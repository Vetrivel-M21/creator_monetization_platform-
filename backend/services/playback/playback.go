package playback

import (
	"bufio"
	"bytes"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/go-chi/chi/v5"
)

// ServeMasterPlaylist handles GET /api/playback/{id}/master.m3u8
func ServeMasterPlaylist(w http.ResponseWriter, r *http.Request) {
	videoID := chi.URLParam(r, "id")
	if videoID == "" {
		http.Error(w, `{"error":"missing video id"}`, http.StatusBadRequest)
		return
	}

	masterPath := filepath.Join("data", "hls", videoID, "master.m3u8")
	data, err := os.ReadFile(masterPath)
	if err != nil {
		// If HLS directory doesn't exist yet, check master file
		rawMasterPath := filepath.Join("data", "masters", videoID+".mp4")
		if _, statErr := os.Stat(rawMasterPath); statErr == nil {
			// Generate dynamic single-rendition playlist
			fallback := fmt.Sprintf(`#EXTM3U
#EXT-X-VERSION:7
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
/api/playback/%s/master.mp4
`, videoID)
			w.Header().Set("Content-Type", "application/vnd.apple.mpegurl")
			w.Header().Set("Access-Control-Allow-Origin", "*")
			_, _ = w.Write([]byte(fallback))
			return
		}

		http.Error(w, `{"error":"video stream not ready or not found"}`, http.StatusNotFound)
		return
	}

	// Rewrite relative playlist URIs so hls.js requests them via /api/playback/{id}/...
	rewritten := rewriteMasterManifest(data, videoID)

	w.Header().Set("Content-Type", "application/vnd.apple.mpegurl")
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range")
	_, _ = w.Write(rewritten)
}

// ServeSegmentFile handles GET /api/playback/{id}/{file}
func ServeSegmentFile(w http.ResponseWriter, r *http.Request) {
	videoID := chi.URLParam(r, "id")
	filename := chi.URLParam(r, "file")

	if videoID == "" || filename == "" {
		http.Error(w, `{"error":"invalid playback path"}`, http.StatusBadRequest)
		return
	}

	// Security check: prevent directory traversal
	if strings.Contains(filename, "..") || strings.Contains(filename, "/") || strings.Contains(filename, "\\") {
		http.Error(w, `{"error":"invalid segment filename"}`, http.StatusBadRequest)
		return
	}

	// Direct master MP4 fallback support
	if filename == "master.mp4" {
		masterPath := filepath.Join("data", "masters", videoID+".mp4")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		http.ServeFile(w, r, masterPath)
		return
	}

	segmentPath := filepath.Join("data", "hls", videoID, filename)
	if _, err := os.Stat(segmentPath); err != nil {
		http.Error(w, `{"error":"segment file not found"}`, http.StatusNotFound)
		return
	}

	// Set proper MIME types per CMAF / HLS specifications
	ext := strings.ToLower(filepath.Ext(filename))
	switch ext {
	case ".m3u8":
		w.Header().Set("Content-Type", "application/vnd.apple.mpegurl")
		w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
	case ".m4s":
		w.Header().Set("Content-Type", "video/iso.segment")
		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	case ".mp4":
		w.Header().Set("Content-Type", "video/mp4")
		w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
	default:
		w.Header().Set("Content-Type", "application/octet-stream")
	}

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range")
	w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Range")

	http.ServeFile(w, r, segmentPath)
}

func rewriteMasterManifest(raw []byte, videoID string) []byte {
	var buf bytes.Buffer
	scanner := bufio.NewScanner(bytes.NewReader(raw))

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			buf.WriteString("\n")
			continue
		}

		// Rewrite variant playlist links (e.g., stream_0.m3u8 -> /api/playback/vid/stream_0.m3u8)
		if !strings.HasPrefix(line, "#") && strings.HasSuffix(line, ".m3u8") {
			buf.WriteString(fmt.Sprintf("/api/playback/%s/%s\n", videoID, line))
			continue
		}

		// Rewrite map/initialization URIs inside EXT-X-MAP tags
		if strings.HasPrefix(line, "#EXT-X-MAP:") {
			line = strings.ReplaceAll(line, `URI="`, fmt.Sprintf(`URI="/api/playback/%s/`, videoID))
		}

		buf.WriteString(line + "\n")
	}

	return buf.Bytes()
}
