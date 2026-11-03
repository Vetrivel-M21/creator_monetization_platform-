package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"

	"creator-monetization-backend/database"
	"creator-monetization-backend/logger"
	"creator-monetization-backend/middleware"

	"github.com/go-chi/chi/v5"
)

type Category struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Slug        string    `json:"slug"`
	Description string    `json:"description"`
	Icon        string    `json:"icon"`
	IsActive    bool      `json:"is_active"`
	VideoCount  int       `json:"video_count"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

var nonAlphaNumRegex = regexp.MustCompile("[^a-z0-9]+")

func slugify(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	s = nonAlphaNumRegex.ReplaceAllString(s, "-")
	return strings.Trim(s, "-")
}

// ListCategories returns all categories (publicly active ones, or all if query param all=true)
func ListCategories(w http.ResponseWriter, r *http.Request) {
	showAll := r.URL.Query().Get("all") == "true"

	query := `
		SELECT c.id, c.name, c.slug, COALESCE(c.description, ''), COALESCE(c.icon, 'Tag'), 
		       c.is_active, c.created_at, c.updated_at,
		       (SELECT COUNT(*) FROM videos v WHERE v.category = c.slug) as video_count
		FROM categories c
	`
	if !showAll {
		query += " WHERE c.is_active = 1"
	}
	query += " ORDER BY c.name ASC"

	rows, err := database.DB.QueryContext(r.Context(), query)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var categories []Category
	for rows.Next() {
		var cat Category
		var isActiveInt int
		if err := rows.Scan(
			&cat.ID, &cat.Name, &cat.Slug, &cat.Description, &cat.Icon,
			&isActiveInt, &cat.CreatedAt, &cat.UpdatedAt, &cat.VideoCount,
		); err == nil {
			cat.IsActive = (isActiveInt == 1)
			categories = append(categories, cat)
		}
	}

	if categories == nil {
		categories = []Category{}
	}

	jsonResponse(w, http.StatusOK, categories)
}

// AdminCreateCategory creates a new video category
func AdminCreateCategory(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Name        string `json:"name"`
		Slug        string `json:"slug"`
		Description string `json:"description"`
		Icon        string `json:"icon"`
		IsActive    *bool  `json:"is_active"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		http.Error(w, "category name is required", http.StatusBadRequest)
		return
	}

	slug := strings.TrimSpace(req.Slug)
	if slug == "" {
		slug = slugify(req.Name)
	} else {
		slug = slugify(slug)
	}

	if slug == "" {
		http.Error(w, "invalid category slug", http.StatusBadRequest)
		return
	}

	// Check for duplicates
	var count int
	_ = database.DB.QueryRowContext(r.Context(), "SELECT COUNT(*) FROM categories WHERE slug = ? OR LOWER(name) = LOWER(?)", slug, req.Name).Scan(&count)
	if count > 0 {
		http.Error(w, "a category with this name or slug already exists", http.StatusConflict)
		return
	}

	icon := strings.TrimSpace(req.Icon)
	if icon == "" {
		icon = "Tag"
	}

	isActive := 1
	if req.IsActive != nil && !*req.IsActive {
		isActive = 0
	}

	id := randomID("cat")
	now := time.Now()

	_, err := database.DB.ExecContext(r.Context(), `
		INSERT INTO categories (id, name, slug, description, icon, is_active, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`, id, req.Name, slug, strings.TrimSpace(req.Description), icon, isActive, now, now)
	if err != nil {
		http.Error(w, fmt.Sprintf("failed to create category: %v", err), http.StatusInternalServerError)
		return
	}

	adminClaims := middleware.GetUserFromContext(r)
	actor := "admin"
	if adminClaims != nil {
		actor = adminClaims.UserID
	}
	logger.LogAction(actor, "admin_create_category", id, fmt.Sprintf("Created category %s (%s)", req.Name, slug))

	cat := Category{
		ID:          id,
		Name:        req.Name,
		Slug:        slug,
		Description: strings.TrimSpace(req.Description),
		Icon:        icon,
		IsActive:    isActive == 1,
		VideoCount:  0,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	jsonResponse(w, http.StatusCreated, cat)
}

// AdminUpdateCategory updates an existing video category
func AdminUpdateCategory(w http.ResponseWriter, r *http.Request) {
	catID := chi.URLParam(r, "id")

	var req struct {
		Name        string `json:"name"`
		Slug        string `json:"slug"`
		Description string `json:"description"`
		Icon        string `json:"icon"`
		IsActive    *bool  `json:"is_active"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return
	}

	// Check if category exists
	var existing Category
	var isActiveInt int
	err := database.DB.QueryRowContext(r.Context(), `
		SELECT id, name, slug, COALESCE(description, ''), COALESCE(icon, 'Tag'), is_active
		FROM categories WHERE id = ?
	`, catID).Scan(&existing.ID, &existing.Name, &existing.Slug, &existing.Description, &existing.Icon, &isActiveInt)
	if err == sql.ErrNoRows {
		http.Error(w, "category not found", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	name := strings.TrimSpace(req.Name)
	if name == "" {
		name = existing.Name
	}

	slug := strings.TrimSpace(req.Slug)
	if slug == "" {
		slug = existing.Slug
	} else {
		slug = slugify(slug)
	}

	// Check duplicate slug if changed
	if slug != existing.Slug {
		var count int
		_ = database.DB.QueryRowContext(r.Context(), "SELECT COUNT(*) FROM categories WHERE slug = ? AND id != ?", slug, catID).Scan(&count)
		if count > 0 {
			http.Error(w, "another category with this slug already exists", http.StatusConflict)
			return
		}
	}

	icon := strings.TrimSpace(req.Icon)
	if icon == "" {
		icon = existing.Icon
	}

	description := req.Description
	if strings.TrimSpace(description) == "" && req.Description == "" {
		description = existing.Description
	}

	isActive := isActiveInt
	if req.IsActive != nil {
		if *req.IsActive {
			isActive = 1
		} else {
			isActive = 0
		}
	}

	now := time.Now()
	_, err = database.DB.ExecContext(r.Context(), `
		UPDATE categories 
		SET name = ?, slug = ?, description = ?, icon = ?, is_active = ?, updated_at = ?
		WHERE id = ?
	`, name, slug, description, icon, isActive, now, catID)
	if err != nil {
		http.Error(w, fmt.Sprintf("failed to update category: %v", err), http.StatusInternalServerError)
		return
	}

	// If slug changed, cascade update existing videos category identifier
	if slug != existing.Slug {
		_, _ = database.DB.ExecContext(r.Context(), "UPDATE videos SET category = ? WHERE category = ?", slug, existing.Slug)
	}

	adminClaims := middleware.GetUserFromContext(r)
	actor := "admin"
	if adminClaims != nil {
		actor = adminClaims.UserID
	}
	logger.LogAction(actor, "admin_update_category", catID, fmt.Sprintf("Updated category %s (%s)", name, slug))

	var videoCount int
	_ = database.DB.QueryRowContext(r.Context(), "SELECT COUNT(*) FROM videos WHERE category = ?", slug).Scan(&videoCount)

	jsonResponse(w, http.StatusOK, Category{
		ID:          catID,
		Name:        name,
		Slug:        slug,
		Description: description,
		Icon:        icon,
		IsActive:    isActive == 1,
		VideoCount:  videoCount,
		UpdatedAt:   now,
	})
}

// AdminDeleteCategory deletes a video category
func AdminDeleteCategory(w http.ResponseWriter, r *http.Request) {
	catID := chi.URLParam(r, "id")

	var slug, name string
	err := database.DB.QueryRowContext(r.Context(), "SELECT slug, name FROM categories WHERE id = ?", catID).Scan(&slug, &name)
	if err == sql.ErrNoRows {
		http.Error(w, "category not found", http.StatusNotFound)
		return
	} else if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	// Check if videos are assigned to this category
	var videoCount int
	_ = database.DB.QueryRowContext(r.Context(), "SELECT COUNT(*) FROM videos WHERE category = ?", slug).Scan(&videoCount)
	if videoCount > 0 {
		http.Error(w, fmt.Sprintf("Cannot delete category: %d video(s) are currently categorized as '%s'. Reassign or delete the videos first, or deactivate the category.", videoCount, name), http.StatusBadRequest)
		return
	}

	_, err = database.DB.ExecContext(r.Context(), "DELETE FROM categories WHERE id = ?", catID)
	if err != nil {
		http.Error(w, fmt.Sprintf("failed to delete category: %v", err), http.StatusInternalServerError)
		return
	}

	adminClaims := middleware.GetUserFromContext(r)
	actor := "admin"
	if adminClaims != nil {
		actor = adminClaims.UserID
	}
	logger.LogAction(actor, "admin_delete_category", catID, fmt.Sprintf("Deleted category %s (%s)", name, slug))

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"status":  "deleted",
		"id":      catID,
		"message": fmt.Sprintf("Category '%s' was deleted successfully", name),
	})
}
