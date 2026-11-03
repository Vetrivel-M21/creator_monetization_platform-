package handlers

import (
	"bytes"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGoogleLogin_Validation(t *testing.T) {
	// 1. Empty body
	req := httptest.NewRequest(http.MethodPost, "/api/auth/google", bytes.NewBufferString(`{}`))
	rec := httptest.NewRecorder()
	GoogleLogin(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("Expected 400 Bad Request for empty payload, got %d", rec.Code)
	}

	// 2. Malformed / Invalid ID token
	req = httptest.NewRequest(http.MethodPost, "/api/auth/google", bytes.NewBufferString(`{"credential":"invalid.jwt.token"}`))
	rec = httptest.NewRecorder()
	GoogleLogin(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("Expected 401 Unauthorized for invalid Google credential, got %d", rec.Code)
	}
}
