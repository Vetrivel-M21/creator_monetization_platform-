package models

import "time"

type UserRole string

const (
	RoleUser  UserRole = "user"
	RoleAdmin UserRole = "admin"
)

type CreatorTier string

const (
	TierSilver  CreatorTier = "silver"
	TierGold    CreatorTier = "gold"
	TierDiamond CreatorTier = "diamond"
)

type VideoCategory string

const (
	CatPromotion VideoCategory = "promotion"
	CatProduct   VideoCategory = "product"
	CatBusiness  VideoCategory = "business"
	CatSelf      VideoCategory = "self"
)

type VideoStatus string

const (
	StatusPending  VideoStatus = "pending_review"
	StatusApproved VideoStatus = "approved"
	StatusRejected VideoStatus = "rejected"
)

type User struct {
	ID                  string      `json:"id"`
	Email               string      `json:"email"`
	Mobile              string      `json:"mobile"`
	Age                 int         `json:"age,omitempty"`
	PasswordHash        string      `json:"-"`
	Name                string      `json:"name"`
	ChannelName         string      `json:"channel_name,omitempty"`
	ChannelLogo         string      `json:"channel_logo,omitempty"`
	ChannelDescription  string      `json:"channel_description,omitempty"`
	Role                UserRole    `json:"role"`
	Tier                CreatorTier `json:"tier"`
	IsActive            bool        `json:"is_active"`
	AccountStatus       string      `json:"account_status"` // "pending_approval", "active", "suspended", "rejected"
	SuspensionReason    string      `json:"suspension_reason,omitempty"`
	SuspendedAt         *time.Time  `json:"suspended_at,omitempty"`
	ApprovedAt          *time.Time  `json:"approved_at,omitempty"`
	ApprovedBy          string      `json:"approved_by,omitempty"`
	RejectionReason     string      `json:"rejection_reason,omitempty"`
	WalletAmount        float64     `json:"wallet_amount"`
	SilverRewardPaid    bool        `json:"silver_reward_paid"`
	SilverRewardPaidAt  *time.Time  `json:"silver_reward_paid_at,omitempty"`
	GoldRewardPaid      bool        `json:"gold_reward_paid"`
	GoldRewardPaidAt    *time.Time  `json:"gold_reward_paid_at,omitempty"`
	DiamondRewardPaid   bool        `json:"diamond_reward_paid"`
	DiamondRewardPaidAt *time.Time  `json:"diamond_reward_paid_at,omitempty"`
	CreatedAt           time.Time   `json:"created_at"`
	UpdatedAt           time.Time   `json:"updated_at"`
}

type UserKYC struct {
	UserID          string     `json:"user_id"`
	AadhaarNumber   string     `json:"aadhaar_number"`
	PANNumber       string     `json:"pan_number"`
	BankAccount     string     `json:"bank_account"`
	IFSCCode        string     `json:"ifsc_code"`
	BankName        string     `json:"bank_name"`
	AccountHolder   string     `json:"account_holder"`
	AgreementAgreed bool       `json:"agreement_agreed"`
	IsVerified      bool       `json:"is_verified"`
	VerifiedAt      *time.Time `json:"verified_at,omitempty"`
}

type Video struct {
	ID              string        `json:"id"`
	UserID          string        `json:"user_id"`
	CreatorName     string        `json:"creator_name"`
	CreatorTier     CreatorTier   `json:"creator_tier"`
	Title           string        `json:"title"`
	Description     string        `json:"description"`
	Category        VideoCategory `json:"category"`
	VideoType       string        `json:"video_type,omitempty"` // "landscape" or "short"
	DurationMinutes float64       `json:"duration_minutes"`
	VideoURL        string        `json:"video_url"`
	HLSURL          string        `json:"hls_url,omitempty"`
	HLSPath         string        `json:"hls_path,omitempty"`
	MasterPath      string        `json:"master_path,omitempty"`
	ThumbnailURL    string        `json:"thumbnail_url"`
	Status          VideoStatus   `json:"status"`
	TranscodeStatus string        `json:"transcode_status,omitempty"` // "pending", "processing", "ready", "failed"
	RejectReason    string        `json:"reject_reason,omitempty"`
	ViewsCount      int64         `json:"views_count"`
	LikesCount      int64         `json:"likes_count"`
	SharesCount     int64         `json:"shares_count"`
	CommentsCount   int64         `json:"comments_count"`
	TotalWatchMins  float64       `json:"total_watch_mins"`
	TotalEarned     float64       `json:"total_earned"`
	CreatedAt       time.Time     `json:"created_at"`
	UpdatedAt       time.Time     `json:"updated_at"`
}

type VideoComment struct {
	ID        string    `json:"id"`
	VideoID   string    `json:"video_id"`
	UserID    string    `json:"user_id"`
	UserName  string    `json:"user_name"`
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

type WalletTransaction struct {
	ID           string    `json:"id"`
	UserID       string    `json:"user_id"`
	Amount       float64   `json:"amount"`
	Type         string    `json:"type"` // "credit_welcome_bonus", "credit_video_earning", "debit_withdrawal"
	Description  string    `json:"description"`
	BalanceAfter float64   `json:"balance_after"`
	CreatedAt    time.Time `json:"created_at"`
}

type PayoutRequest struct {
	ID              string    `json:"id"`
	UserID          string    `json:"user_id"`
	Amount          float64   `json:"amount"`
	Status          string    `json:"status"` // "pending", "processed", "failed"
	CFTransferID    string    `json:"cf_transfer_id,omitempty"`
	CFReferenceID   string    `json:"cf_reference_id,omitempty"`
	BeneficiaryName string    `json:"beneficiary_name"`
	BankAccount     string    `json:"bank_account"`
	IFSC            string    `json:"ifsc"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
}

type DurationBucketQuota struct {
	Key           string  `json:"key"`
	Label         string  `json:"label"`
	MinMinutes    float64 `json:"min_minutes"`
	ApprovedCount int     `json:"approved_count"`
	TargetCount   int     `json:"target_count"`
	Completed     bool    `json:"completed"`
	RatePerView   float64 `json:"rate_per_view"`
}

type CreatorEligibility struct {
	UserID        string                `json:"user_id"`
	CurrentTier   CreatorTier           `json:"current_tier"`
	IsMonetized   bool                  `json:"is_monetized"`
	TotalEarned   float64               `json:"total_earned"`
	TierCap       float64               `json:"tier_cap"`
	TotalVideos   int                   `json:"total_videos"`
	Buckets       []DurationBucketQuota `json:"buckets"`
	StatusMessage string                `json:"status_message"`
	NextTier      CreatorTier           `json:"next_tier,omitempty"`
	NextTarget    int                   `json:"next_target,omitempty"`
}

type PlatformSettings struct {
	PayoutMode       string  `json:"payout_mode"` // "fixed_per_video", "duration_weighted", "milestone_batch"
	FixedRateSilver  float64 `json:"fixed_rate_silver"`
	FixedRateGold    float64 `json:"fixed_rate_gold"`
	FixedRateDiamond float64 `json:"fixed_rate_diamond"`
	Rate30m          float64 `json:"rate_30m"`
	Rate20m          float64 `json:"rate_20m"`
	Rate10m          float64 `json:"rate_10m"`
	Rate5m           float64 `json:"rate_5m"`
	Rate2m           float64 `json:"rate_2m"`
	MilestoneSilver  float64 `json:"milestone_silver"`
	MilestoneGold    float64 `json:"milestone_gold"`
	MilestoneDiamond float64 `json:"milestone_diamond"`
	BanAIVideos      bool    `json:"ban_ai_videos"`
}

type SupportThread struct {
	ID               string    `json:"id"`
	UserID           string    `json:"user_id"`
	UserName         string    `json:"user_name"`
	UserEmail        string    `json:"user_email"`
	Subject          string    `json:"subject"`
	Status           string    `json:"status"` // "open", "resolved"
	UnreadAdminCount int       `json:"unread_admin_count"`
	UnreadUserCount  int       `json:"unread_user_count"`
	LastMessage      string    `json:"last_message"`
	LastMessageAt    time.Time `json:"last_message_at"`
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
}

type SupportMessage struct {
	ID         string    `json:"id"`
	ThreadID   string    `json:"thread_id"`
	SenderID   string    `json:"sender_id"`
	SenderName string    `json:"sender_name"`
	SenderRole string    `json:"sender_role"` // "user" or "admin"
	Message    string    `json:"message"`
	CreatedAt  time.Time `json:"created_at"`
}
