package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"creator-monetization-backend/database"
	"creator-monetization-backend/handlers"
	"creator-monetization-backend/logger"
	"creator-monetization-backend/middleware"
	"creator-monetization-backend/services/playback"
	"creator-monetization-backend/services/transcode"

	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"
)

func main() {
	// 1. Initialize Logger
	logger.InitLogger()
	log.Println("[CreatorPlatform] Starting application...")

	// 2. Initialize Database (MySQL with SQLite automatic fallback)
	db, err := database.InitDatabase()
	if err != nil {
		log.Fatalf("[CreatorPlatform] Fatal database initialization failure: %v", err)
	}
	defer db.Close()

	// 2.1 Initialize Video Transcoder & Storage
	if err := transcode.InitTranscoder(); err != nil {
		log.Printf("[CreatorPlatform] Warning: Transcoder initialization: %v", err)
	}

	// 3. Router & Global Middleware Stack
	r := chi.NewRouter()
	r.Use(chiMiddleware.RequestID)
	r.Use(chiMiddleware.RealIP)
	r.Use(chiMiddleware.Recoverer)
	r.Use(middleware.RequestLogger)

	// Cross-Origin Resource Sharing (CORS)
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
			origin := req.Header.Get("Origin")
			if origin != "" {
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Set("Access-Control-Allow-Credentials", "true")
			} else {
				w.Header().Set("Access-Control-Allow-Origin", "*")
			}
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, HEAD, PATCH")
			
			reqHeaders := req.Header.Get("Access-Control-Request-Headers")
			if reqHeaders != "" {
				w.Header().Set("Access-Control-Allow-Headers", reqHeaders)
			} else {
				w.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type, Content-Length, Accept-Encoding, Authorization, X-CSRF-Token, Range, Origin, Cache-Control, Pragma, X-Requested-With")
			}
			w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Range, Content-Type, Authorization")
			w.Header().Set("Access-Control-Max-Age", "86400")

			if req.Method == http.MethodOptions {
				w.WriteHeader(http.StatusOK)
				return
			}
			next.ServeHTTP(w, req)
		})
	})

	// Static Assets (Thumbnails, Channel Logos & Direct Masters)
	r.Handle("/thumbnails/*", http.StripPrefix("/thumbnails", http.FileServer(http.Dir("data/thumbnails"))))
	r.Handle("/logos/*", http.StripPrefix("/logos", http.FileServer(http.Dir("data/logos"))))
	r.Handle("/data/masters/*", http.StripPrefix("/data/masters", http.FileServer(http.Dir("data/masters"))))
	r.Handle("/data/hls/*", http.StripPrefix("/data/hls", http.FileServer(http.Dir("data/hls"))))

	// Root-level Playback Routes (for direct /playback proxy support)
	r.Get("/playback/{id}/master.m3u8", playback.ServeMasterPlaylist)
	r.Head("/playback/{id}/master.m3u8", playback.ServeMasterPlaylist)
	r.Get("/playback/{id}/{file}", playback.ServeSegmentFile)
	r.Head("/playback/{id}/{file}", playback.ServeSegmentFile)

	// 4. API Routes
	r.Route("/api", func(r chi.Router) {
		// Public Health Endpoint
		r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			_, _ = w.Write([]byte(`{"status":"healthy","database":"` + database.DriverName + `","version":"2.0.0"}`))
		})

		// Public Auth
		r.Post("/auth/login", handlers.Login)
		r.Post("/auth/register", handlers.Register)
		r.Post("/auth/send-otp", handlers.SendEmailOTP)
		r.Post("/auth/verify-otp", handlers.VerifyEmailOTP)
		r.Post("/auth/google", handlers.GoogleLogin)

		// User Profile & Creator Branding (Protected)
		r.With(middleware.RequireAuth).Get("/user/profile", handlers.GetProfile)
		r.With(middleware.RequireAuth).Put("/user/profile", handlers.UpdateProfile)
		r.With(middleware.RequireAuth).Post("/user/channel-logo", handlers.UploadChannelLogo)

		// Public Videos & Feed
		r.Get("/videos", handlers.ListVideos)
		r.With(middleware.RequireAuth).Get("/videos/{id}/playback", playback.GetPlaybackTicket)
		r.With(middleware.RequireAuth).Post("/videos", handlers.CreateVideo)
		r.With(middleware.RequireAuth).Post("/videos/upload", handlers.UploadVideo)
		r.Post("/videos/{id}/like", handlers.LikeVideo)
		r.Post("/videos/{id}/share", handlers.ShareVideo)
		r.Post("/videos/{id}/view", handlers.ViewVideo)
		r.Get("/videos/{id}/comments", handlers.ListComments)
		r.Post("/videos/{id}/comments", handlers.CreateComment)

		// Adaptive Bitrate HLS Playback Engine (fMP4 CMAF Streaming)
		r.Get("/playback/{id}/master.m3u8", playback.ServeMasterPlaylist)
		r.Head("/playback/{id}/master.m3u8", playback.ServeMasterPlaylist)
		r.Get("/playback/{id}/{file}", playback.ServeSegmentFile)
		r.Head("/playback/{id}/{file}", playback.ServeSegmentFile)

		// Wallet & Payouts (Protected)
		r.With(middleware.RequireAuth).Get("/wallet/{id}", handlers.GetWallet)
		r.With(middleware.RequireAuth).Post("/wallet/withdraw", handlers.RequestWithdrawal)

		// Creator Monetization Eligibility & Quotas
		r.With(middleware.RequireAuth).Get("/creator/eligibility", handlers.GetCreatorEligibility)
		r.Get("/creator/{id}/eligibility", handlers.GetCreatorEligibility)

		// KYC Verification (Protected)
		r.With(middleware.RequireAuth).Post("/kyc", handlers.SubmitKYC)
		r.With(middleware.RequireAuth).Get("/kyc", handlers.GetKYC)

		// Platform Settings
		r.Get("/settings", handlers.GetPlatformSettings)

		// Video Categories (Public)
		r.Get("/categories", handlers.ListCategories)

		// Creator Support Chat (Protected)
		r.With(middleware.RequireAuth).Get("/support/thread", handlers.GetUserSupportThread)
		r.With(middleware.RequireAuth).Post("/support/message", handlers.SendUserSupportMessage)

		// Admin Moderation Desk (Protected by JWT and Admin Role)
		r.Route("/admin", func(r chi.Router) {
			r.Use(middleware.RequireAuth)
			r.Use(middleware.RequireAdmin)
			r.Get("/videos", handlers.AdminListVideos)
			r.Put("/videos/{id}/verify", handlers.AdminVerifyVideo)
			r.Delete("/videos/{id}", handlers.AdminDeleteVideo)
			r.Get("/users", handlers.AdminListUsers)
			r.Put("/users/{id}/toggle-active", handlers.AdminToggleUserActive)
			r.Put("/users/{id}/role", handlers.AdminUpdateUserRole)
			r.Delete("/users/{id}", handlers.AdminDeleteUser)
			r.Post("/users/{id}/block", handlers.AdminBlockUser)
			r.Post("/users/{id}/unblock", handlers.AdminUnblockUser)
			r.Post("/users/{id}/approve", handlers.AdminApproveUser)
			r.Post("/users/{id}/reject", handlers.AdminRejectUser)
			r.Get("/support/threads", handlers.AdminListSupportThreads)
			r.Get("/support/threads/{id}/messages", handlers.AdminGetSupportThreadMessages)
			r.Post("/support/threads/{id}/reply", handlers.AdminReplySupportThread)
			r.Put("/support/threads/{id}/status", handlers.AdminUpdateSupportStatus)
			r.Get("/categories", handlers.ListCategories)
			r.Post("/categories", handlers.AdminCreateCategory)
			r.Put("/categories/{id}", handlers.AdminUpdateCategory)
			r.Delete("/categories/{id}", handlers.AdminDeleteCategory)
			r.Get("/kyc", handlers.AdminListKYC)
			r.Put("/kyc/{id}/verify", handlers.AdminVerifyKYC)
			r.Get("/settings", handlers.GetPlatformSettings)
			r.Put("/settings", handlers.UpdatePlatformSettings)
		})
	})

	// 5. HTTP Server Configuration
	port := os.Getenv("PORT")
	if port == "" {
		port = "2085"
	}

	server := &http.Server{
		Addr:              ":" + port,
		Handler:           r,
		ReadHeaderTimeout: 30 * time.Second,
		ReadTimeout:       30 * time.Minute,
		WriteTimeout:      30 * time.Minute,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		log.Printf("[CreatorPlatform] ✓ HTTP Server running on http://localhost:%s (Engine: %s)", port, database.DriverName)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server startup failed: %v", err)
		}
	}()

	// 6. Graceful Shutdown Listener
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop

	log.Println("[CreatorPlatform] Initiating graceful shutdown...")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = server.Shutdown(ctx)
	log.Println("[CreatorPlatform] Server exited cleanly.")
}
