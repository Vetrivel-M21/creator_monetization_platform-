package playback

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
)

func TestPlaybackTokenLifecycle(t *testing.T) {
	videoID := "vid-test-01"

	// 1. Generate valid token
	token, exp := GeneratePlaybackToken(videoID, 1*time.Hour)
	if token == "" {
		t.Fatal("expected non-empty token")
	}
	if exp.Before(time.Now()) {
		t.Fatal("expected future expiry")
	}

	// 2. Validate with correct video ID
	if !ValidatePlaybackToken(token, videoID) {
		t.Fatalf("expected token %s to be valid for %s", token, videoID)
	}

	// 3. Validate with incorrect video ID (binding mismatch)
	if ValidatePlaybackToken(token, "vid-other-99") {
		t.Fatal("expected token to fail for mismatched video ID")
	}

	// 4. Validate empty or malformed token
	if ValidatePlaybackToken("", videoID) {
		t.Fatal("expected empty token to be invalid")
	}
	if ValidatePlaybackToken("malformed_token", videoID) {
		t.Fatal("expected malformed token to be invalid")
	}

	// 5. Expired token check
	expiredToken, _ := GeneratePlaybackToken(videoID, -1*time.Hour)
	if ValidatePlaybackToken(expiredToken, videoID) {
		t.Fatal("expected expired token to be rejected")
	}
}

func TestMasterAndMediaPlaylistRewriting(t *testing.T) {
	videoID := "vid-abr-100"
	token, _ := GeneratePlaybackToken(videoID, 2*time.Hour)
	baseURL := "https://api.example.com"

	// Raw master playlist sample
	rawMaster := []byte(`#EXTM3U
#EXT-X-VERSION:7
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
stream_0.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720
stream_1.m3u8
`)

	rewrittenMaster := string(rewriteMasterManifest(rawMaster, videoID, token, baseURL))

	// Verify variant streams have absolute short paths + token
	expectedVariant0 := "https://api.example.com/api/playback/vid-abr-100/stream_0.m3u8?token=" + token
	expectedVariant1 := "https://api.example.com/api/playback/vid-abr-100/stream_1.m3u8?token=" + token
	if !strings.Contains(rewrittenMaster, expectedVariant0) {
		t.Fatalf("master missing expected variant 0:\n%s", rewrittenMaster)
	}
	if !strings.Contains(rewrittenMaster, expectedVariant1) {
		t.Fatalf("master missing expected variant 1:\n%s", rewrittenMaster)
	}

	// Raw media playlist sample
	rawMedia := []byte(`#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-MAP:URI="init.mp4"
#EXTINF:6.000000,
stream_0_00000.m4s
#EXTINF:6.000000,
stream_0_00001.m4s
`)

	rewrittenMedia := string(rewriteMediaManifest(rawMedia, videoID, token, baseURL))

	// Verify VOD tags
	if !strings.Contains(rewrittenMedia, "#EXT-X-PLAYLIST-TYPE:VOD") {
		t.Fatalf("media playlist missing VOD tag:\n%s", rewrittenMedia)
	}
	if !strings.Contains(rewrittenMedia, "#EXT-X-ENDLIST") {
		t.Fatalf("media playlist missing ENDLIST tag:\n%s", rewrittenMedia)
	}

	// Verify EXT-X-MAP rewritten with token
	expectedMap := `URI="https://api.example.com/api/playback/vid-abr-100/init.mp4?token=` + token + `"`
	if !strings.Contains(rewrittenMedia, expectedMap) {
		t.Fatalf("media playlist missing rewritten EXT-X-MAP URI:\n%s", rewrittenMedia)
	}

	// Verify segment lines rewritten with short paths + token
	expectedSeg0 := "https://api.example.com/api/playback/vid-abr-100/stream_0_00000.m4s?token=" + token
	expectedSeg1 := "https://api.example.com/api/playback/vid-abr-100/stream_0_00001.m4s?token=" + token
	if !strings.Contains(rewrittenMedia, expectedSeg0) {
		t.Fatalf("media playlist missing rewritten segment 0:\n%s", rewrittenMedia)
	}
	if !strings.Contains(rewrittenMedia, expectedSeg1) {
		t.Fatalf("media playlist missing rewritten segment 1:\n%s", rewrittenMedia)
	}

	// Verify NO S3/presigned URLs exist
	if strings.Contains(rewrittenMedia, "amazonaws.com") || strings.Contains(rewrittenMedia, "X-Amz-Signature") {
		t.Fatal("detected unauthorized presigned S3 URL in media manifest")
	}
}

func TestPlaybackEndpointsAuthGatingStrict(t *testing.T) {
	os.Setenv("PLAYBACK_TOKEN_REQUIRED", "true")
	defer os.Unsetenv("PLAYBACK_TOKEN_REQUIRED")

	videoID := "vid-mock-test"
	token, _ := GeneratePlaybackToken(videoID, 2*time.Hour)

	// Create test HLS files on disk
	hlsDir := filepath.Join("data", "hls", videoID)
	_ = os.MkdirAll(hlsDir, 0755)
	defer os.RemoveAll(filepath.Join("data", "hls", videoID))

	masterPath := filepath.Join(hlsDir, "master.m3u8")
	_ = os.WriteFile(masterPath, []byte("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=800000\nstream_0.m3u8\n"), 0644)

	mediaPath := filepath.Join(hlsDir, "stream_0.m3u8")
	_ = os.WriteFile(mediaPath, []byte("#EXTM3U\n#EXT-X-MAP:URI=\"init.mp4\"\n#EXTINF:6.0,\nstream_0_0.m4s\n#EXT-X-ENDLIST\n"), 0644)

	initPath := filepath.Join(hlsDir, "init.mp4")
	_ = os.WriteFile(initPath, []byte("ftypmp42"), 0644)

	r := chi.NewRouter()
	r.Get("/api/playback/{id}/master.m3u8", ServeMasterPlaylist)
	r.Get("/api/playback/{id}/{file}", ServeSegmentFile)

	// 1. In strict mode: request master without token -> 401 Unauthorized
	req1 := httptest.NewRequest("GET", "/api/playback/"+videoID+"/master.m3u8", nil)
	w1 := httptest.NewRecorder()
	r.ServeHTTP(w1, req1)
	if w1.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 without token in strict mode, got %d", w1.Code)
	}

	// 2. In strict mode: request master with wrong token -> 401 Unauthorized
	req2 := httptest.NewRequest("GET", "/api/playback/"+videoID+"/master.m3u8?token=invalid_dummy_token", nil)
	w2 := httptest.NewRecorder()
	r.ServeHTTP(w2, req2)
	if w2.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401 with invalid token, got %d", w2.Code)
	}

	// 3. Request master with valid token -> 200 OK
	req3 := httptest.NewRequest("GET", "/api/playback/"+videoID+"/master.m3u8?token="+token, nil)
	w3 := httptest.NewRecorder()
	r.ServeHTTP(w3, req3)
	if w3.Code != http.StatusOK {
		t.Fatalf("expected 200 with valid token, got %d (body: %s)", w3.Code, w3.Body.String())
	}
	if !strings.Contains(w3.Body.String(), "stream_0.m3u8?token="+token) {
		t.Fatalf("master response does not propagate token to variants: %s", w3.Body.String())
	}

	// 4. Request media playlist with valid token -> 200 OK
	req4 := httptest.NewRequest("GET", "/api/playback/"+videoID+"/stream_0.m3u8?token="+token, nil)
	w4 := httptest.NewRecorder()
	r.ServeHTTP(w4, req4)
	if w4.Code != http.StatusOK {
		t.Fatalf("expected 200 for media playlist, got %d", w4.Code)
	}
	if !strings.Contains(w4.Body.String(), "init.mp4?token="+token) {
		t.Fatalf("media playlist does not rewrite init.mp4 with token: %s", w4.Body.String())
	}

	// 5. Request segment file with valid token -> 200 OK
	req5 := httptest.NewRequest("GET", "/api/playback/"+videoID+"/init.mp4?token="+token, nil)
	w5 := httptest.NewRecorder()
	r.ServeHTTP(w5, req5)
	if w5.Code != http.StatusOK {
		t.Fatalf("expected 200 for init.mp4, got %d", w5.Code)
	}
	if w5.Body.String() != "ftypmp42" {
		t.Fatalf("unexpected segment payload: %s", w5.Body.String())
	}
}

func TestPlaybackCompatibilityMode(t *testing.T) {
	os.Setenv("PLAYBACK_TOKEN_REQUIRED", "false")
	defer os.Unsetenv("PLAYBACK_TOKEN_REQUIRED")

	videoID := "vid-compat-test"
	hlsDir := filepath.Join("data", "hls", videoID)
	_ = os.MkdirAll(hlsDir, 0755)
	defer os.RemoveAll(filepath.Join("data", "hls", videoID))

	masterPath := filepath.Join(hlsDir, "master.m3u8")
	_ = os.WriteFile(masterPath, []byte("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=800000\nstream_0.m3u8\n"), 0644)

	r := chi.NewRouter()
	r.Get("/api/playback/{id}/master.m3u8", ServeMasterPlaylist)

	// In compatibility mode (default), tokenless request succeeds with 200 and auto-generates token for child segments!
	req := httptest.NewRequest("GET", "/api/playback/"+videoID+"/master.m3u8", nil)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("expected 200 in compatibility mode, got %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), "stream_0.m3u8?token=") {
		t.Fatalf("expected auto-generated token in variant links, got %s", w.Body.String())
	}
}
