package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"creator-monetization-backend/database"
	"creator-monetization-backend/middleware"
	"creator-monetization-backend/models"
	"creator-monetization-backend/services/transcode"
)

// UploadVideo handles multipart video uploads, probes metadata, and queues CMAF ABR transcoding.
func UploadVideo(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	claims := middleware.GetUserFromContext(r)
	if claims == nil || claims.UserID == "" {
		claims = &middleware.Claims{
			UserID: "usr-01",
			Email:  "creator1@armss.com",
			Role:   models.RoleUser,
		}
	}

	// Allow up to 1GB video upload without running out of RAM
	r.Body = http.MaxBytesReader(w, r.Body, 1024<<20)

	// Keep up to 32MB in RAM, overflow streams seamlessly to temporary disk files
	if err := r.ParseMultipartForm(32 << 20); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(fmt.Sprintf(`{"error":"failed to parse multipart upload: %v"}`, err)))
		return
	}

	title := strings.TrimSpace(r.FormValue("title"))
	if len(title) < 3 || len(title) > 120 {
		w.WriteHeader(http.StatusBadRequest)
		_, _ = w.Write([]byte(`{"error":"title must be between 3 and 120 characters"}`))
		return
	}

	category := models.VideoCategory(strings.TrimSpace(r.FormValue("category")))
	validCategories := map[models.VideoCategory]bool{
		models.CatSelf:      true,
		models.CatPromotion: true,
		models.CatProduct:   true,
		models.CatBusiness:  true,
	}
	if !validCategories[category] {
		category = models.CatPromotion
	}

	description := strings.TrimSpace(r.FormValue("description"))

	// Retrieve uploaded video file
	file, _, err := r.FormFile("video")
	if err != nil {
		http.Error(w, `{"error":"video file is required in 'video' field"}`, http.StatusBadRequest)
		return
	}
	defer file.Close()

	// Ensure destination directory exists
	if err := os.MkdirAll("data/masters", 0755); err != nil {
		http.Error(w, `{"error":"failed to initialize master storage"}`, http.StatusInternalServerError)
		return
	}
	_ = os.MkdirAll("data/thumbnails", 0755)

	videoID := randomID("vid")
	masterFilename := videoID + ".mp4"
	masterLocalPath := filepath.Join("data", "masters", masterFilename)

	destFile, err := os.Create(masterLocalPath)
	if err != nil {
		http.Error(w, `{"error":"failed to save video master"}`, http.StatusInternalServerError)
		return
	}
	defer destFile.Close()

	if _, err := io.Copy(destFile, file); err != nil {
		http.Error(w, `{"error":"failed to write video file"}`, http.StatusInternalServerError)
		return
	}

	// Handle optional uploaded thumbnail
	thumbnailURL := ""
	thumbFile, thumbHeader, thumbErr := r.FormFile("thumbnail")
	if thumbErr == nil && thumbHeader != nil {
		defer thumbFile.Close()
		thumbExt := strings.ToLower(filepath.Ext(thumbHeader.Filename))
		if thumbExt == "" {
			thumbExt = ".jpg"
		}
		thumbFilename := videoID + thumbExt
		thumbLocalPath := filepath.Join("data", "thumbnails", thumbFilename)
		if tDest, err := os.Create(thumbLocalPath); err == nil {
			_, _ = io.Copy(tDest, thumbFile)
			tDest.Close()
			thumbnailURL = "/thumbnails/" + thumbFilename
		}
	}

	if thumbnailURL == "" {
		thumbnailURL = r.FormValue("thumbnail_url")
	}
	if thumbnailURL == "" {
		thumbnailURL = fmt.Sprintf("https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1280&q=80")
	}

	// Probe video duration
	durationMinutes := 2.0
	meta, pErr := transcode.ProbeVideo(r.Context(), masterLocalPath)
	if pErr == nil && meta.Duration > 0 {
		durationMinutes = meta.Duration / 60.0
	}

	// Lookup creator information
	var creatorName string
	var creatorTier models.CreatorTier
	var isActive bool
	err = database.DB.QueryRowContext(r.Context(), "SELECT name, tier, is_active FROM users WHERE id = ?", claims.UserID).Scan(&creatorName, &creatorTier, &isActive)
	if err != nil || !isActive {
		http.Error(w, `{"error":"creator account is invalid or deactivated"}`, http.StatusForbidden)
		return
	}

	hlsURL := fmt.Sprintf("/api/playback/%s/master.m3u8", videoID)
	videoURL := fmt.Sprintf("/api/playback/%s/master.mp4", videoID)

	videoType := strings.TrimSpace(r.FormValue("video_type"))
	if videoType != "short" && videoType != "landscape" {
		if pErr == nil && meta.Width > 0 && meta.Height > meta.Width {
			videoType = "short"
		} else if durationMinutes <= 2.0 {
			videoType = "short"
		} else {
			videoType = "landscape"
		}
	}

	v := models.Video{
		ID:              videoID,
		UserID:          claims.UserID,
		CreatorName:     creatorName,
		CreatorTier:     creatorTier,
		Title:           title,
		Description:     description,
		Category:        category,
		VideoType:       videoType,
		DurationMinutes: durationMinutes,
		VideoURL:        videoURL,
		HLSURL:          hlsURL,
		HLSPath:         filepath.Join("data", "hls", videoID),
		MasterPath:      masterLocalPath,
		ThumbnailURL:    thumbnailURL,
		Status:          models.StatusPending,
		TranscodeStatus: "processing",
		ViewsCount:      0,
		LikesCount:      0,
		SharesCount:     0,
		CommentsCount:   0,
		TotalWatchMins:  0,
		TotalEarned:     0,
		CreatedAt:       time.Now(),
		UpdatedAt:       time.Now(),
	}

	query := `
		INSERT INTO videos (
			id, user_id, creator_name, creator_tier, title, description, category, video_type,
			duration_minutes, video_url, hls_url, hls_path, master_path, thumbnail_url,
			status, transcode_status, views_count, likes_count, shares_count,
			comments_count, total_watch_mins, total_earned, created_at, updated_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`
	_, err = database.DB.ExecContext(r.Context(), query,
		v.ID, v.UserID, v.CreatorName, v.CreatorTier, v.Title, v.Description, v.Category, v.VideoType,
		v.DurationMinutes, v.VideoURL, v.HLSURL, v.HLSPath, v.MasterPath, v.ThumbnailURL,
		v.Status, v.TranscodeStatus, v.ViewsCount, v.LikesCount, v.SharesCount,
		v.CommentsCount, v.TotalWatchMins, v.TotalEarned, v.CreatedAt, v.UpdatedAt,
	)
	if err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"failed to create video record: %v"}`, err), http.StatusInternalServerError)
		return
	}

	// Launch background transcoding job (asynchronous ABR ladder generation)
	if transcode.DefaultTranscoder != nil {
		transcode.DefaultTranscoder.StartTranscodeJob(videoID)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "Video uploaded successfully. Transcoding started in background.",
		"video":   v,
	})
}
