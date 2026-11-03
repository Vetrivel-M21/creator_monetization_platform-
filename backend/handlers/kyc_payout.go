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

	query := `
		INSERT INTO user_kyc (user_id, aadhaar_number, pan_number, bank_account, ifsc_code, bank_name, account_holder, agreement_agreed, is_verified, verified_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0, NULL)
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
			verified_at = NULL`
	} else {
		query = `
			INSERT OR REPLACE INTO user_kyc (user_id, aadhaar_number, pan_number, bank_account, ifsc_code, bank_name, account_holder, agreement_agreed, is_verified, verified_at)
			VALUES (?, ?, ?, ?, ?, ?, ?, 1, 0, NULL)
		`
	}

	_, err := database.DB.ExecContext(r.Context(), query, claims.UserID, aadhaar, pan, account, ifsc, bankName, holder)
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
	err := database.DB.QueryRowContext(r.Context(), `
		SELECT user_id, aadhaar_number, pan_number, bank_account, ifsc_code, bank_name, account_holder, agreement_agreed, is_verified, verified_at
		FROM user_kyc
		WHERE user_id = ?
	`, claims.UserID).Scan(
		&kyc.UserID, &kyc.AadhaarNumber, &kyc.PANNumber, &kyc.BankAccount, &kyc.IFSCCode,
		&kyc.BankName, &kyc.AccountHolder, &kyc.AgreementAgreed, &kyc.IsVerified, &kyc.VerifiedAt,
	)

	if err != nil {
		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"submitted": false,
			"kyc":       nil,
		})
		return
	}

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
	rows, err := database.DB.QueryContext(r.Context(), `
		SELECT k.user_id, u.name, u.email, u.mobile, u.tier, k.aadhaar_number, k.pan_number, 
		       k.bank_account, k.ifsc_code, k.bank_name, k.account_holder, k.is_verified, k.verified_at
		FROM user_kyc k
		JOIN users u ON k.user_id = u.id
		ORDER BY k.is_verified ASC
	`)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	type AdminKYCItem struct {
		UserID        string     `json:"user_id"`
		Name          string     `json:"name"`
		Email         string     `json:"email"`
		Mobile        string     `json:"mobile"`
		Tier          string     `json:"tier"`
		AadhaarNumber string     `json:"aadhaar_number"`
		PANNumber     string     `json:"pan_number"`
		BankAccount   string     `json:"bank_account"`
		IFSCCode      string     `json:"ifsc_code"`
		BankName      string     `json:"bank_name"`
		AccountHolder string     `json:"account_holder"`
		IsVerified    bool       `json:"is_verified"`
		VerifiedAt    *time.Time `json:"verified_at,omitempty"`
	}

	var list []AdminKYCItem
	for rows.Next() {
		var item AdminKYCItem
		if err := rows.Scan(
			&item.UserID, &item.Name, &item.Email, &item.Mobile, &item.Tier,
			&item.AadhaarNumber, &item.PANNumber, &item.BankAccount, &item.IFSCCode,
			&item.BankName, &item.AccountHolder, &item.IsVerified, &item.VerifiedAt,
		); err == nil {
			list = append(list, item)
		}
	}
	if list == nil {
		list = []AdminKYCItem{}
	}

	jsonResponse(w, http.StatusOK, list)
}

// AdminVerifyKYC approves or revokes creator KYC
func AdminVerifyKYC(w http.ResponseWriter, r *http.Request) {
	targetUserID := chi.URLParam(r, "id")
	var req struct {
		Approve bool `json:"approve"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)

	now := time.Now()
	var err error
	if req.Approve {
		_, err = database.DB.ExecContext(r.Context(), "UPDATE user_kyc SET is_verified = 1, verified_at = ? WHERE user_id = ?", now, targetUserID)
	} else {
		_, err = database.DB.ExecContext(r.Context(), "UPDATE user_kyc SET is_verified = 0, verified_at = NULL WHERE user_id = ?", targetUserID)
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

	adminClaims := middleware.GetUserFromContext(r)
	actor := "admin"
	if adminClaims != nil {
		actor = adminClaims.UserID
	}
	logger.LogAction(actor, "admin_verify_kyc", targetUserID, fmt.Sprintf("Approved: %v, MilestoneAwarded: %v (₹%.2f)", req.Approve, milestoneAwarded, milestoneAmount))

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"status":            "success",
		"user_id":           targetUserID,
		"is_verified":       req.Approve,
		"milestone_awarded": milestoneAwarded,
		"milestone_amount":  milestoneAmount,
		"milestone_message": milestoneMsg,
	})
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
