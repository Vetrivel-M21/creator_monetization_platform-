package handlers

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"creator-monetization-backend/database"
	"creator-monetization-backend/middleware"
	"creator-monetization-backend/models"

	"github.com/go-chi/chi/v5"
)

// GetUserSupportThread retrieves or initializes the active support thread for the logged-in creator.
func GetUserSupportThread(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetUserFromContext(r)
	if claims == nil || claims.UserID == "" {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	var thread models.SupportThread
	var lastMsgAt, createdAt, updatedAt time.Time

	err := database.DB.QueryRowContext(r.Context(), `
		SELECT id, user_id, user_name, user_email, subject, status, 
		       unread_admin_count, unread_user_count, COALESCE(last_message, ''), 
		       last_message_at, created_at, updated_at
		FROM support_threads
		WHERE user_id = ?
		ORDER BY updated_at DESC
		LIMIT 1
	`, claims.UserID).Scan(
		&thread.ID, &thread.UserID, &thread.UserName, &thread.UserEmail,
		&thread.Subject, &thread.Status, &thread.UnreadAdminCount, &thread.UnreadUserCount,
		&thread.LastMessage, &lastMsgAt, &createdAt, &updatedAt,
	)

	now := time.Now()
	if err != nil {
		// Create initial thread
		var u models.User
		_ = database.DB.QueryRowContext(r.Context(), "SELECT name, email FROM users WHERE id = ?", claims.UserID).Scan(&u.Name, &u.Email)
		if u.Name == "" {
			u.Name = "Creator"
		}
		if u.Email == "" {
			u.Email = claims.Email
		}

		thread = models.SupportThread{
			ID:               randomID("thr"),
			UserID:           claims.UserID,
			UserName:         u.Name,
			UserEmail:        u.Email,
			Subject:          "Creator Monetization & Platform Support",
			Status:           "open",
			UnreadAdminCount: 0,
			UnreadUserCount:  0,
			LastMessage:      "Support thread initialized.",
			LastMessageAt:    now,
			CreatedAt:        now,
			UpdatedAt:        now,
		}

		_, _ = database.DB.ExecContext(r.Context(), `
			INSERT INTO support_threads (id, user_id, user_name, user_email, subject, status, unread_admin_count, unread_user_count, last_message, last_message_at, created_at, updated_at)
			VALUES (?, ?, ?, ?, ?, ?, 0, 0, ?, ?, ?, ?)
		`, thread.ID, thread.UserID, thread.UserName, thread.UserEmail, thread.Subject, thread.Status, thread.LastMessage, now, now, now)
	} else {
		thread.LastMessageAt = lastMsgAt
		thread.CreatedAt = createdAt
		thread.UpdatedAt = updatedAt

		// Mark user messages as read
		_, _ = database.DB.ExecContext(r.Context(), "UPDATE support_threads SET unread_user_count = 0 WHERE id = ?", thread.ID)
	}

	// Fetch messages in thread
	rows, err := database.DB.QueryContext(r.Context(), `
		SELECT id, thread_id, sender_id, sender_name, sender_role, message, created_at
		FROM support_messages
		WHERE thread_id = ?
		ORDER BY created_at ASC
	`, thread.ID)

	var messages []models.SupportMessage
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var m models.SupportMessage
			if sErr := rows.Scan(&m.ID, &m.ThreadID, &m.SenderID, &m.SenderName, &m.SenderRole, &m.Message, &m.CreatedAt); sErr == nil {
				messages = append(messages, m)
			}
		}
	}
	if messages == nil {
		messages = []models.SupportMessage{}
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"thread":   thread,
		"messages": messages,
	})
}

// SendUserSupportMessage appends a message from the creator to their support thread.
func SendUserSupportMessage(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetUserFromContext(r)
	if claims == nil || claims.UserID == "" {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	var req struct {
		Message string `json:"message"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid json"}`, http.StatusBadRequest)
		return
	}

	msgText := strings.TrimSpace(req.Message)
	if msgText == "" {
		http.Error(w, `{"error":"message cannot be empty"}`, http.StatusBadRequest)
		return
	}

	var threadID, userName string
	now := time.Now()

	err := database.DB.QueryRowContext(r.Context(), `
		SELECT t.id, COALESCE(u.name, 'Creator')
		FROM support_threads t
		LEFT JOIN users u ON t.user_id = u.id
		WHERE t.user_id = ?
		ORDER BY t.updated_at DESC
		LIMIT 1
	`, claims.UserID).Scan(&threadID, &userName)

	if err != nil {
		threadID = randomID("thr")
		userName = "Creator"
		_, _ = database.DB.ExecContext(r.Context(), `
			INSERT INTO support_threads (id, user_id, user_name, user_email, subject, status, unread_admin_count, unread_user_count, last_message, last_message_at, created_at, updated_at)
			VALUES (?, ?, ?, ?, 'Creator Support', 'open', 1, 0, ?, ?, ?, ?)
		`, threadID, claims.UserID, userName, claims.Email, msgText, now, now, now)
	} else {
		_, _ = database.DB.ExecContext(r.Context(), `
			UPDATE support_threads 
			SET last_message = ?, last_message_at = ?, unread_admin_count = unread_admin_count + 1, status = 'open', updated_at = ?
			WHERE id = ?
		`, msgText, now, now, threadID)
	}

	msgID := randomID("msg")
	_, err = database.DB.ExecContext(r.Context(), `
		INSERT INTO support_messages (id, thread_id, sender_id, sender_name, sender_role, message, created_at)
		VALUES (?, ?, ?, ?, 'user', ?, ?)
	`, msgID, threadID, claims.UserID, userName, msgText, now)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	jsonResponse(w, http.StatusCreated, models.SupportMessage{
		ID:         msgID,
		ThreadID:   threadID,
		SenderID:   claims.UserID,
		SenderName: userName,
		SenderRole: "user",
		Message:    msgText,
		CreatedAt:  now,
	})
}

// AdminListSupportThreads returns all active support threads for administrative monitoring.
func AdminListSupportThreads(w http.ResponseWriter, r *http.Request) {
	rows, err := database.DB.QueryContext(r.Context(), `
		SELECT t.id, t.user_id, t.user_name, t.user_email, t.subject, t.status, 
		       t.unread_admin_count, t.unread_user_count, COALESCE(t.last_message, ''), 
		       t.last_message_at, t.created_at, t.updated_at
		FROM support_threads t
		ORDER BY t.last_message_at DESC
	`)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var threads []models.SupportThread
	for rows.Next() {
		var t models.SupportThread
		if sErr := rows.Scan(
			&t.ID, &t.UserID, &t.UserName, &t.UserEmail, &t.Subject, &t.Status,
			&t.UnreadAdminCount, &t.UnreadUserCount, &t.LastMessage,
			&t.LastMessageAt, &t.CreatedAt, &t.UpdatedAt,
		); sErr == nil {
			threads = append(threads, t)
		}
	}
	if threads == nil {
		threads = []models.SupportThread{}
	}

	jsonResponse(w, http.StatusOK, threads)
}

// AdminGetSupportThreadMessages returns full conversation history for a given thread.
func AdminGetSupportThreadMessages(w http.ResponseWriter, r *http.Request) {
	threadID := chi.URLParam(r, "id")

	// Reset unread admin count
	_, _ = database.DB.ExecContext(r.Context(), "UPDATE support_threads SET unread_admin_count = 0 WHERE id = ?", threadID)

	rows, err := database.DB.QueryContext(r.Context(), `
		SELECT id, thread_id, sender_id, sender_name, sender_role, message, created_at
		FROM support_messages
		WHERE thread_id = ?
		ORDER BY created_at ASC
	`, threadID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var messages []models.SupportMessage
	for rows.Next() {
		var m models.SupportMessage
		if sErr := rows.Scan(&m.ID, &m.ThreadID, &m.SenderID, &m.SenderName, &m.SenderRole, &m.Message, &m.CreatedAt); sErr == nil {
			messages = append(messages, m)
		}
	}
	if messages == nil {
		messages = []models.SupportMessage{}
	}

	jsonResponse(w, http.StatusOK, messages)
}

// AdminReplySupportThread sends a message from the admin to the creator's thread.
func AdminReplySupportThread(w http.ResponseWriter, r *http.Request) {
	threadID := chi.URLParam(r, "id")
	claims := middleware.GetUserFromContext(r)

	var req struct {
		Message string `json:"message"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid json"}`, http.StatusBadRequest)
		return
	}

	msgText := strings.TrimSpace(req.Message)
	if msgText == "" {
		http.Error(w, `{"error":"message cannot be empty"}`, http.StatusBadRequest)
		return
	}

	adminID := "admin"
	adminName := "Platform Support"
	if claims != nil {
		adminID = claims.UserID
	}

	now := time.Now()
	msgID := randomID("msg")

	_, err := database.DB.ExecContext(r.Context(), `
		INSERT INTO support_messages (id, thread_id, sender_id, sender_name, sender_role, message, created_at)
		VALUES (?, ?, ?, ?, 'admin', ?, ?)
	`, msgID, threadID, adminID, adminName, msgText, now)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	_, _ = database.DB.ExecContext(r.Context(), `
		UPDATE support_threads 
		SET last_message = ?, last_message_at = ?, unread_user_count = unread_user_count + 1, updated_at = ?
		WHERE id = ?
	`, msgText, now, now, threadID)

	jsonResponse(w, http.StatusCreated, models.SupportMessage{
		ID:         msgID,
		ThreadID:   threadID,
		SenderID:   adminID,
		SenderName: adminName,
		SenderRole: "admin",
		Message:    msgText,
		CreatedAt:  now,
	})
}

// AdminUpdateSupportStatus toggles thread status between 'open' and 'resolved'.
func AdminUpdateSupportStatus(w http.ResponseWriter, r *http.Request) {
	threadID := chi.URLParam(r, "id")
	var req struct {
		Status string `json:"status"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)
	if req.Status != "open" && req.Status != "resolved" {
		req.Status = "resolved"
	}

	_, err := database.DB.ExecContext(r.Context(), "UPDATE support_threads SET status = ?, updated_at = ? WHERE id = ?", req.Status, time.Now(), threadID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	jsonResponse(w, http.StatusOK, map[string]string{
		"thread_id": threadID,
		"status":    req.Status,
	})
}

