package push

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"

	"creator-monetization-backend/database"
)

type Repository interface {
	UpsertDevice(ctx context.Context, userID, token, platform string) error
	DeleteDevice(ctx context.Context, token string) error
	TokensByUser(ctx context.Context, userID string) ([]string, error)
	TokensByAdmins(ctx context.Context) ([]string, error)
	TokensByTier(ctx context.Context, tier string) ([]string, error)
	TokensAllBatch(ctx context.Context, cursorID int64, limit int) ([]int64, []string, error)
	TokensByChannelBatch(ctx context.Context, channelID string, cursorID int64, limit int) ([]int64, []string, error)
	Subscribe(ctx context.Context, userID, channelID string, muted bool) error
	Unsubscribe(ctx context.Context, userID, channelID string) error
	GetRecentJobs(ctx context.Context, limit int) ([]PushJob, error)
}

type sqlRepo struct {
	db *sql.DB
}

func NewRepository(db *sql.DB) Repository {
	return &sqlRepo{db: db}
}

func (r *sqlRepo) UpsertDevice(ctx context.Context, userID, token, platform string) error {
	if database.DriverName == "mysql" {
		query := `
			INSERT INTO push_device_tokens (user_id, token, platform)
			VALUES (?, ?, ?)
			ON DUPLICATE KEY UPDATE
				user_id = VALUES(user_id),
				platform = VALUES(platform),
				updated_at = CURRENT_TIMESTAMP`
		_, err := r.db.ExecContext(ctx, query, userID, token, platform)
		return err
	}

	// SQLite dialect
	query := `
		INSERT INTO push_device_tokens (user_id, token, platform)
		VALUES (?, ?, ?)
		ON CONFLICT(token) DO UPDATE SET
			user_id = excluded.user_id,
			platform = excluded.platform,
			updated_at = CURRENT_TIMESTAMP`
	_, err := r.db.ExecContext(ctx, query, userID, token, platform)
	return err
}

func (r *sqlRepo) DeleteDevice(ctx context.Context, token string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM push_device_tokens WHERE token = ?`, token)
	return err
}

func (r *sqlRepo) TokensByUser(ctx context.Context, userID string) ([]string, error) {
	rows, err := r.db.QueryContext(ctx, `SELECT token FROM push_device_tokens WHERE user_id = ?`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}
	return tokens, rows.Err()
}

func (r *sqlRepo) TokensByAdmins(ctx context.Context) ([]string, error) {
	query := `
		SELECT t.token 
		FROM push_device_tokens t
		JOIN users u ON u.id = t.user_id
		WHERE u.role = 'admin'`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}
	return tokens, rows.Err()
}

func (r *sqlRepo) TokensByTier(ctx context.Context, tier string) ([]string, error) {
	query := `
		SELECT t.token 
		FROM push_device_tokens t
		JOIN users u ON u.id = t.user_id
		WHERE u.tier = ?`
	rows, err := r.db.QueryContext(ctx, query, tier)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}
	return tokens, rows.Err()
}

func (r *sqlRepo) TokensAllBatch(ctx context.Context, cursorID int64, limit int) ([]int64, []string, error) {
	query := `
		SELECT id, token 
		FROM push_device_tokens 
		WHERE id > ? 
		ORDER BY id ASC 
		LIMIT ?`
	rows, err := r.db.QueryContext(ctx, query, cursorID, limit)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()

	var ids []int64
	var tokens []string
	for rows.Next() {
		var id int64
		var tok string
		if err := rows.Scan(&id, &tok); err != nil {
			return nil, nil, err
		}
		ids = append(ids, id)
		tokens = append(tokens, tok)
	}
	return ids, tokens, rows.Err()
}

func (r *sqlRepo) TokensByChannelBatch(ctx context.Context, channelID string, cursorID int64, limit int) ([]int64, []string, error) {
	query := `
		SELECT t.id, t.token
		FROM push_subscriptions s
		JOIN push_device_tokens t ON t.user_id = s.user_id
		WHERE s.channel_id = ? AND s.muted = 0 AND t.id > ?
		ORDER BY t.id ASC
		LIMIT ?`
	rows, err := r.db.QueryContext(ctx, query, channelID, cursorID, limit)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()

	var ids []int64
	var tokens []string
	for rows.Next() {
		var id int64
		var tok string
		if err := rows.Scan(&id, &tok); err != nil {
			return nil, nil, err
		}
		ids = append(ids, id)
		tokens = append(tokens, tok)
	}
	return ids, tokens, rows.Err()
}

func (r *sqlRepo) Subscribe(ctx context.Context, userID, channelID string, muted bool) error {
	mutedInt := 0
	if muted {
		mutedInt = 1
	}

	if database.DriverName == "mysql" {
		query := `
			INSERT INTO push_subscriptions (user_id, channel_id, muted)
			VALUES (?, ?, ?)
			ON DUPLICATE KEY UPDATE muted = VALUES(muted)`
		_, err := r.db.ExecContext(ctx, query, userID, channelID, mutedInt)
		return err
	}

	query := `
		INSERT INTO push_subscriptions (user_id, channel_id, muted)
		VALUES (?, ?, ?)
		ON CONFLICT(channel_id, user_id) DO UPDATE SET muted = excluded.muted`
	_, err := r.db.ExecContext(ctx, query, userID, channelID, mutedInt)
	return err
}

func (r *sqlRepo) Unsubscribe(ctx context.Context, userID, channelID string) error {
	_, err := r.db.ExecContext(ctx, `DELETE FROM push_subscriptions WHERE user_id = ? AND channel_id = ?`, userID, channelID)
	return err
}

func (r *sqlRepo) GetRecentJobs(ctx context.Context, limit int) ([]PushJob, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	query := `
		SELECT id, dedupe_key, kind, target_id, target_filter, payload, status,
		       attempts, cursor_id, sent_count, failed_count, last_error, created_at, updated_at
		FROM push_jobs
		ORDER BY id DESC
		LIMIT ?`
	rows, err := r.db.QueryContext(ctx, query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var jobs []PushJob
	for rows.Next() {
		var j PushJob
		var payloadStr string
		var dedupeKey, targetFilter, lastError sql.NullString

		if err := rows.Scan(
			&j.ID, &dedupeKey, &j.Kind, &j.TargetID, &targetFilter,
			&payloadStr, &j.Status, &j.Attempts, &j.CursorID,
			&j.SentCount, &j.FailedCount, &lastError,
			&j.CreatedAt, &j.UpdatedAt,
		); err != nil {
			log.Printf("[Push] Failed scanning push job row: %v", err)
			continue
		}

		if dedupeKey.Valid {
			j.DedupeKey = &dedupeKey.String
		}
		if targetFilter.Valid {
			j.TargetFilter = &targetFilter.String
		}
		if lastError.Valid {
			j.LastError = &lastError.String
		}

		_ = json.Unmarshal([]byte(payloadStr), &j.Payload)
		jobs = append(jobs, j)
	}

	return jobs, nil
}
