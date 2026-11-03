package payout

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"
)

type PayoutService struct {
	ClientID     string
	ClientSecret string
	BaseURL      string
	IsSandbox    bool
}

type DirectTransferRequest struct {
	Amount             float64            `json:"amount"`
	TransferID         string             `json:"transferId"`
	TransferMode       string             `json:"transferMode"`
	BeneficiaryDetails BeneficiaryDetails `json:"beneficiaryDetails"`
	Remarks            string             `json:"remarks"`
}

type BeneficiaryDetails struct {
	BeneficiaryID      string `json:"beneficiaryId"`
	BeneficiaryName    string `json:"beneficiaryName"`
	BeneficiaryAccount string `json:"beneficiaryAccount"`
	BeneficiaryIFSC    string `json:"beneficiaryIFSC"`
}

type DirectTransferResponse struct {
	Status     string `json:"status"`
	SubCode    string `json:"subCode"`
	Message    string `json:"message"`
	Data       struct {
		TransferID string `json:"transferId"`
		ReferenceID string `json:"referenceId"`
		Utr        string `json:"utr"`
	} `json:"data"`
}

func NewPayoutService() *PayoutService {
	clientID := os.Getenv("CASHFREE_PAYOUT_CLIENT_ID")
	clientSecret := os.Getenv("CASHFREE_PAYOUT_CLIENT_SECRET")
	env := os.Getenv("CASHFREE_PAYOUT_ENV")

	baseURL := "https://payout-gamma.cashfree.com"
	isSandbox := true
	if env == "production" || env == "PROD" {
		baseURL = "https://payout-api.cashfree.com"
		isSandbox = false
	}

	return &PayoutService{
		ClientID:     clientID,
		ClientSecret: clientSecret,
		BaseURL:      baseURL,
		IsSandbox:    isSandbox,
	}
}

// RequestBankPayout initiates an instant bank transfer through Cashfree Payouts API
func (s *PayoutService) RequestBankPayout(transferID, userID, name, bankAccount, ifsc string, amount float64) (string, string, error) {
	// If credentials are not yet configured in .env, simulate successful test transfer
	if s.ClientID == "" || s.ClientSecret == "" || s.ClientID == "TEST_CF_CLIENT_ID" {
		referenceID := fmt.Sprintf("CF_SIM_%d", time.Now().UnixNano())
		return transferID, referenceID, nil
	}

	reqPayload := DirectTransferRequest{
		Amount:       amount,
		TransferID:   transferID,
		TransferMode: "banktransfer",
		BeneficiaryDetails: BeneficiaryDetails{
			BeneficiaryID:      userID,
			BeneficiaryName:    name,
			BeneficiaryAccount: bankAccount,
			BeneficiaryIFSC:    ifsc,
		},
		Remarks: "ARMSS Creator Monetization Payout",
	}

	bodyBytes, err := json.Marshal(reqPayload)
	if err != nil {
		return "", "", fmt.Errorf("marshalling payout request: %w", err)
	}

	url := fmt.Sprintf("%s/payout/v1/directTransfer", s.BaseURL)
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(bodyBytes))
	if err != nil {
		return "", "", fmt.Errorf("creating payout http request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Client-Id", s.ClientID)
	req.Header.Set("X-Client-Secret", s.ClientSecret)

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", "", fmt.Errorf("executing cashfree payout call: %w", err)
	}
	defer resp.Body.Close()

	var cfResp DirectTransferResponse
	if err := json.NewDecoder(resp.Body).Decode(&cfResp); err != nil {
		return "", "", fmt.Errorf("decoding cashfree response: %w", err)
	}

	if cfResp.Status != "SUCCESS" && cfResp.SubCode != "200" {
		return "", "", fmt.Errorf("cashfree payout rejected: %s (code: %s)", cfResp.Message, cfResp.SubCode)
	}

	return cfResp.Data.TransferID, cfResp.Data.ReferenceID, nil
}
