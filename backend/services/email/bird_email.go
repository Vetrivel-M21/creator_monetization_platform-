package email

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

// BirdConfig holds API parameters for Bird email dispatch
type BirdConfig struct {
	APIKey    string
	APIURL    string
	FromEmail string
	FromName  string
}

// GetBirdConfig retrieves configuration from environment or defaults
func GetBirdConfig() BirdConfig {
	apiKey := os.Getenv("BIRD_API_KEY")

	apiURL := os.Getenv("BIRD_API_URL")
	if apiURL == "" {
		apiURL = "https://eu1.platform.bird.com/v1/email/messages"
	}

	fromEmail := os.Getenv("BIRD_FROM_EMAIL")
	if fromEmail == "" {
		fromEmail = "noreply@arminfo.in"
	}

	fromName := os.Getenv("BIRD_FROM_NAME")
	if fromName == "" {
		fromName = "ARMSS Gateway"
	}

	return BirdConfig{
		APIKey:    apiKey,
		APIURL:    apiURL,
		FromEmail: fromEmail,
		FromName:  fromName,
	}
}

// BirdEmailPayload defines the payload sent to Bird /v1/email/messages
type BirdEmailPayload struct {
	From    string   `json:"from"`
	To      []string `json:"to"`
	Subject string   `json:"subject"`
	HTML    string   `json:"html"`
}

// SendVerificationOTP sends a 6-digit email OTP using the Bird Email API
func SendVerificationOTP(recipientEmail, otpCode string) error {
	cfg := GetBirdConfig()
	cleanRecipient := strings.TrimSpace(strings.ToLower(recipientEmail))

	subject := fmt.Sprintf("%s • Your Verification Code: %s", cfg.FromName, otpCode)

	// Modern, dark-mode responsive HTML template
	htmlBody := fmt.Sprintf(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>%s</title>
</head>
<body style="margin: 0; padding: 0; background-color: #090A0F; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #F4F6FB;">
  <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%%" style="background-color: #090A0F; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%%" style="max-width: 520px; background-color: #11131A; border: 1px solid #232736; border-radius: 8px; overflow: hidden; box-shadow: 0 16px 36px rgba(0, 0, 0, 0.45);">
          <!-- Header Banner -->
          <tr>
            <td style="padding: 24px 28px; background-color: #171923; border-bottom: 1px solid #232736;">
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%%">
                <tr>
                  <td>
                    <span style="font-size: 16px; font-weight: 800; color: #F4F6FB; letter-spacing: -0.02em;">
                      ARMSS ENTERTAINMENT <span style="color: #FF3366;">●</span>
                    </span>
                    <span style="display: block; font-size: 10px; font-weight: 700; color: #7E869B; text-transform: uppercase; letter-spacing: 0.05em; margin-top: 2px;">
                      %s Verification Service
                    </span>
                  </td>
                  <td align="right">
                    <span style="display: inline-block; padding: 3px 8px; background-color: rgba(0, 229, 153, 0.12); border: 1px solid rgba(0, 229, 153, 0.3); border-radius: 4px; font-size: 11px; font-weight: 700; color: #00E599;">
                      OTP SECURE
                    </span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main Content -->
          <tr>
            <td style="padding: 32px 28px 24px;">
              <h1 style="margin: 0 0 10px; font-size: 20px; font-weight: 700; color: #F4F6FB; letter-spacing: -0.01em;">
                Confirm Your Email Address
              </h1>
              <p style="margin: 0 0 24px; font-size: 13px; line-height: 1.6; color: #7E869B;">
                Use the one-time verification code below to complete your sign-in to ARMSS Entertainment Platform.
              </p>

              <!-- OTP Code Display Card -->
              <div style="background-color: #171923; border: 1.5px solid #232736; border-radius: 6px; padding: 22px; text-align: center; margin-bottom: 24px;">
                <div style="font-size: 11px; font-weight: 700; color: #7E869B; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 8px;">
                  Your 6-Digit One-Time Password
                </div>
                <div style="font-family: 'Courier New', Courier, monospace; font-size: 36px; font-weight: 800; letter-spacing: 10px; color: #FF3366; text-shadow: 0 2px 12px rgba(255, 51, 102, 0.35);">
                  %s
                </div>
                <div style="font-size: 11px; color: #00E599; margin-top: 8px; font-weight: 600;">
                  Expires in 10 minutes
                </div>
              </div>

              <!-- Security Warning -->
              <table role="presentation" border="0" cellpadding="0" cellspacing="0" width="100%%" style="background-color: rgba(255, 51, 102, 0.06); border-left: 3px solid #FF3366; border-radius: 0 4px 4px 0; padding: 12px 14px; margin-bottom: 24px;">
                <tr>
                  <td style="font-size: 11px; line-height: 1.5; color: #F4F6FB;">
                    <strong>Security Notice:</strong> Never share this OTP with anyone, including staff members. We will never ask for your verification code.
                  </td>
                </tr>
              </table>

              <p style="margin: 0; font-size: 12px; color: #555C6E; line-height: 1.5;">
                If you did not request this code, you can safely ignore this email. Your account remains protected.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 20px 28px; background-color: #0E1017; border-top: 1px solid #232736; text-align: center;">
              <p style="margin: 0 0 4px; font-size: 11px; color: #7E869B;">
                Sent securely by <strong>%s</strong> (%s)
              </p>
              <p style="margin: 0; font-size: 10px; color: #555C6E;">
                ARMSS Entertainment Creator Platform • All Rights Reserved &copy; 2026
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`, cfg.FromName, cfg.FromName, otpCode, cfg.FromName, cfg.FromEmail)

	// Build Bird Email payload
	payload := BirdEmailPayload{
		From:    cfg.FromEmail,
		To:      []string{cleanRecipient},
		Subject: subject,
		HTML:    htmlBody,
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("serializing bird email payload: %w", err)
	}

	// Prepare HTTP request
	req, err := http.NewRequest("POST", cfg.APIURL, bytes.NewBuffer(payloadBytes))
	if err != nil {
		return fmt.Errorf("creating bird request: %w", err)
	}

	req.Header.Set("Authorization", "Bearer "+cfg.APIKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	resp, err := client.Do(req)
	if err != nil {
		log.Printf("[BirdEmail] Network warning sending OTP to %s: %v", cleanRecipient, err)
		return fmt.Errorf("bird email request failed: %w", err)
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		log.Printf("[BirdEmail] Error from Bird API (HTTP %d): %s", resp.StatusCode, string(respBody))
		return fmt.Errorf("bird api error (status %d): %s", resp.StatusCode, string(respBody))
	}

	log.Printf("[BirdEmail] ✓ OTP verification email successfully sent to %s via Bird (Status: %d)", cleanRecipient, resp.StatusCode)
	return nil
}

