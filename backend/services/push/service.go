package push

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

type Service struct {
	enabled bool
	client  *messaging.Client
	db      *sql.DB
	repo    Repository
}

// New initializes the FCM push service. Failure-isolated: any initialization problem
// disables push notifications safely and logs the error without stopping the server.
func New(ctx context.Context, db *sql.DB, repo Repository, enabled bool, credsFile string) *Service {
	s := &Service{db: db, repo: repo}
	if !enabled {
		log.Println("[Push] Push notifications disabled (PUSH_ENABLED != true)")
		return s
	}

	if credsFile == "" {
		log.Println("[Push] FIREBASE_CREDENTIALS_FILE not provided, push notifications disabled")
		return s
	}

	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(credsFile))
	if err != nil {
		log.Printf("[Push] Firebase init failed, push disabled: %v", err)
		return s
	}

	client, err := app.Messaging(ctx)
	if err != nil {
		log.Printf("[Push] FCM Messaging client init failed, push disabled: %v", err)
		return s
	}

	s.client = client
	s.enabled = true

	// Launch background persistent worker
	go s.worker(ctx)
	log.Println("[Push] ✓ Push notifications enabled & background worker running")
	return s
}

// NotifyUser sends a push notification to all devices of one user
func (s *Service) NotifyUser(userID string, p Payload) {
	if s == nil || !s.enabled {
		return
	}
	s.enqueue("user", userID, "", "", p)
}

// NotifyAdmins sends a push notification to all registered administrator accounts
func (s *Service) NotifyAdmins(p Payload, dedupeKey string) {
	if s == nil || !s.enabled {
		return
	}
	s.enqueue("admin", "", "admins", dedupeKey, p)
}

// NotifyChannelSubscribers sends a push notification to every non-muted subscriber of a creator channel
func (s *Service) NotifyChannelSubscribers(channelID string, p Payload, dedupeKey string) {
	if s == nil || !s.enabled {
		return
	}
	s.enqueue("channel", channelID, "", dedupeKey, p)
}

// Broadcast sends a push notification to a platform segment ("all", "tier:silver", "tier:gold", "tier:diamond")
func (s *Service) Broadcast(filter string, p Payload, dedupeKey string) {
	if s == nil || !s.enabled {
		return
	}
	s.enqueue("broadcast", "", filter, dedupeKey, p)
}

// enqueue non-blockingly inserts a push job into the database
func (s *Service) enqueue(kind, targetID, targetFilter, dedupeKey string, p Payload) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				log.Printf("[Push] Enqueue panic: %v", r)
			}
		}()

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		b, err := json.Marshal(p)
		if err != nil {
			log.Printf("[Push] Enqueue JSON marshal failed: %v", err)
			return
		}

		var dk, tf interface{}
		if dedupeKey != "" {
			dk = dedupeKey
		}
		if targetFilter != "" {
			tf = targetFilter
		}

		query := `
			INSERT INTO push_jobs (dedupe_key, kind, target_id, target_filter, payload)
			VALUES (?, ?, ?, ?, ?)`
		_, err = s.db.ExecContext(ctx, query, dk, kind, targetID, tf, string(b))
		if err != nil && !strings.Contains(err.Error(), "Duplicate") && !strings.Contains(err.Error(), "UNIQUE") {
			log.Printf("[Push] Enqueue DB write failed: %v", err)
		}
	}()
}

func (s *Service) worker(ctx context.Context) {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Println("[Push] Worker stopping due to context cancellation")
			return
		case <-ticker.C:
			s.recoverStuck()
			for {
				j := s.claim()
				if j == nil {
					break
				}
				s.run(j)
			}
		}
	}
}

// claim atomically picks up the next pending job
func (s *Service) claim() *jobRow {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	tok := newToken()
	res, err := s.db.ExecContext(ctx, `
		UPDATE push_jobs
		SET status='processing', attempts=attempts+1, claim_token=?, locked_at=CURRENT_TIMESTAMP
		WHERE status='pending' AND next_attempt_at <= CURRENT_TIMESTAMP
		ORDER BY id ASC LIMIT 1`, tok)
	if err != nil {
		log.Printf("[Push] Claim job update failed: %v", err)
		return nil
	}

	rowsAff, _ := res.RowsAffected()
	if rowsAff == 0 {
		return nil
	}

	var j jobRow
	var raw []byte
	var dedupeKey, targetFilter sql.NullString

	err = s.db.QueryRowContext(ctx, `
		SELECT id, dedupe_key, kind, target_id, target_filter, payload, attempts, cursor_id, sent_count, failed_count
		FROM push_jobs WHERE claim_token=? AND status='processing'`, tok).
		Scan(&j.ID, &dedupeKey, &j.Kind, &j.TargetID, &targetFilter, &raw, &j.Attempts, &j.Cursor, &j.Sent, &j.Failed)

	if err != nil {
		log.Printf("[Push] Claim read error: %v", err)
		return nil
	}

	if targetFilter.Valid {
		j.TargetFilter = targetFilter.String
	}

	if err := json.Unmarshal(raw, &j.Payload); err != nil {
		log.Printf("[Push] Bad payload in job %d: %v", j.ID, err)
		s.exec(`UPDATE push_jobs SET status='failed', last_error='bad payload json' WHERE id=?`, j.ID)
		return nil
	}

	return &j
}

func (s *Service) recoverStuck() {
	// Re-queue jobs that got stuck in processing for over 10 minutes (e.g. server crash)
	s.exec(`
		UPDATE push_jobs 
		SET status='pending' 
		WHERE status='processing' AND locked_at < CURRENT_TIMESTAMP - INTERVAL 10 MINUTE`)
}

func (s *Service) exec(query string, args ...interface{}) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if _, err := s.db.ExecContext(ctx, query, args...); err != nil {
		// Log note if error happens
		log.Printf("[Push] Background exec note: %v", err)
	}
}

func (s *Service) run(j *jobRow) {
	defer func() {
		if r := recover(); r != nil {
			s.retryOrFail(j, fmt.Errorf("panic in worker: %v", r))
		}
	}()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	var err error
	switch j.Kind {
	case "user":
		err = s.sendUser(ctx, j)
	case "admin":
		err = s.sendAdmins(ctx, j)
	case "channel":
		err = s.sendChannel(ctx, j)
	case "broadcast":
		err = s.sendBroadcast(ctx, j)
	default:
		err = fmt.Errorf("unknown job kind: %s", j.Kind)
	}

	if err != nil {
		s.retryOrFail(j, err)
		return
	}

	s.exec(`
		UPDATE push_jobs 
		SET status='done', last_error=NULL, sent_count=?, failed_count=?, updated_at=CURRENT_TIMESTAMP 
		WHERE id=?`, j.Sent, j.Failed, j.ID)
}

func (s *Service) retryOrFail(j *jobRow, cause error) {
	msg := cause.Error()
	if len(msg) > 500 {
		msg = msg[:500]
	}

	log.Printf("[Push] Job %d attempt %d failed: %s", j.ID, j.Attempts, msg)
	if j.Attempts >= maxAttempts {
		s.exec(`UPDATE push_jobs SET status='failed', last_error=?, updated_at=CURRENT_TIMESTAMP WHERE id=?`, msg, j.ID)
		return
	}

	delaySec := (1 << uint(j.Attempts)) * 30 // 60s, 120s, 240s, 480s
	s.exec(`
		UPDATE push_jobs 
		SET status='pending', last_error=?, next_attempt_at=CURRENT_TIMESTAMP + INTERVAL ? SECOND, updated_at=CURRENT_TIMESTAMP 
		WHERE id=?`, msg, delaySec, j.ID)
}
