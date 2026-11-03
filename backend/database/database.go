package database

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	_ "github.com/go-sql-driver/mysql"
	"golang.org/x/crypto/bcrypt"
	_ "modernc.org/sqlite"
)

var (
	DB         *sql.DB
	DriverName string
)

func InitDatabase() (*sql.DB, error) {
	mysqlUser := getEnv("MYSQL_USER", "root")
	mysqlPass := getEnv("MYSQL_PASSWORD", "Vetri@123")
	mysqlHost := getEnv("MYSQL_HOST", "127.0.0.1")
	mysqlPort := getEnv("MYSQL_PORT", "3306")
	mysqlDB := getEnv("MYSQL_DATABASE", "creator_platform")
	mysqlDSN := os.Getenv("MYSQL_DSN")

	if mysqlDSN == "" {
		mysqlDSN = fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?parseTime=true&charset=utf8mb4&loc=Local",
			mysqlUser, mysqlPass, mysqlHost, mysqlPort, mysqlDB)
	}

	log.Printf("[Database] Attempting connection to MySQL (%s:%s/%s)...", mysqlHost, mysqlPort, mysqlDB)
	mdb, err := sql.Open("mysql", mysqlDSN)
	if err == nil {
		mdb.SetMaxOpenConns(25)
		mdb.SetMaxIdleConns(10)
		mdb.SetConnMaxLifetime(5 * time.Minute)

		if pingErr := mdb.Ping(); pingErr == nil {
			log.Println("[Database] ✓ MySQL Connected Successfully!")
			DB = mdb
			DriverName = "mysql"
			if initErr := createTables("mysql"); initErr != nil {
				return nil, fmt.Errorf("migrating mysql tables: %w", initErr)
			}
			return DB, nil
		} else {
			log.Printf("[Database] MySQL ping failed (%v). Falling back to embedded SQLite...", pingErr)
			_ = mdb.Close()
		}
	} else {
		log.Printf("[Database] MySQL connection failed (%v). Falling back to embedded SQLite...", err)
	}

	// ── SQLite Fallback for Local Dev ──
	sqlitePath := getEnv("SQLITE_PATH", "./data/creator_platform.db")
	_ = os.MkdirAll(filepath.Dir(sqlitePath), 0755)

	sdb, sErr := sql.Open("sqlite", sqlitePath+"?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)&_pragma=foreign_keys(ON)")
	if sErr != nil {
		return nil, fmt.Errorf("opening sqlite: %w", sErr)
	}
	sdb.SetMaxOpenConns(1)

	if pingErr := sdb.Ping(); pingErr != nil {
		return nil, fmt.Errorf("sqlite ping failed: %w", pingErr)
	}

	log.Printf("[Database] ✓ Connected to SQLite (%s)", sqlitePath)
	DB = sdb
	DriverName = "sqlite"

	if initErr := createTables("sqlite"); initErr != nil {
		return nil, fmt.Errorf("migrating sqlite tables: %w", initErr)
	}

	return DB, nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func createTables(driver string) error {
	var schema string
	if driver == "mysql" {
		schema = `
		CREATE TABLE IF NOT EXISTS users (
			id VARCHAR(64) PRIMARY KEY,
			email VARCHAR(191) UNIQUE,
			mobile VARCHAR(32) UNIQUE,
			password_hash VARCHAR(255) NOT NULL,
			name VARCHAR(100) NOT NULL,
			role VARCHAR(20) NOT NULL DEFAULT 'user',
			tier VARCHAR(20) NOT NULL DEFAULT 'silver',
			is_active BOOLEAN NOT NULL DEFAULT TRUE,
			wallet_amount DECIMAL(12, 2) NOT NULL DEFAULT 250.00,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

		CREATE TABLE IF NOT EXISTS user_kyc (
			user_id VARCHAR(64) PRIMARY KEY,
			aadhaar_number VARCHAR(32),
			pan_number VARCHAR(32),
			bank_account VARCHAR(64),
			ifsc_code VARCHAR(32),
			bank_name VARCHAR(100),
			account_holder VARCHAR(100),
			agreement_agreed BOOLEAN NOT NULL DEFAULT FALSE,
			is_verified BOOLEAN NOT NULL DEFAULT FALSE,
			verified_at DATETIME NULL,
			FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

		CREATE TABLE IF NOT EXISTS videos (
			id VARCHAR(64) PRIMARY KEY,
			user_id VARCHAR(64) NOT NULL,
			creator_name VARCHAR(100) NOT NULL,
			creator_tier VARCHAR(20) NOT NULL DEFAULT 'silver',
			title VARCHAR(255) NOT NULL,
			description TEXT,
			category VARCHAR(32) NOT NULL,
			video_type VARCHAR(20) NOT NULL DEFAULT 'landscape',
			duration_minutes DOUBLE NOT NULL DEFAULT 2.0,
			video_url TEXT NOT NULL,
			thumbnail_url TEXT,
			status VARCHAR(32) NOT NULL DEFAULT 'pending_review',
			reject_reason TEXT,
			views_count BIGINT NOT NULL DEFAULT 0,
			likes_count BIGINT NOT NULL DEFAULT 0,
			shares_count BIGINT NOT NULL DEFAULT 0,
			comments_count BIGINT NOT NULL DEFAULT 0,
			total_watch_mins DOUBLE NOT NULL DEFAULT 0,
			total_earned DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
			KEY idx_video_status (status),
			KEY idx_video_category (category),
			FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

		CREATE TABLE IF NOT EXISTS video_comments (
			id VARCHAR(64) PRIMARY KEY,
			video_id VARCHAR(64) NOT NULL,
			user_id VARCHAR(64) NOT NULL,
			user_name VARCHAR(100) NOT NULL,
			content TEXT NOT NULL,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY(video_id) REFERENCES videos(id) ON DELETE CASCADE,
			FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

		CREATE TABLE IF NOT EXISTS wallet_transactions (
			id VARCHAR(64) PRIMARY KEY,
			user_id VARCHAR(64) NOT NULL,
			amount DECIMAL(12, 2) NOT NULL,
			type VARCHAR(64) NOT NULL,
			description TEXT NOT NULL,
			balance_after DECIMAL(12, 2) NOT NULL,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

		CREATE TABLE IF NOT EXISTS payout_requests (
			id VARCHAR(64) PRIMARY KEY,
			user_id VARCHAR(64) NOT NULL,
			amount DECIMAL(12, 2) NOT NULL,
			status VARCHAR(32) NOT NULL DEFAULT 'pending',
			cf_transfer_id VARCHAR(128),
			cf_reference_id VARCHAR(128),
			beneficiary_name VARCHAR(100),
			bank_account VARCHAR(64),
			ifsc VARCHAR(32),
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
			FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

		CREATE TABLE IF NOT EXISTS platform_settings (
			setting_key VARCHAR(64) PRIMARY KEY,
			setting_value TEXT NOT NULL,
			updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

		CREATE TABLE IF NOT EXISTS categories (
			id VARCHAR(64) PRIMARY KEY,
			name VARCHAR(100) NOT NULL UNIQUE,
			slug VARCHAR(100) NOT NULL UNIQUE,
			description TEXT,
			icon VARCHAR(64) DEFAULT 'Tag',
			is_active BOOLEAN NOT NULL DEFAULT TRUE,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
		`
	} else {
		schema = `
		CREATE TABLE IF NOT EXISTS users (
			id TEXT PRIMARY KEY,
			email TEXT UNIQUE,
			mobile TEXT UNIQUE,
			password_hash TEXT NOT NULL,
			name TEXT NOT NULL,
			role TEXT NOT NULL DEFAULT 'user',
			tier TEXT NOT NULL DEFAULT 'silver',
			is_active INTEGER NOT NULL DEFAULT 1,
			wallet_amount REAL NOT NULL DEFAULT 250.0,
			created_at DATETIME NOT NULL,
			updated_at DATETIME NOT NULL
		);

		CREATE TABLE IF NOT EXISTS user_kyc (
			user_id TEXT PRIMARY KEY,
			aadhaar_number TEXT,
			pan_number TEXT,
			bank_account TEXT,
			ifsc_code TEXT,
			bank_name TEXT,
			account_holder TEXT,
			agreement_agreed INTEGER NOT NULL DEFAULT 0,
			is_verified INTEGER NOT NULL DEFAULT 0,
			verified_at DATETIME,
			FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
		);

		CREATE TABLE IF NOT EXISTS videos (
			id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			creator_name TEXT NOT NULL,
			creator_tier TEXT NOT NULL,
			title TEXT NOT NULL,
			description TEXT,
			category TEXT NOT NULL,
			video_type TEXT NOT NULL DEFAULT 'landscape',
			duration_minutes REAL NOT NULL DEFAULT 2.0,
			video_url TEXT NOT NULL,
			thumbnail_url TEXT,
			status TEXT NOT NULL DEFAULT 'pending_review',
			reject_reason TEXT,
			views_count INTEGER NOT NULL DEFAULT 0,
			likes_count INTEGER NOT NULL DEFAULT 0,
			shares_count INTEGER NOT NULL DEFAULT 0,
			comments_count INTEGER NOT NULL DEFAULT 0,
			total_watch_mins REAL NOT NULL DEFAULT 0,
			total_earned REAL NOT NULL DEFAULT 0,
			created_at DATETIME NOT NULL,
			updated_at DATETIME NOT NULL,
			FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
		);

		CREATE TABLE IF NOT EXISTS video_comments (
			id TEXT PRIMARY KEY,
			video_id TEXT NOT NULL,
			user_id TEXT NOT NULL,
			user_name TEXT NOT NULL,
			content TEXT NOT NULL,
			created_at DATETIME NOT NULL,
			FOREIGN KEY(video_id) REFERENCES videos(id) ON DELETE CASCADE
		);

		CREATE TABLE IF NOT EXISTS wallet_transactions (
			id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			amount REAL NOT NULL,
			type TEXT NOT NULL,
			description TEXT NOT NULL,
			balance_after REAL NOT NULL,
			created_at DATETIME NOT NULL,
			FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
		);

		CREATE TABLE IF NOT EXISTS payout_requests (
			id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			amount REAL NOT NULL,
			status TEXT NOT NULL DEFAULT 'pending',
			cf_transfer_id TEXT,
			cf_reference_id TEXT,
			beneficiary_name TEXT,
			bank_account TEXT,
			ifsc TEXT,
			created_at DATETIME NOT NULL,
			updated_at DATETIME NOT NULL,
			FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
		);

		CREATE TABLE IF NOT EXISTS platform_settings (
			setting_key TEXT PRIMARY KEY,
			setting_value TEXT NOT NULL,
			updated_at DATETIME NOT NULL
		);

		CREATE TABLE IF NOT EXISTS categories (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL UNIQUE,
			slug TEXT NOT NULL UNIQUE,
			description TEXT,
			icon TEXT DEFAULT 'Tag',
			is_active INTEGER NOT NULL DEFAULT 1,
			created_at DATETIME NOT NULL,
			updated_at DATETIME NOT NULL
		);
		`
	}

	queries := strings.Split(schema, ";")
	for _, q := range queries {
		q = strings.TrimSpace(q)
		if q == "" {
			continue
		}
		if _, err := DB.Exec(q); err != nil {
			log.Printf("[Database] Note on query execution: %v", err)
		}
	}

	// Auto-migrate videos table columns for HLS & CMAF ABR Transcoding & Video Format Type
	_, _ = DB.Exec("ALTER TABLE videos ADD COLUMN master_path TEXT")
	_, _ = DB.Exec("ALTER TABLE videos ADD COLUMN hls_path TEXT")
	_, _ = DB.Exec("ALTER TABLE videos ADD COLUMN hls_url TEXT")
	_, _ = DB.Exec("ALTER TABLE videos ADD COLUMN transcode_status TEXT DEFAULT 'ready'")
	_, _ = DB.Exec("ALTER TABLE videos ADD COLUMN video_type TEXT DEFAULT 'landscape'")
	_, _ = DB.Exec("UPDATE videos SET video_type = 'landscape' WHERE video_type IS NULL OR video_type = ''")
	_, _ = DB.Exec("UPDATE videos SET video_type = 'short' WHERE duration_minutes <= 2.0")

	// Auto-migrate users table columns for Age, Creator Channel Details & Silver Milestone Reward Tracking
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN age INTEGER DEFAULT 0")
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN channel_name TEXT")
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN channel_logo TEXT")
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN channel_description TEXT")
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN silver_reward_paid INTEGER DEFAULT 0")
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN silver_reward_paid_at DATETIME")

	// Multi-Tier Monetization Tracking (Gold & Diamond)
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN gold_reward_paid INTEGER DEFAULT 0")
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN gold_reward_paid_at DATETIME")
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN diamond_reward_paid INTEGER DEFAULT 0")
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN diamond_reward_paid_at DATETIME")

	// User Lifecycle, Approvals & Temporary Suspension
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN account_status TEXT DEFAULT 'active'")
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN suspension_reason TEXT")
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN suspended_at DATETIME")
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN approved_at DATETIME")
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN approved_by TEXT")
	_, _ = DB.Exec("ALTER TABLE users ADD COLUMN rejection_reason TEXT")
	_, _ = DB.Exec("UPDATE users SET account_status = 'active' WHERE account_status IS NULL OR account_status = ''")

	// Live Support Chat Tables
	_, _ = DB.Exec(`
		CREATE TABLE IF NOT EXISTS support_threads (
			id TEXT PRIMARY KEY,
			user_id TEXT NOT NULL,
			user_name TEXT NOT NULL,
			user_email TEXT NOT NULL,
			subject TEXT NOT NULL DEFAULT 'Creator Support',
			status TEXT NOT NULL DEFAULT 'open',
			unread_admin_count INTEGER NOT NULL DEFAULT 0,
			unread_user_count INTEGER NOT NULL DEFAULT 0,
			last_message TEXT,
			last_message_at DATETIME NOT NULL,
			created_at DATETIME NOT NULL,
			updated_at DATETIME NOT NULL,
			FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
		);
	`)
	_, _ = DB.Exec(`
		CREATE TABLE IF NOT EXISTS support_messages (
			id TEXT PRIMARY KEY,
			thread_id TEXT NOT NULL,
			sender_id TEXT NOT NULL,
			sender_name TEXT NOT NULL,
			sender_role TEXT NOT NULL,
			message TEXT NOT NULL,
			created_at DATETIME NOT NULL,
			FOREIGN KEY(thread_id) REFERENCES support_threads(id) ON DELETE CASCADE
		);
	`)

	seedCategories()
	seedInitialData(driver)
	return nil
}

func seedCategories() {
	now := time.Now()
	defaultCategories := []struct {
		id, name, slug, desc, icon string
	}{
		{"cat-self", "Self / Personal Brand", "self", "Personal vlogs, tutorials, opinion pieces, and individual portfolios", "User"},
		{"cat-product", "Product Review", "product", "Detailed hardware, gadget, software, and physical product unboxings and evaluations", "Package"},
		{"cat-business", "Business & MSME", "business", "Company profiles, entrepreneurial case studies, and enterprise workflows", "Briefcase"},
		{"cat-promotion", "Promotion & Sponsorship", "promotion", "Sponsored brand partnerships, promotional clips, and commercial campaigns", "Megaphone"},
	}

	for _, c := range defaultCategories {
		var cExists int
		_ = DB.QueryRow("SELECT COUNT(*) FROM categories WHERE slug = ? OR id = ?", c.slug, c.id).Scan(&cExists)
		if cExists == 0 {
			_, _ = DB.Exec(`
				INSERT INTO categories (id, name, slug, description, icon, is_active, created_at, updated_at)
				VALUES (?, ?, ?, ?, ?, 1, ?, ?)
			`, c.id, c.name, c.slug, c.desc, c.icon, now, now)
		}
	}
}

func seedInitialData(driver string) {
	now := time.Now()
	// Dynamic bcrypt hash for 'admin123'
	hashBytes, _ := bcrypt.GenerateFromPassword([]byte("admin123"), bcrypt.DefaultCost)
	adminHash := string(hashBytes)

	// Ensure the initial production root administrator account (admin@armss.com / admin123) exists
	var adminCount int
	_ = DB.QueryRow("SELECT COUNT(*) FROM users WHERE email = 'admin@armss.com'").Scan(&adminCount)
	if adminCount == 0 {
		_, _ = DB.Exec(`
			INSERT INTO users (id, email, mobile, age, password_hash, name, channel_name, channel_logo, channel_description, role, tier, is_active, account_status, wallet_amount, silver_reward_paid, gold_reward_paid, diamond_reward_paid, created_at, updated_at)
			VALUES ('admin-01', 'admin@armss.com', '9876543210', 32, ?, 'ARMSS Administrator', 'ARMSS Media Official', 'https://api.dicebear.com/7.x/bottts/svg?seed=admin', 'Official platform moderation & administration.', 'admin', 'diamond', 1, 'active', 0.0, 1, 1, 1, ?, ?)
		`, adminHash, now, now)
		log.Println("[Database] ✓ Production admin account created: admin@armss.com")
	} else {
		// Ensure admin status is active, role is admin, and password matches admin123
		_, _ = DB.Exec("UPDATE users SET password_hash = ?, role = 'admin', is_active = 1, account_status = 'active' WHERE email = 'admin@armss.com'", adminHash)
	}

	// Purge all default sample/testing dummy records for clean production start
	_, _ = DB.Exec("DELETE FROM users WHERE email = 'creator1@armss.com' OR id = 'usr-01'")
	_, _ = DB.Exec("DELETE FROM wallet_transactions WHERE id = 'tx-w1' OR user_id = 'usr-01'")
	_, _ = DB.Exec("DELETE FROM videos WHERE id IN ('vid-1', 'vid-2', 'vid-3', 'vid-4') OR user_id = 'usr-01'")

	// Seed default platform settings
	defaultSettings := map[string]string{
		"payout_mode":        "fixed_per_video",
		"fixed_rate_silver":  "50.00",
		"fixed_rate_gold":    "65.00",
		"fixed_rate_diamond": "85.00",
		"rate_30m":           "80.00",
		"rate_20m":           "60.00",
		"rate_10m":           "50.00",
		"rate_5m":            "35.00",
		"rate_2m":            "25.00",
		"milestone_silver":   "2500.00",
		"milestone_gold":     "5000.00",
		"milestone_diamond":  "10000.00",
		"ban_ai_videos":      "true",
	}

	for k, v := range defaultSettings {
		var exists int
		_ = DB.QueryRow("SELECT COUNT(*) FROM platform_settings WHERE setting_key = ?", k).Scan(&exists)
		if exists == 0 {
			_, _ = DB.Exec("INSERT INTO platform_settings (setting_key, setting_value, updated_at) VALUES (?, ?, ?)", k, v, now)
		}
	}

	log.Println("[Database] ✓ Database initialized with production admin and clean state.")
}
