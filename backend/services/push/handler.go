package push

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"creator-monetization-backend/middleware"

	"github.com/go-chi/chi/v5"
)

type Handler struct {
	svc  *Service
	repo Repository
}

func NewHandler(svc *Service, repo Repository) *Handler {
	return &Handler{svc: svc, repo: repo}
}

// RegisterRoutes mounts all push notification endpoints onto Chi router
func (h *Handler) RegisterRoutes(r chi.Router) {
	r.Route("/push", func(r chi.Router) {
		// Device token registration (Authenticated or Guest Device)
		r.Post("/devices", h.RegisterDevice)
		r.Delete("/devices", h.UnregisterDevice)

		// Channel alerts subscriptions (Protected)
		r.With(middleware.RequireAuth).Put("/channels/{id}/subscription", h.UpdateSubscription)
		r.With(middleware.RequireAuth).Delete("/channels/{id}/subscription", h.DeleteSubscription)

		// Admin Custom Push Desk & History (Protected by Admin Role)
		r.With(middleware.RequireAuth, middleware.RequireAdmin).Post("/admin/send", h.AdminSendNotification)
		r.With(middleware.RequireAuth, middleware.RequireAdmin).Get("/admin/history", h.AdminGetHistory)
	})
}

func (h *Handler) RegisterDevice(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	claims := middleware.GetUserFromContext(r)
	userID := "guest"
	if claims != nil && claims.UserID != "" {
		userID = claims.UserID
	}

	var req DeviceReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.TrimSpace(req.Token) == "" {
		http.Error(w, `{"error":"invalid device token payload"}`, http.StatusBadRequest)
		return
	}

	platform := strings.ToLower(strings.TrimSpace(req.Platform))
	if platform != "android" && platform != "ios" && platform != "web" {
		platform = "web"
	}

	if err := h.repo.UpsertDevice(r.Context(), userID, req.Token, platform); err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"failed to register device: %v"}`, err), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"success","message":"device registered successfully"}`))
}

func (h *Handler) UnregisterDevice(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	var req DeviceReq
	_ = json.NewDecoder(r.Body).Decode(&req)
	token := strings.TrimSpace(req.Token)
	if token == "" {
		token = r.URL.Query().Get("token")
	}

	if token != "" {
		_ = h.repo.DeleteDevice(r.Context(), token)
	}

	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"success","message":"device unregistered"}`))
}

func (h *Handler) UpdateSubscription(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	claims := middleware.GetUserFromContext(r)
	if claims == nil || claims.UserID == "" {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	channelID := chi.URLParam(r, "id")
	if channelID == "" {
		http.Error(w, `{"error":"missing channel_id"}`, http.StatusBadRequest)
		return
	}

	var req struct {
		Muted bool `json:"muted"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)

	if err := h.repo.Subscribe(r.Context(), claims.UserID, channelID, req.Muted); err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"failed to update subscription: %v"}`, err), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"success","message":"channel notification preferences updated"}`))
}

func (h *Handler) DeleteSubscription(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	claims := middleware.GetUserFromContext(r)
	if claims == nil || claims.UserID == "" {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	channelID := chi.URLParam(r, "id")
	if channelID == "" {
		http.Error(w, `{"error":"missing channel_id"}`, http.StatusBadRequest)
		return
	}

	_ = h.repo.Unsubscribe(r.Context(), claims.UserID, channelID)
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"success","message":"unsubscribed from channel notifications"}`))
}

func (h *Handler) AdminSendNotification(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	claims := middleware.GetUserFromContext(r)
	if claims == nil || claims.Role != "admin" {
		http.Error(w, `{"error":"forbidden: admin access required"}`, http.StatusForbidden)
		return
	}

	var req CustomPushReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request format"}`, http.StatusBadRequest)
		return
	}

	req.Title = strings.TrimSpace(req.Title)
	req.Body = strings.TrimSpace(req.Body)
	if req.Title == "" || req.Body == "" {
		http.Error(w, `{"error":"title and message body are required"}`, http.StatusBadRequest)
		return
	}

	payload := Payload{
		Title:    req.Title,
		Body:     req.Body,
		ImageURL: strings.TrimSpace(req.ImageURL),
		Data: map[string]string{
			"screen": req.TargetScreen,
			"id":     req.TargetID,
		},
	}

	aud := strings.ToLower(strings.TrimSpace(req.TargetAudience))
	switch aud {
	case "all":
		h.svc.Broadcast("all", payload, "")
	case "admins":
		h.svc.NotifyAdmins(payload, "")
	case "tier:silver", "tier:gold", "tier:diamond":
		h.svc.Broadcast(aud, payload, "")
	case "user":
		if strings.TrimSpace(req.TargetUserID) == "" {
			http.Error(w, `{"error":"target_user_id is required when target_audience is user"}`, http.StatusBadRequest)
			return
		}
		h.svc.NotifyUser(req.TargetUserID, payload)
	default:
		// Default to all users if unspecified
		h.svc.Broadcast("all", payload, "")
	}

	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte(`{"status":"success","message":"push notification enqueued successfully for delivery"}`))
}

func (h *Handler) AdminGetHistory(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	jobs, err := h.repo.GetRecentJobs(r.Context(), 50)
	if err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"failed to fetch jobs history: %v"}`, err), http.StatusInternalServerError)
		return
	}

	if jobs == nil {
		jobs = []PushJob{}
	}

	resp, err := json.Marshal(map[string]interface{}{
		"status": "success",
		"jobs":   jobs,
	})
	if err != nil {
		http.Error(w, `{"error":"failed to encode response"}`, http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(resp)
}

