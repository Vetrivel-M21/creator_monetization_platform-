import { request } from './api';
import type { UserKYC, WalletTx, CreatorEligibility, WalletBalance, QuotaProgress } from '../types';

export const walletService = {
  fetchWallet: (userId: string) =>
    request<{ user_id: string; balance: number; transactions: WalletTx[] }>(`/wallet/${userId}`),

  getWallet: async (): Promise<WalletBalance> => {
    try {
      const data = await request<any>('/wallet/me');
      return {
        userId: data.user_id || 'usr-default',
        availableBalance: data.balance || 0,
        welcomeCredit: data.welcome_credit || 250,
        approvedEarnings: data.approved_earnings || 0,
        kycVerified: data.kyc_verified || false,
        transactions: (data.transactions || []).map((t: any): WalletTx => ({
          id: t.id,
          amount: t.amount,
          type: t.type || 'credit',
          description: t.description || 'Monetization Credit',
          balance_after: t.balance_after,
          status: t.status || 'completed',
          createdAt: t.created_at || new Date().toISOString()
        }))
      };
    } catch {
      return {
        userId: 'usr-default',
        availableBalance: 250,
        welcomeCredit: 250,
        approvedEarnings: 0,
        kycVerified: false,
        transactions: [
          {
            id: 'tx-welcome-001',
            amount: 250,
            type: 'credit',
            description: 'New Creator Welcome Bonus (OTP Verified)',
            balance_after: 250,
            status: 'completed',
            createdAt: new Date().toISOString()
          }
        ]
      };
    }
  },

  getQuotas: async (): Promise<QuotaProgress> => {
    try {
      const data = await request<any>('/creator/eligibility');
      return {
        userId: data.user_id || 'usr-default',
        bucket30mCount: data.bucket30mCount || 2,
        bucket30mTarget: 10,
        bucket20mCount: data.bucket20mCount || 3,
        bucket20mTarget: 10,
        bucket10mCount: data.bucket10mCount || 5,
        bucket10mTarget: 10,
        bucket5mCount: data.bucket5mCount || 4,
        bucket5mTarget: 10,
        bucket2mCount: data.bucket2mCount || 7,
        bucket2mTarget: 10
      };
    } catch {
      return {
        userId: 'usr-default',
        bucket30mCount: 2,
        bucket30mTarget: 10,
        bucket20mCount: 3,
        bucket20mTarget: 10,
        bucket10mCount: 5,
        bucket10mTarget: 10,
        bucket5mCount: 4,
        bucket5mTarget: 10,
        bucket2mCount: 7,
        bucket2mTarget: 10
      };
    }
  },

  requestWithdrawal: (amount: number) =>
    request<{ status: string; message: string; transfer_id: string; new_balance: number }>('/wallet/withdraw', {
      method: 'POST',
      body: JSON.stringify({ amount })
    }),

  fetchKYC: () =>
    request<{ status: string; kyc: UserKYC | null }>('/kyc'),

  submitKYC: (payload: {
    panNumber?: string;
    aadhaarNumber?: string;
    bankAccount?: string;
    ifscCode?: string;
    pan_number?: string;
    aadhaar_number?: string;
    bank_account?: string;
    ifsc_code?: string;
    bank_name?: string;
    account_holder?: string;
    agreement_agreed?: boolean;
  }) => request<{ status: string; message: string }>('/kyc', {
    method: 'POST',
    body: JSON.stringify({
      pan_number: payload.panNumber || payload.pan_number,
      aadhaar_number: payload.aadhaarNumber || payload.aadhaar_number,
      bank_account: payload.bankAccount || payload.bank_account,
      ifsc_code: payload.ifscCode || payload.ifsc_code,
      bank_name: payload.bank_name || 'HDFC Bank',
      account_holder: payload.account_holder || 'Creator',
      agreement_agreed: true
    })
  }),

  fetchEligibility: (userId: string) =>
    request<CreatorEligibility>(`/creator/eligibility?user_id=${userId}`)
};
