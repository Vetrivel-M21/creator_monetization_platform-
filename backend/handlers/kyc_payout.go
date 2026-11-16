package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"

	"creator-monetization-backend/database"
	"creator-monetization-backend/logger"
	"creator-monetization-backend/middleware"
	"creator-monetization-backend/models"
	"creator-monetization-backend/services/payout"
	"creator-monetization-backend/services/push"

	"github.com/go-chi/chi/v5"
)

var payoutSvc = payout.NewPayoutService()

// SubmitKYC allows an authenticated creator to submit their Aadhaar, PAN, and Bank details
func SubmitKYC(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetUserFromContext(r)
	if claims == nil || claims.UserID == "" {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	var req struct {
		AadhaarNumber   string `json:"aadhaar_number"`
		PANNumber       string `json:"pan_number"`
		BankAccount     string `json:"bank_account"`
		IFSCCode        string `json:"ifsc_code"`
		BankName        string `json:"bank_name"`
		AccountHolder   string `json:"account_holder"`
		AgreementAgreed bool   `json:"agreement_agreed"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid json"}`, http.StatusBadRequest)
		return
	}

	aadhaar := strings.TrimSpace(req.AadhaarNumber)
	pan := strings.ToUpper(strings.TrimSpace(req.PANNumber))
	account := strings.TrimSpace(req.BankAccount)
	ifsc := strings.ToUpper(strings.TrimSpace(req.IFSCCode))
	bankName := strings.TrimSpace(req.BankName)
	holder := strings.TrimSpace(req.AccountHolder)

	if !regexp.MustCompile(`^\d{12}$`).MatchString(aadhaar) {
		http.Error(w, `{"error":"aadhaar number must be exactly 12 digits"}`, http.StatusBadRequest)
		return
	}
	if !regexp.MustCompile(`^[A-Z]{5}[0-9]{4}[A-Z]{1}$`).MatchString(pan) {
		http.Error(w, `{"error":"invalid PAN number format (e.g. ABCDE1234F)"}`, http.StatusBadRequest)
		return
	}
	if !regexp.MustCompile(`^\d{9,18}$`).MatchString(account) {
		http.Error(w, `{"error":"bank account number must be between 9 and 18 digits"}`, http.StatusBadRequest)
		return
	}
	if !regexp.MustCompile(`^[A-Z]{4}0[A-Z0-9]{6}$`).MatchString(ifsc) {
		http.Error(w, `{"error":"invalid IFSC code (e.g. HDFC0001234)"}`, http.StatusBadRequest)
		return
	}
	if bankName == "" || holder == "" {
		http.Error(w, `{"error":"bank name and account holder name are required"}`, http.StatusBadRequest)
		return
	}
	if !req.AgreementAgreed {
		http.Error(w, `{"error":"you must agree to the creator payout terms"}`, http.StatusBadRequest)
		return
	}

	now := time.Now()
	query := `
		INSERT INTO user_kyc (user_id, aadhaar_number, pan_number, bank_account, ifsc_code, bank_name, account_holder, agreement_agreed, is_verified, verified_at, rejection_reason, reviewed_by, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0, NULL, '', '', ?)
	`
	if database.DriverName == "mysql" {
		query += ` ON DUPLICATE KEY UPDATE 
			aadhaar_number = VALUES(aadhaar_number),
			pan_number = VALUES(pan_number),
			bank_account = VALUES(bank_account),
			ifsc_code = VALUES(ifsc_code),
			bank_name = VALUES(bank_name),
			account_holder = VALUES(account_holder),
			agreement_agreed = 1,
			is_verified = 0,
			verified_at = NULL,
			rejection_reason = '',
			reviewed_by = '',
			updated_at = VALUES(updated_at)`
	} else {
		query = `
			INSERT OR REPLACE INTO user_kyc (user_id, aadhaar_number, pan_number, bank_account, ifsc_code, bank_name, account_holder, agreement_agreed, is_verified, verified_at, rejection_reason, reviewed_by, updated_at)
			VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0, NULL, '', '', ?)
		`
	}

	_, err := database.DB.ExecContext(r.Context(), query, claims.UserID, aadhaar, pan, account, ifsc, bankName, holder, now)
	if err != nil {
		http.Error(w, fmt.Sprintf(`{"error":"failed to save kyc: %v"}`, err), http.StatusInternalServerError)
		return
	}

	logger.LogAction(claims.UserID, "kyc_submitted", claims.UserID, fmt.Sprintf("PAN: %s, Bank: %s", pan, bankName))
	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"status":  "success",
		"message": "KYC documents submitted successfully. Verification takes up to 24 hours.",
	})
}

// GetKYC retrieves the KYC verification status for the current user
func GetKYC(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetUserFromContext(r)
	if claims == nil || claims.UserID == "" {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	var kyc models.UserKYC
	var rejReason, revBy string
	err := database.DB.QueryRowContext(r.Context(), `
		SELECT user_id, aadhaar_number, pan_number, bank_account, ifsc_code, bank_name, account_holder, 
		       agreement_agreed, is_verified, verified_at, COALESCE(rejection_reason, ''), COALESCE(reviewed_by, ''), updated_at
		FROM user_kyc
		WHERE user_id = ?
	`, claims.UserID).Scan(
		&kyc.UserID, &kyc.AadhaarNumber, &kyc.PANNumber, &kyc.BankAccount, &kyc.IFSCCode,
		&kyc.BankName, &kyc.AccountHolder, &kyc.AgreementAgreed, &kyc.IsVerified, &kyc.VerifiedAt,
		&rejReason, &revBy, &kyc.UpdatedAt,
	)

	if err != nil {
		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"submitted": false,
			"kyc":       nil,
		})
		return
	}

	kyc.RejectionReason = rejReason
	kyc.ReviewedBy = revBy

	// Mask Aadhaar & Bank Account for security
	if len(kyc.AadhaarNumber) == 12 {
		kyc.AadhaarNumber = "XXXXXXXX" + kyc.AadhaarNumber[8:]
	}
	if len(kyc.BankAccount) > 4 {
		kyc.BankAccount = strings.Repeat("*", len(kyc.BankAccount)-4) + kyc.BankAccount[len(kyc.BankAccount)-4:]
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"submitted": true,
		"kyc":       kyc,
	})
}

// AdminListKYC lists all submitted creator KYC records
func AdminListKYC(w http.ResponseWriter, r *http.Request) {
	statusFilter := r.URL.Query().Get("status")
	query := `
		SELECT k.user_id, u.name, u.email, u.mobile, u.tier, COALESCE(u.channel_name, ''),
		       k.aadhaar_number, k.pan_number, k.bank_account, k.ifsc_code, k.bank_name, k.account_holder, 
		       k.is_verified, k.verified_at, COALESCE(k.rejection_reason, ''), COALESCE(k.reviewed_by, ''), k.updated_at
		FROM user_kyc k
		JOIN users u ON k.user_id = u.id
	`
	if statusFilter == "pending" {
		query += " WHERE k.is_verified = 0 AND (k.rejection_reason = '' OR k.rejection_reason IS NULL)"
	} else if statusFilter == "verified" {
		query += " WHERE k.is_verified = 1"
	} else if statusFilter == "rejected" {
		query += " WHERE k.is_verified = 0 AND k.rejection_reason != '' AND k.rejection_reason IS NOT NULL"
	}
	query += " ORDER BY k.is_verified ASC, k.updated_at DESC"

	rows, err := database.DB.QueryContext(r.Context(), query)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	type AdminKYCItem struct {
		UserID          string     `json:"user_id"`
		Name            string     `json:"name"`
		Email           string     `json:"email"`
		Mobile          string     `json:"mobile"`
		Tier            string     `json:"tier"`
		ChannelName     string     `json:"channel_name"`
		AadhaarNumber   string     `json:"aadhaar_number"`
		PANNumber       string     `json:"pan_number"`
		BankAccount     string     `json:"bank_account"`
		IFSCCode        string     `json:"ifsc_code"`
		BankName        string     `json:"bank_name"`
		AccountHolder   string     `json:"account_holder"`
		IsVerified      bool       `json:"is_verified"`
		VerifiedAt      *time.Time `json:"verified_at,omitempty"`
		RejectionReason string     `json:"rejection_reason,omitempty"`
		ReviewedBy      string     `json:"reviewed_by,omitempty"`
		UpdatedAt       *time.Time `json:"updated_at,omitempty"`
	}

	var list []AdminKYCItem
	for rows.Next() {
		var item AdminKYCItem
		var rejReason, revBy string
		if err := rows.Scan(
			&item.UserID, &item.Name, &item.Email, &item.Mobile, &item.Tier, &item.ChannelName,
			&item.AadhaarNumber, &item.PANNumber, &item.BankAccount, &item.IFSCCode,
			&item.BankName, &item.AccountHolder, &item.IsVerified, &item.VerifiedAt,
			&rejReason, &revBy, &item.UpdatedAt,
		); err == nil {
			item.RejectionReason = rejReason
			item.ReviewedBy = revBy
			list = append(list, item)
		}
	}
	if list == nil {
		list = []AdminKYCItem{}
	}

	jsonResponse(w, http.StatusOK, list)
}

// AdminVerifyKYC approves or rejects creator KYC
func AdminVerifyKYC(w http.ResponseWriter, r *http.Request) {
	targetUserID := chi.URLParam(r, "id")
	var req struct {
		Approve         bool   `json:"approve"`
		RejectionReason string `json:"rejection_reason"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)

	adminClaims := middleware.GetUserFromContext(r)
	actor := "admin"
	if adminClaims != nil && adminClaims.UserID != "" {
		actor = adminClaims.UserID
	}

	now := time.Now()
	var err error
	if req.Approve {
		_, err = database.DB.ExecContext(r.Context(), `
			UPDATE user_kyc 
			SET is_verified = 1, verified_at = ?, rejection_reason = '', reviewed_by = ?, updated_at = ? 
			WHERE user_id = ?
		`, now, actor, now, targetUserID)
	} else {
		reason := strings.TrimSpace(req.RejectionReason)
		if reason == "" {
			reason = "Document verification incomplete or mismatched"
		}
		_, err = database.DB.ExecContext(r.Context(), `
			UPDATE user_kyc 
			SET is_verified = 0, verified_at = NULL, rejection_reason = ?, reviewed_by = ?, updated_at = ? 
			WHERE user_id = ?
		`, reason, actor, now, targetUserID)
	}

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var milestoneAwarded bool
	var milestoneAmount float64
	var milestoneMsg string
	if req.Approve {
		milestoneAwarded, milestoneAmount, milestoneMsg, _ = EvaluateAndAwardSilverReward(r.Context(), targetUserID)
	}

	// Dispatch FCM Push Notification to Creator
	if PushSvc != nil {
		if req.Approve {
			PushSvc.NotifyUser(targetUserID, push.Payload{
				Title: "KYC Verified! 🎉",
				Body:  "Your bank account has been verified. Direct bank payouts and milestone rewards are now unlocked!",
				Data: map[string]string{
					"action": "kyc_approved",
					"type":   "kyc",
					"status": "approved",
				},
			})
		} else {
			reason := strings.TrimSpace(req.RejectionReason)
			if reason == "" {
				reason = "Please review your document details and resubmit."
			}
			PushSvc.NotifyUser(targetUserID, push.Payload{
				Title: "KYC Verification Update ⚠️",
				Body:  fmt.Sprintf("Action required: %s", reason),
				Data: map[string]string{
					"action": "kyc_rejected",
					"type":   "kyc",
					"status": "rejected",
					"reason": reason,
				},
			})
		}
	}

	logger.LogAction(actor, "admin_verify_kyc", targetUserID, fmt.Sprintf("Approved: %v, Reason: %s, MilestoneAwarded: %v (₹%.2f)", req.Approve, req.RejectionReason, milestoneAwarded, milestoneAmount))

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"status":            "success",
		"user_id":           targetUserID,
		"is_verified":       req.Approve,
		"rejection_reason":  req.RejectionReason,
		"milestone_awarded": milestoneAwarded,
		"milestone_amount":  milestoneAmount,
		"milestone_message": milestoneMsg,
	})
}

// AdminListPayouts lists all withdrawal requests for admin settlement review
func AdminListPayouts(w http.ResponseWriter, r *http.Request) {
	statusFilter := r.URL.Query().Get("status")
	query := `
		SELECT p.id, p.user_id, u.name, u.email, u.mobile, COALESCE(u.channel_name, ''),
		       p.amount, p.status, COALESCE(p.cf_transfer_id, ''), COALESCE(p.cf_reference_id, ''),
		       COALESCE(p.beneficiary_name, ''), COALESCE(p.bank_account, ''), COALESCE(p.ifsc, ''),
		       COALESCE(p.utr_number, ''), COALESCE(p.failure_reason, ''), COALESCE(p.processed_by, ''),
		       p.created_at, p.updated_at
		FROM payout_requests p
		JOIN users u ON p.user_id = u.id
	`
	var args []interface{}
	if statusFilter != "" && statusFilter != "all" {
		query += " WHERE p.status = ?"
		args = append(args, statusFilter)
	}
	query += " ORDER BY p.created_at DESC"

	rows, err := database.DB.QueryContext(r.Context(), query, args...)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	type AdminPayoutItem struct {
		ID              string    `json:"id"`
		UserID          string    `json:"user_id"`
		UserName        string    `json:"user_name"`
		UserEmail       string    `json:"user_email"`
		UserMobile      string    `json:"user_mobile"`
		ChannelName     string    `json:"channel_name"`
		Amount          float64   `json:"amount"`
		Status          string    `json:"status"`
		CFTransferID    string    `json:"cf_transfer_id,omitempty"`
		CFReferenceID   string    `json:"cf_reference_id,omitempty"`
		BeneficiaryName string    `json:"beneficiary_name"`
		BankAccount     string    `json:"bank_account"`
		IFSC            string    `json:"ifsc"`
		UTRNumber       string    `json:"utr_number,omitempty"`
		FailureReason   string    `json:"failure_reason,omitempty"`
		ProcessedBy     string    `json:"processed_by,omitempty"`
		CreatedAt       time.Time `json:"created_at"`
		UpdatedAt       time.Time `json:"updated_at"`
	}

	var list []AdminPayoutItem
	for rows.Next() {
		var item AdminPayoutItem
		if err := rows.Scan(
			&item.ID, &item.UserID, &item.UserName, &item.UserEmail, &item.UserMobile, &item.ChannelName,
			&item.Amount, &item.Status, &item.CFTransferID, &item.CFReferenceID,
			&item.BeneficiaryName, &item.BankAccount, &item.IFSC,
			&item.UTRNumber, &item.FailureReason, &item.ProcessedBy,
			&item.CreatedAt, &item.UpdatedAt,
		); err == nil {
			list = append(list, item)
		}
	}
	if list == nil {
		list = []AdminPayoutItem{}
	}

	jsonResponse(w, http.StatusOK, list)
}

// AdminSettlePayout marks payout processed with UTR or rejects and refunds to wallet
func AdminSettlePayout(w http.ResponseWriter, r *http.Request) {
	payoutID := chi.URLParam(r, "id")
	var req struct {
		Action    string `json:"action"` // "mark_processed" or "reject"
		UTRNumber string `json:"utr_number"`
		Reason    string `json:"reason"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)

	adminClaims := middleware.GetUserFromContext(r)
	actor := "admin"
	if adminClaims != nil && adminClaims.UserID != "" {
		actor = adminClaims.UserID
	}

	// Fetch existing payout
	var p models.PayoutRequest
	err := database.DB.QueryRowContext(r.Context(), `
		SELECT id, user_id, amount, status, beneficiary_name, bank_account, ifsc
		FROM payout_requests
		WHERE id = ?
	`, payoutID).Scan(&p.ID, &p.UserID, &p.Amount, &p.Status, &p.BeneficiaryName, &p.BankAccount, &p.IFSC)
	if err != nil {
		http.Error(w, `{"error":"payout request not found"}`, http.StatusNotFound)
		return
	}

	if p.Status != "pending" && p.Status != "processing" {
		http.Error(w, fmt.Sprintf(`{"error":"payout is already in '%s' status"}`, p.Status), http.StatusBadRequest)
		return
	}

	now := time.Now()
	if req.Action == "mark_processed" {
		utr := strings.TrimSpace(req.UTRNumber)
		if utr == "" {
			utr = fmt.Sprintf("IMPS%d", now.UnixNano()/1e6)
		}
		_, err = database.DB.ExecContext(r.Context(), `
			UPDATE payout_requests
			SET status = 'processed', utr_number = ?, processed_by = ?, updated_at = ?
			WHERE id = ?
		`, utr, actor, now, payoutID)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		logger.LogAction(actor, "admin_settle_payout", payoutID, fmt.Sprintf("Settled ₹%.2f with UTR: %s", p.Amount, utr))

		if PushSvc != nil {
			PushSvc.NotifyUser(p.UserID, push.Payload{
				Title: "Bank Payout Settled! 💰",
				Body:  fmt.Sprintf("₹%.2f has been transferred to your bank account (%s). Ref/UTR: %s", p.Amount, p.BankAccount, utr),
				Data: map[string]string{
					"action":    "payout_settled",
					"type":      "payout",
					"payout_id": payoutID,
					"amount":    fmt.Sprintf("%.2f", p.Amount),
					"utr":       utr,
				},
			})
		}

		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"status":     "success",
			"payout_id":  payoutID,
			"utr_number": utr,
			"message":    fmt.Sprintf("Payout of ₹%.2f marked as processed", p.Amount),
		})
		return
	} else if req.Action == "reject" {
		reason := strings.TrimSpace(req.Reason)
		if reason == "" {
			reason = "Bank account validation failed or returned by bank"
		}

		tx, txErr := database.DB.BeginTx(r.Context(), nil)
		if txErr != nil {
			http.Error(w, `{"error":"transaction error"}`, http.StatusInternalServerError)
			return
		}
		defer tx.Rollback()

		_, err = tx.ExecContext(r.Context(), `
			UPDATE payout_requests
			SET status = 'failed', failure_reason = ?, processed_by = ?, updated_at = ?
			WHERE id = ?
		`, reason, actor, now, payoutID)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		// Refund wallet amount
		var currentBalance float64
		_ = tx.QueryRowContext(r.Context(), "SELECT wallet_amount FROM users WHERE id = ?", p.UserID).Scan(&currentBalance)
		newBalance := currentBalance + p.Amount

		_, err = tx.ExecContext(r.Context(), "UPDATE users SET wallet_amount = ? WHERE id = ?", newBalance, p.UserID)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		// Insert refund ledger transaction
		_, err = tx.ExecContext(r.Context(), `
			INSERT INTO wallet_transactions (id, user_id, amount, type, description, balance_after, created_at)
			VALUES (?, ?, ?, 'credit_refund', ?, ?, ?)
		`, randomID("tx"), p.UserID, p.Amount, fmt.Sprintf("Refund for rejected payout #%s: %s", payoutID, reason), newBalance, now)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		if commitErr := tx.Commit(); commitErr != nil {
			http.Error(w, `{"error":"failed to commit refund"}`, http.StatusInternalServerError)
			return
		}

		logger.LogAction(actor, "admin_reject_payout", payoutID, fmt.Sprintf("Rejected payout ₹%.2f, refunded to user %s. Reason: %s", p.Amount, p.UserID, reason))

		if PushSvc != nil {
			PushSvc.NotifyUser(p.UserID, push.Payload{
				Title: "Payout Returned & Refunded 🔄",
				Body:  fmt.Sprintf("Your payout of ₹%.2f could not be processed and was refunded to your wallet. Reason: %s", p.Amount, reason),
				Data: map[string]string{
					"action":    "payout_refunded",
					"type":      "payout",
					"payout_id": payoutID,
					"amount":    fmt.Sprintf("%.2f", p.Amount),
					"reason":    reason,
				},
			})
		}

		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"status":      "success",
			"payout_id":   payoutID,
			"new_balance": newBalance,
			"message":     fmt.Sprintf("Payout rejected and ₹%.2f refunded to creator wallet", p.Amount),
		})
		return
	} else {
		http.Error(w, `{"error":"invalid action, must be 'mark_processed' or 'reject'"}`, http.StatusBadRequest)
		return
	}
}

// RequestWithdrawal executes bank transfer payout via Cashfree
func RequestWithdrawal(w http.ResponseWriter, r *http.Request) {
	claims := middleware.GetUserFromContext(r)
	if claims == nil || claims.UserID == "" {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	var req struct {
		Amount float64 `json:"amount"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid json"}`, http.StatusBadRequest)
		return
	}

	if req.Amount < 500.0 {
		http.Error(w, `{"error":"minimum withdrawal amount is ₹500.00"}`, http.StatusBadRequest)
		return
	}

	// 1. Verify User & KYC
	var u models.User
	err := database.DB.QueryRowContext(r.Context(), "SELECT id, name, is_active, wallet_amount FROM users WHERE id = ?", claims.UserID).Scan(&u.ID, &u.Name, &u.IsActive, &u.WalletAmount)
	if err != nil || !u.IsActive {
		http.Error(w, `{"error":"account is not active"}`, http.StatusForbidden)
		return
	}

	if u.WalletAmount < req.Amount {
		http.Error(w, fmt.Sprintf(`{"error":"insufficient wallet balance (available: ₹%.2f)"}`, u.WalletAmount), http.StatusBadRequest)
		return
	}

	var kyc models.UserKYC
	err = database.DB.QueryRowContext(r.Context(), `
		SELECT bank_account, ifsc_code, bank_name, account_holder, is_verified 
		FROM user_kyc 
		WHERE user_id = ?
	`, claims.UserID).Scan(&kyc.BankAccount, &kyc.IFSCCode, &kyc.BankName, &kyc.AccountHolder, &kyc.IsVerified)

	if err != nil || !kyc.IsVerified {
		http.Error(w, `{"error":"your KYC must be verified by admin before requesting bank payouts"}`, http.StatusForbidden)
		return
	}

	// 2. Atomic Wallet Deduction
	tx, err := database.DB.BeginTx(r.Context(), nil)
	if err != nil {
		http.Error(w, `{"error":"transaction error"}`, http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	newBalance := u.WalletAmount - req.Amount
	_, err = tx.ExecContext(r.Context(), "UPDATE users SET wallet_amount = ? WHERE id = ?", newBalance, claims.UserID)
	if err != nil {
		http.Error(w, `{"error":"failed to update balance"}`, http.StatusInternalServerError)
		return
	}

	// 3. Dispatch Cashfree Payout
	payoutID := randomID("pay")
	transferID, refID, cfErr := payoutSvc.RequestBankPayout(payoutID, claims.UserID, kyc.AccountHolder, kyc.BankAccount, kyc.IFSCCode, req.Amount)
	payoutStatus := "processed"
	if cfErr != nil {
		http.Error(w, fmt.Sprintf(`{"error":"payout provider error: %v"}`, cfErr), http.StatusBadGateway)
		return
	}

	now := time.Now()
	// Record Ledger Transaction
	_, _ = tx.ExecContext(r.Context(), `
		INSERT INTO wallet_transactions (id, user_id, amount, type, description, balance_after, created_at)
		VALUES (?, ?, ?, 'debit_withdrawal', ?, ?, ?)
	`, randomID("tx"), claims.UserID, req.Amount, fmt.Sprintf("Bank payout to %s (%s)", kyc.BankName, kyc.BankAccount), newBalance, now)

	// Record Payout Request
	_, _ = tx.ExecContext(r.Context(), `
		INSERT INTO payout_requests (id, user_id, amount, status, cf_transfer_id, cf_reference_id, beneficiary_name, bank_account, ifsc, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`, payoutID, claims.UserID, req.Amount, payoutStatus, transferID, refID, kyc.AccountHolder, kyc.BankAccount, kyc.IFSCCode, now, now)

	if commitErr := tx.Commit(); commitErr != nil {
		http.Error(w, `{"error":"failed to commit payout"}`, http.StatusInternalServerError)
		return
	}

	logger.LogAction(claims.UserID, "payout_processed", payoutID, fmt.Sprintf("₹%.2f sent to %s via Cashfree (Ref: %s)", req.Amount, kyc.BankAccount, refID))

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"status":         "success",
		"message":        fmt.Sprintf("Payout of ₹%.2f successfully initiated to your bank account.", req.Amount),
		"transfer_id":    transferID,
		"reference_id":   refID,
		"new_balance":    newBalance,
		"account_holder": kyc.AccountHolder,
	})
}
