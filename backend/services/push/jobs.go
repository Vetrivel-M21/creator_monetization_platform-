package push

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"log"
	"strings"

	"firebase.google.com/go/v4/messaging"
)

const maxAttempts = 5

type jobRow struct {
	ID           int64
	Kind         string
	TargetID     string
	TargetFilter string
	Payload      Payload
	Attempts     int
	Cursor       int64
	Sent         int
	Failed       int
}

func newToken() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func (s *Service) sendUser(ctx context.Context, j *jobRow) error {
	tokens, err := s.repo.TokensByUser(ctx, j.TargetID)
	if err != nil {
		return fmt.Errorf("fetching user tokens: %w", err)
	}
	if len(tokens) == 0 {
		return nil
	}

	sent, failed, err := s.sendBatch(ctx, tokens, j.Payload)
	j.Sent += sent
	j.Failed += failed
	return err
}

func (s *Service) sendAdmins(ctx context.Context, j *jobRow) error {
	tokens, err := s.repo.TokensByAdmins(ctx)
	if err != nil {
		return fmt.Errorf("fetching admin tokens: %w", err)
	}
	if len(tokens) == 0 {
		return nil
	}

	sent, failed, err := s.sendBatch(ctx, tokens, j.Payload)
	j.Sent += sent
	j.Failed += failed
	return err
}

func (s *Service) sendChannel(ctx context.Context, j *jobRow) error {
	for {
		ids, tokens, err := s.repo.TokensByChannelBatch(ctx, j.TargetID, j.Cursor, 500)
		if err != nil {
			return fmt.Errorf("fetching channel tokens batch: %w", err)
		}
		if len(tokens) == 0 {
			return nil
		}

		sent, failed, err := s.sendBatch(ctx, tokens, j.Payload)
		if err != nil {
			return err
		}

		j.Cursor = ids[len(ids)-1]
		j.Sent += sent
		j.Failed += failed

		s.exec(`
			UPDATE push_jobs 
			SET cursor_id=?, sent_count=?, failed_count=?, updated_at=CURRENT_TIMESTAMP 
			WHERE id=?`, j.Cursor, j.Sent, j.Failed, j.ID)
	}
}

func (s *Service) sendBroadcast(ctx context.Context, j *jobRow) error {
	filter := strings.ToLower(strings.TrimSpace(j.TargetFilter))

	// By Creator Tier
	if strings.HasPrefix(filter, "tier:") {
		tier := strings.TrimPrefix(filter, "tier:")
		tokens, err := s.repo.TokensByTier(ctx, tier)
		if err != nil {
			return fmt.Errorf("fetching tier tokens: %w", err)
		}
		if len(tokens) == 0 {
			return nil
		}
		sent, failed, err := s.sendBatch(ctx, tokens, j.Payload)
		j.Sent += sent
		j.Failed += failed
		return err
	}

	// Admins segment
	if filter == "admins" {
		return s.sendAdmins(ctx, j)
	}

	// All users broadcast (batch walking)
	for {
		ids, tokens, err := s.repo.TokensAllBatch(ctx, j.Cursor, 500)
		if err != nil {
			return fmt.Errorf("fetching broadcast tokens batch: %w", err)
		}
		if len(tokens) == 0 {
			return nil
		}

		sent, failed, err := s.sendBatch(ctx, tokens, j.Payload)
		if err != nil {
			return err
		}

		j.Cursor = ids[len(ids)-1]
		j.Sent += sent
		j.Failed += failed

		s.exec(`
			UPDATE push_jobs 
			SET cursor_id=?, sent_count=?, failed_count=?, updated_at=CURRENT_TIMESTAMP 
			WHERE id=?`, j.Cursor, j.Sent, j.Failed, j.ID)
	}
}

func (s *Service) sendBatch(ctx context.Context, tokens []string, p Payload) (int, int, error) {
	if s.client == nil {
		return 0, 0, fmt.Errorf("FCM messaging client is not initialized")
	}

	msg := buildMessage(tokens, p)
	resp, err := s.client.SendEachForMulticast(ctx, msg)
	if err != nil {
		return 0, 0, err
	}

	sent := 0
	failed := 0
	for i, r := range resp.Responses {
		if r.Success {
			sent++
			continue
		}
		failed++
		if messaging.IsUnregistered(r.Error) {
			log.Printf("[Push] Pruning expired/unregistered token: %s", tokens[i][:15]+"...")
			_ = s.repo.DeleteDevice(ctx, tokens[i])
		}
	}

	return sent, failed, nil
}

func buildMessage(tokens []string, p Payload) *messaging.MulticastMessage {
	img := ""
	if strings.HasPrefix(p.ImageURL, "https://") || strings.HasPrefix(p.ImageURL, "http://") {
		img = p.ImageURL
	}

	msg := &messaging.MulticastMessage{
		Tokens: tokens,
		Notification: &messaging.Notification{
			Title:    p.Title,
			Body:     p.Body,
			ImageURL: img,
		},
		Data: p.Data,
	}

	if img != "" {
		msg.APNS = &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{MutableContent: true},
			},
			FCMOptions: &messaging.APNSFCMOptions{
				ImageURL: img,
			},
		}
		msg.Webpush = &messaging.WebpushConfig{
			Notification: &messaging.WebpushNotification{
				Image: img,
			},
		}
	}

	return msg
}

