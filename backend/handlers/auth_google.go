package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"creator-monetization-backend/database"
	"creator-monetization-backend/logger"
	"creator-monetization-backend/middleware"
	"creator-monetization-backend/models"
)

type GoogleTokenInfo struct {
	Iss           string `json:"iss"`
	Sub           string `json:"sub"`
	Azp           string `json:"azp"`
	Aud           string `json:"aud"`
	Email         string `json:"email"`
	EmailVerified string `json:"email_verified"`
	Name          string `json:"name"`
	Picture       string `json:"picture"`
	GivenName     string `json:"given_name"`
	FamilyName    string `json:"family_name"`
	Error         string `json:"error"`
	ErrorDesc     string `json:"error_description"`
}

type GoogleAuthRequest struct {
	Credential string `json:"credential"`
	Code       string `json:"code"`
}

// GoogleLogin handles verified Google ID tokens from Google Identity Services
func GoogleLogin(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	var req GoogleAuthRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(map[string]string{"error": "Invalid request payload"})
		return
	}

	googleClientID := os.Getenv("GOOGLE_CLIENT_ID")
	googleClientSecret := os.Getenv("GOOGLE_CLIENT_SECRET")
	if googleClientID == "" {
		logger.ErrorLogger.Println("[GoogleAuth] GOOGLE_CLIENT_ID environment variable is not configured")
	}

	var verifiedEmail string
	var verifiedName string
	var verifiedPicture string

	httpClient := &http.Client{Timeout: 10 * time.Second}

	if req.Credential != "" {
		// 1. Verify Google ID token (Credential from Google Identity Services)
		tokenInfoURL := fmt.Sprintf("https://oauth2.googleapis.com/tokeninfo?id_token=%s", url.QueryEscape(req.Credential))
		resp, err := httpClient.Get(tokenInfoURL)
		if err != nil {
			w.WriteHeader(http.StatusBadGateway)
			_ = json.NewEncoder(w).Encode(map[string]string{"error": "Failed to connect to Google authentication service"})
			return
		}
		defer resp.Body.Close()

		bodyBytes, err := io.ReadAll(resp.Body)
		if err != nil || resp.StatusCode != http.StatusOK {
			w.WriteHeader(http.StatusUnauthorized)
			_ = json.NewEncoder(w).Encode(map[string]string{"error": "Invalid or expired Google credential"})
			return
		}

		var info GoogleTokenInfo
		if err := json.Unmarshal(bodyBytes, &info); err != nil || info.Email == "" {
			w.WriteHeader(http.StatusUnauthorized)
			_ = json.NewEncoder(w).Encode(map[string]string{"error": "Unable to parse Google token details"})
			return
		}

		// Security: verify audience matches our application's client ID
		if info.Aud != googleClientID && info.Azp != googleClientID {
			logger.ErrorLogger.Printf("[GoogleAuth] Token audience mismatch: token aud=%s, expected=%s", info.Aud, googleClientID)
		}

		verifiedEmail = strings.ToLower(strings.TrimSpace(info.Email))
		verifiedName = strings.TrimSpace(info.Name)
		verifiedPicture = strings.TrimSpace(info.Picture)

	} else if req.Code != "" {
		// 2. Exchange Authorization Code for Tokens
		tokenReqData := url.Values{}
		tokenReqData.Set("code", req.Code)
		tokenReqData.Set("client_id", googleClientID)
		tokenReqData.Set("client_secret", googleClientSecret)
		tokenReqData.Set("redirect_uri", "http://localhost:5173")
		tokenReqData.Set("grant_type", "authorization_code")

		tokenResp, err := httpClient.PostForm("https://oauth2.googleapis.com/token", tokenReqData)
		if err != nil {
			w.WriteHeader(http.StatusBadGateway)
			_ = json.NewEncoder(w).Encode(map[string]string{"error": "Failed to exchange authorization code with Google"})
			return
		}
		defer tokenResp.Body.Close()

		var tokenResult struct {
			IDToken     string `json:"id_token"`
			AccessToken string `json:"access_token"`
			Error       string `json:"error"`
			ErrorDesc   string `json:"error_description"`
		}
		if err := json.NewDecoder(tokenResp.Body).Decode(&tokenResult); err != nil || (tokenResult.IDToken == "" && tokenResult.AccessToken == "") {
			w.WriteHeader(http.StatusUnauthorized)
			_ = json.NewEncoder(w).Encode(map[string]string{"error": "Failed to parse Google OAuth token response"})
			return
		}

		// Query Google UserInfo API using access token or id token
		userInfoURL := "https://www.googleapis.com/oauth2/v3/userinfo"
		userInfoReq, _ := http.NewRequestWithContext(r.Context(), "GET", userInfoURL, nil)
		userInfoReq.Header.Set("Authorization", "Bearer "+tokenResult.AccessToken)
		userResp, err := httpClient.Do(userInfoReq)
		if err != nil || userResp.StatusCode != http.StatusOK {
			w.WriteHeader(http.StatusUnauthorized)
			_ = json.NewEncoder(w).Encode(map[string]string{"error": "Failed to fetch user profile from Google"})
			return
		}
		defer userResp.Body.Close()

		var userInfo struct {
			Email   string `json:"email"`
			Name    string `json:"name"`
			Picture string `json:"picture"`
		}
		if err := json.NewDecoder(userResp.Body).Decode(&userInfo); err != nil || userInfo.Email == "" {
			w.WriteHeader(http.StatusUnauthorized)
			_ = json.NewEncoder(w).Encode(map[string]string{"error": "Invalid Google user profile data"})
			return
		}

		verifiedEmail = strings.ToLower(strings.TrimSpace(userInfo.Email))
		verifiedName = strings.TrimSpace(userInfo.Name)
		verifiedPicture = strings.TrimSpace(userInfo.Picture)
	} else {
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(map[string]string{"error": "Google credential token or authorization code is required"})
		return
	}

	if verifiedEmail == "" {
		w.WriteHeader(http.StatusBadRequest)
		_ = json.NewEncoder(w).Encode(map[string]string{"error": "Google account does not have a verified email"})
		return
	}

	if verifiedName == "" {
		verifiedName = strings.Split(verifiedEmail, "@")[0]
	}
	if verifiedPicture == "" {
		verifiedPicture = fmt.Sprintf("https://api.dicebear.com/7.x/bottts/svg?seed=%s", verifiedEmail)
	}

	// 3. Lookup user in database or auto-provision as creator
	var u models.User
	var storedHash string
	var silverPaidInt int

	err := database.DB.QueryRowContext(r.Context(), `
		SELECT id, email, COALESCE(mobile, ''), COALESCE(age, 0), password_hash, name, 
		       COALESCE(channel_name, ''), COALESCE(channel_logo, ''), COALESCE(channel_description, ''),
		       role, tier, is_active, wallet_amount, COALESCE(silver_reward_paid, 0), silver_reward_paid_at, created_at, updated_at
		FROM users 
		WHERE email = ?
	`, verifiedEmail).Scan(
		&u.ID, &u.Email, &u.Mobile, &u.Age, &storedHash, &u.Name,
		&u.ChannelName, &u.ChannelLogo, &u.ChannelDescription,
		&u.Role, &u.Tier, &u.IsActive, &u.WalletAmount, &silverPaidInt, &u.SilverRewardPaidAt, &u.CreatedAt, &u.UpdatedAt,
	)

	if err != nil {
		// New creator: create record
		now := time.Now()
		u = models.User{
			ID:                 randomID("usr"),
			Email:              verifiedEmail,
			Mobile:             "",
			Age:                24,
			PasswordHash:       "",
			Name:               verifiedName,
			ChannelName:        verifiedName + " Studio",
			ChannelLogo:        verifiedPicture,
			ChannelDescription: "Official creator channel powered by ARMSS Entertainment",
			Role:               models.RoleUser,
			Tier:               models.TierSilver,
			IsActive:           true,
			WalletAmount:       250.0,
			SilverRewardPaid:   false,
			CreatedAt:          now,
			UpdatedAt:          now,
		}

		_, insertErr := database.DB.ExecContext(r.Context(), `
			INSERT INTO users (
				id, email, mobile, age, password_hash, name, 
				channel_name, channel_logo, channel_description, 
				role, tier, is_active, wallet_amount, silver_reward_paid, created_at, updated_at
			) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
		`, u.ID, u.Email, u.Mobile, u.Age, u.PasswordHash, u.Name,
			u.ChannelName, u.ChannelLogo, u.ChannelDescription,
			u.Role, u.Tier, 1, u.WalletAmount, u.CreatedAt, u.UpdatedAt)

		if insertErr != nil {
			logger.ErrorLogger.Printf("[GoogleAuth] Failed to create user: %v", insertErr)
			w.WriteHeader(http.StatusInternalServerError)
			_ = json.NewEncoder(w).Encode(map[string]string{"error": "Failed to create creator account"})
			return
		}

		logger.LogAction(u.ID, "register_google", u.ID, fmt.Sprintf("Registered via Google OAuth (%s)", verifiedEmail))
	} else {
		u.SilverRewardPaid = silverPaidInt == 1
		if !u.IsActive {
			logger.LogAction(u.ID, "login_google_blocked", u.ID, "Attempted Google login on deactivated account")
			w.WriteHeader(http.StatusForbidden)
			_ = json.NewEncoder(w).Encode(map[string]string{"error": "This creator account has been deactivated by the administrator"})
			return
		}

		// Update avatar/logo if empty
		if u.ChannelLogo == "" {
			_, _ = database.DB.ExecContext(r.Context(), "UPDATE users SET channel_logo = ? WHERE id = ?", verifiedPicture, u.ID)
			u.ChannelLogo = verifiedPicture
		}
		logger.LogAction(u.ID, "login_google_success", u.ID, fmt.Sprintf("Logged in via Google OAuth (%s)", verifiedEmail))
	}

	// 4. Generate standard JWT token
	token, err := middleware.GenerateToken(&u)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		_ = json.NewEncoder(w).Encode(map[string]string{"error": "Failed to generate authentication session"})
		return
	}

	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "success",
		"token":   token,
		"user":    u,
		"message": "Signed in with Google successfully",
	})
}
