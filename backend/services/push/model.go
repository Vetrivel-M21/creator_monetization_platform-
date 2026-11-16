package push

import "time"

// Payload defines the cross-platform notification content
type Payload struct {
	Title    string            `json:"title"`
	Body     string            `json:"body"`
	ImageURL string            `json:"image_url,omitempty"` // Public HTTPS image URL
	Data     map[string]string `json:"data,omitempty"`      // Screen navigation, id, metadata
}

// DeviceReq is the payload sent from Flutter or React to register or delete a device token
type DeviceReq struct {
	Token    string `json:"token"`
	Platform string `json:"platform"` // "android", "ios", "web"
}

// CustomPushReq is submitted by an Admin to dispatch custom announcements or targeted notifications
type CustomPushReq struct {
	Title          string `json:"title"`
	Body           string `json:"body"`
	ImageURL       string `json:"image_url,omitempty"`
	TargetAudience string `json:"target_audience"` // "all", "tier:silver", "tier:gold", "tier:diamond", "admins", "user"
	TargetUserID   string `json:"target_user_id,omitempty"`
	TargetScreen   string `json:"target_screen,omitempty"`
	TargetID       string `json:"target_id,omitempty"`
}

// PushJob represents a row in the push_jobs table
type PushJob struct {
	ID           int64     `json:"id"`
	DedupeKey    *string   `json:"dedupe_key,omitempty"`
	Kind         string    `json:"kind"` // "user", "channel", "admin", "broadcast"
	TargetID     string    `json:"target_id"`
	TargetFilter *string   `json:"target_filter,omitempty"`
	Payload      Payload   `json:"payload"`
	Status       string    `json:"status"` // "pending", "processing", "done", "failed"
	Attempts     int       `json:"attempts"`
	CursorID     int64     `json:"cursor_id"`
	SentCount    int       `json:"sent_count"`
	FailedCount  int       `json:"failed_count"`
	LastError    *string   `json:"last_error,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

