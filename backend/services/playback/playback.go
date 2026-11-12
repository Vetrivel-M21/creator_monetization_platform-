package playback

import (
	"bufio"
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"creator-monetization-backend/database"
	"creator-monetization-backend/middleware"

	"github.com/go-chi/chi/v5"
)

// ─────────────────────────────────────────────────────────────────────────────
// Configuration & Playback Token Engine (HMAC-SHA256 Signed & Video-Bound)
// ─────────────────────────────────────────────────────────────────────────────

// IsPlaybackTokenRequired determines whether unauthenticated/tokenless requests are blocked
// Default is false (compatibility mode) to prevent breaking mobile / guest playback.
func IsPlaybackTokenRequired() bool {
	req := strings.ToLower(strings.TrimSpace(os.Getenv("PLAYBACK_TOKEN_REQUIRED")))
	return req == "true" || req == "1" || req == "yes"
}

// GeneratePlaybackToken creates a lightweight, URL-safe HMAC token bound to videoID
func GeneratePlaybackToken(videoID string, duration time.Duration) (string, time.Time) {
	if duration == 0 {
		duration = 4 * time.Hour
	}
	expiresAt := time.Now().Add(duration)
	expUnix := expiresAt.Unix()

	payload := fmt.Sprintf("%s:%d", videoID, expUnix)
	mac := hmac.New(sha256.New, middleware.GetJWTSecret())
	mac.Write([]byte(payload))
	sig := hex.EncodeToString(mac.Sum(nil))

	token := fmt.Sprintf("%d_%s", expUnix, sig)
	return token, expiresAt
}

// ValidatePlaybackToken verifies that the token belongs to videoID and has not expired
func ValidatePlaybackToken(tokenStr, videoID string) bool {
	tokenStr = strings.TrimSpace(tokenStr)
	if tokenStr == "" || videoID == "" {
		return false
	}

	parts := strings.SplitN(tokenStr, "_", 2)
	if len(parts) != 2 {
		return false
	}

	expUnix, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return false
	}

	// Expiry check
	if time.Now().Unix() > expUnix {
		return false
	}

	// Verify signature against single source of truth (middleware.GetJWTSecret)
	payload := fmt.Sprintf("%s:%d", videoID, expUnix)
	mac := hmac.New(sha256.New, middleware.GetJWTSecret())
	mac.Write([]byte(payload))
	expectedSig := hex.EncodeToString(mac.Sum(nil))

	return hmac.Equal([]byte(parts[1]), []byte(expectedSig))
}

// extractPlaybackToken retrieves the token from query param ?token= or Authorization header
func extractPlaybackToken(r *http.Request) string {
	if token := r.URL.Query().Get("token"); token != "" {
		return strings.TrimSpace(token)
	}
	authHeader := r.Header.Get("Authorization")
	if authHeader != "" && strings.HasPrefix(authHeader, "Bearer ") {
		return strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
	}
	return ""
}

// GetPublicAPIBaseURL returns the configured public API host or infers from incoming request
func GetPublicAPIBaseURL(r *http.Request) string {
	baseURL := strings.TrimRight(os.Getenv("PUBLIC_API_BASE_URL"), "/")
	if baseURL != "" {
		return baseURL
	}

	scheme := "http"
	if r != nil {
		if proto := r.Header.Get("X-Forwarded-Proto"); proto != "" {
			scheme = proto
		} else if r.TLS != nil {
			scheme = "https"
		}
		host := r.Header.Get("X-Forwarded-Host")
		if host == "" {
			host = r.Host
		}
		if host != "" {
			return fmt.Sprintf("%s://%s", scheme, host)
		}
	}
	// Production fallback
	return "https://entertainment.aurapictures.online"
}

// ─────────────────────────────────────────────────────────────────────────────
// Playback Ticket Endpoint
// ─────────────────────────────────────────────────────────────────────────────

// GetPlaybackTicket handles GET /api/videos/{id}/playback (Protected by Auth)
func GetPlaybackTicket(w http.ResponseWriter, r *http.Request) {
	videoID := chi.URLParam(r, "id")
	if videoID == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"error":"missing video id"}`))
		return
	}

	var transcodeStatus string
	err := database.DB.QueryRowContext(r.Context(),
		"SELECT COALESCE(transcode_status, 'ready') FROM videos WHERE id = ?", videoID,
	).Scan(&transcodeStatus)
	if err != nil && err != sql.ErrNoRows {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{"error":"database error"}`))
		return
	}

	token, expiresAt := GeneratePlaybackToken(videoID, 4*time.Hour)
	baseURL := GetPublicAPIBaseURL(r)
	hlsURL := fmt.Sprintf("%s/api/playback/%s/master.m3u8?token=%s", baseURL, videoID, token)

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"video_id":         videoID,
		"hls_url":          hlsURL,
		"token":            token,
		"expires_at":       expiresAt.Format(time.RFC3339),
		"transcode_status": transcodeStatus,
	})
}

// ─────────────────────────────────────────────────────────────────────────────
// Master & Media HLS Playlist Serving & Absolute Short Rewriting
// ─────────────────────────────────────────────────────────────────────────────

// ServeMasterPlaylist handles GET/HEAD /api/playback/{id}/master.m3u8
func ServeMasterPlaylist(w http.ResponseWriter, r *http.Request) {
	videoID := chi.URLParam(r, "id")
	if videoID == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"error":"missing video id"}`))
		return
	}

	// 1. Validate playback token (with compatibility fallback)
	token := extractPlaybackToken(r)
	hasValidToken := ValidatePlaybackToken(token, videoID)

	if !hasValidToken {
		if IsPlaybackTokenRequired() {
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.WriteHeader(http.StatusUnauthorized)
			_ = json.NewEncoder(w).Encode(map[string]interface{}{
				"error":    "invalid or expired playback token",
				"video_id": videoID,
			})
			return
		}
		// Compatibility mode: generate fresh token so child links in playlist are authenticated
		token, _ = GeneratePlaybackToken(videoID, 4*time.Hour)
	}

	baseURL := GetPublicAPIBaseURL(r)

	// 2. Transcode Gating:
	// A) If HLS master exists on disk -> Playable!
	masterPath := filepath.Join("data", "hls", videoID, "master.m3u8")
	data, err := os.ReadFile(masterPath)
	if err == nil && len(bytes.TrimSpace(data)) > 0 {
		rewritten := rewriteMasterManifest(data, videoID, token, baseURL)
		w.Header().Set("Content-Type", "application/vnd.apple.mpegurl")
		w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range")
		w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Range")
		_, _ = w.Write(rewritten)
		return
	}

	// B) If only raw master MP4 exists on disk -> Serve progressive MP4 fallback
	rawMasterPath := filepath.Join("data", "masters", videoID+".mp4")
	if _, statErr := os.Stat(rawMasterPath); statErr == nil {
		tokenParam := ""
		if token != "" {
			tokenParam = "?token=" + token
		}
		fallback := fmt.Sprintf(`#EXTM3U
#EXT-X-VERSION:7
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
%s/api/playback/%s/master.mp4%s
`, baseURL, videoID, tokenParam)
		w.Header().Set("Content-Type", "application/vnd.apple.mpegurl")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range")
		w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Range")
		_, _ = w.Write([]byte(fallback))
		return
	}

	// C) Neither HLS nor master MP4 exists on disk: query DB for transcode status
	var transcodeStatus string
	dbErr := database.DB.QueryRowContext(r.Context(),
		"SELECT COALESCE(transcode_status, 'ready') FROM videos WHERE id = ?", videoID,
	).Scan(&transcodeStatus)

	if dbErr == nil {
		if transcodeStatus == "processing" || transcodeStatus == "pending" {
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.WriteHeader(http.StatusConflict) // 409 Conflict
			_ = json.NewEncoder(w).Encode(map[string]interface{}{
				"error":            "video stream not ready (transcoding in progress)",
				"status":           "processing",
				"transcode_status": transcodeStatus,
				"video_id":         videoID,
			})
			return
		}
		if transcodeStatus == "failed" {
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.WriteHeader(http.StatusUnprocessableEntity) // 422
			_ = json.NewEncoder(w).Encode(map[string]interface{}{
				"error":            "video transcoding failed",
				"status":           "failed",
				"transcode_status": transcodeStatus,
				"video_id":         videoID,
			})
			return
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(http.StatusNotFound)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"error":    "video stream not ready or not found",
		"status":   "not_found",
		"video_id": videoID,
	})
}

// ServeSegmentFile handles GET/HEAD /api/playback/{id}/{file}
func ServeSegmentFile(w http.ResponseWriter, r *http.Request) {
	videoID := chi.URLParam(r, "id")
	filename := chi.URLParam(r, "file")

	if videoID == "" || filename == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"error":"invalid playback path"}`))
		return
	}

	// Security check: prevent directory traversal
	if strings.Contains(filename, "..") || strings.Contains(filename, "/") || strings.Contains(filename, "\\") {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"error":"invalid segment filename"}`))
		return
	}

	// 1. Validate playback token (with compatibility fallback)
	token := extractPlaybackToken(r)
	hasValidToken := ValidatePlaybackToken(token, videoID)

	if !hasValidToken {
		if IsPlaybackTokenRequired() {
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.WriteHeader(http.StatusUnauthorized)
			_ = json.NewEncoder(w).Encode(map[string]interface{}{
				"error":    "invalid or expired playback token",
				"video_id": videoID,
			})
			return
		}
		// Compatibility mode: generate fresh token
		token, _ = GeneratePlaybackToken(videoID, 4*time.Hour)
	}

	// 2. Direct master MP4 fallback support (e.g. /api/playback/{id}/master.mp4?token=...)
	if filename == "master.mp4" {
		masterPath := filepath.Join("data", "masters", videoID+".mp4")
		if _, err := os.Stat(masterPath); err != nil {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusNotFound)
			_, _ = w.Write([]byte(`{"error":"master file not found"}`))
			return
		}
		w.Header().Set("Content-Type", "video/mp4")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range")
		w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Range")
		http.ServeFile(w, r, masterPath)
		return
	}

	targetPath := filepath.Join("data", "hls", videoID, filename)
	if _, err := os.Stat(targetPath); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		_, _ = w.Write([]byte(`{"error":"file not found"}`))
		return
	}

	baseURL := GetPublicAPIBaseURL(r)
	ext := strings.ToLower(filepath.Ext(filename))

	// 3. Media Playlist Rewrite (stream_X.m3u8): rewrite segments & EXT-X-MAP, ensure VOD tags
	if ext == ".m3u8" {
		raw, err := os.ReadFile(targetPath)
		if err != nil {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = w.Write([]byte(`{"error":"failed to read media playlist"}`))
			return
		}

		rewritten := rewriteMediaManifest(raw, videoID, token, baseURL)

		w.Header().Set("Content-Type", "application/vnd.apple.mpegurl")
		w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range")
		w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Range")
		_, _ = w.Write(rewritten)
		return
	}

	// 4. Binary Segments & Init Files (.m4s, .mp4, .ts)
	switch ext {
	case ".m4s":
		w.Header().Set("Content-Type", "video/iso.segment")
		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	case ".mp4":
		w.Header().Set("Content-Type", "video/mp4")
		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	case ".ts":
		w.Header().Set("Content-Type", "video/mp2t")
		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	default:
		w.Header().Set("Content-Type", "application/octet-stream")
	}

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range")
	w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Range")

	http.ServeFile(w, r, targetPath)
}

// ─────────────────────────────────────────────────────────────────────────────
// Manifest Rewriting Helpers
// ─────────────────────────────────────────────────────────────────────────────

func rewriteMasterManifest(raw []byte, videoID, token, baseURL string) []byte {
	var buf bytes.Buffer
	scanner := bufio.NewScanner(bytes.NewReader(raw))

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			buf.WriteString("\n")
			continue
		}

		// Rewrite variant playlist links (e.g. stream_0.m3u8 -> {baseURL}/api/playback/{id}/stream_0.m3u8?token=...)
		if !strings.HasPrefix(line, "#") && strings.HasSuffix(line, ".m3u8") {
			variantFile := filepath.Base(line)
			if idx := strings.Index(variantFile, "?"); idx != -1 {
				variantFile = variantFile[:idx]
			}
			tokenParam := ""
			if token != "" {
				tokenParam = "?token=" + token
			}
			buf.WriteString(fmt.Sprintf("%s/api/playback/%s/%s%s\n", baseURL, videoID, variantFile, tokenParam))
			continue
		}

		// Rewrite map/initialization URIs inside EXT-X-MAP tags
		if strings.HasPrefix(line, "#EXT-X-MAP:") {
			line = rewriteExtXMapTag(line, videoID, token, baseURL)
		}

		buf.WriteString(line + "\n")
	}

	return buf.Bytes()
}

func rewriteMediaManifest(raw []byte, videoID, token, baseURL string) []byte {
	var buf bytes.Buffer
	scanner := bufio.NewScanner(bytes.NewReader(raw))
	hasPlaylistType := false
	hasEndList := false

	tokenParam := ""
	if token != "" {
		tokenParam = "?token=" + token
	}

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			buf.WriteString("\n")
			continue
		}

		if strings.HasPrefix(line, "#EXT-X-PLAYLIST-TYPE:") {
			hasPlaylistType = true
		}
		if line == "#EXT-X-ENDLIST" {
			hasEndList = true
		}

		// Rewrite EXT-X-MAP tag for initialization segment
		if strings.HasPrefix(line, "#EXT-X-MAP:") {
			line = rewriteExtXMapTag(line, videoID, token, baseURL)
			buf.WriteString(line + "\n")
			continue
		}

		// Rewrite all non-comment media segment lines (.m4s, .ts, .mp4, etc.)
		if !strings.HasPrefix(line, "#") {
			segName := filepath.Base(line)
			if idx := strings.Index(segName, "?"); idx != -1 {
				segName = segName[:idx]
			}
			buf.WriteString(fmt.Sprintf("%s/api/playback/%s/%s%s\n", baseURL, videoID, segName, tokenParam))
			continue
		}

		buf.WriteString(line + "\n")

		// Insert VOD tag after EXT-X-VERSION if missing
		if strings.HasPrefix(line, "#EXT-X-VERSION:") && !hasPlaylistType {
			buf.WriteString("#EXT-X-PLAYLIST-TYPE:VOD\n")
			hasPlaylistType = true
		}
	}

	if !hasPlaylistType {
		buf.WriteString("#EXT-X-PLAYLIST-TYPE:VOD\n")
	}
	if !hasEndList {
		buf.WriteString("#EXT-X-ENDLIST\n")
	}

	return buf.Bytes()
}

func rewriteExtXMapTag(line, videoID, token, baseURL string) string {
	start := strings.Index(line, `URI="`)
	if start == -1 {
		return line
	}
	end := strings.Index(line[start+5:], `"`)
	if end == -1 {
		return line
	}
	rawURI := line[start+5 : start+5+end]
	initFile := filepath.Base(rawURI)
	if idx := strings.Index(initFile, "?"); idx != -1 {
		initFile = initFile[:idx]
	}
	tokenParam := ""
	if token != "" {
		tokenParam = "?token=" + token
	}
	newURI := fmt.Sprintf(`%s/api/playback/%s/%s%s`, baseURL, videoID, initFile, tokenParam)
	return line[:start] + fmt.Sprintf(`URI="%s"`, newURI) + line[start+5+end+1:]
}
