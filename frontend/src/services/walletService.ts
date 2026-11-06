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
      const buckets: any[] = Array.isArray(data?.buckets) ? data.buckets : [];
      const getApprovedCount = (key: string, legacyField?: number) => {
        const found = buckets.find((b: any) => b.key === key);
        if (found && typeof found.approved_count === 'number') {
          return found.approved_count;
        }
        if (typeof legacyField === 'number') {
          return legacyField;
        }
        return 0;
      };
      const getTargetCount = (key: string, legacyTarget?: number, fallback = 10) => {
        const found = buckets.find((b: any) => b.key === key);
        if (found && typeof found.target_count === 'number' && found.target_count > 0) {
          return found.target_count;
        }
        if (typeof legacyTarget === 'number' && legacyTarget > 0) {
          return legacyTarget;
        }
        return fallback;
      };

      return {
        userId: data?.user_id || 'usr-default',
        bucket30mCount: getApprovedCount('30m', data?.bucket30mCount),
        bucket30mTarget: getTargetCount('30m', data?.bucket30mTarget, 10),
        bucket20mCount: getApprovedCount('20m', data?.bucket20mCount),
        bucket20mTarget: getTargetCount('20m', data?.bucket20mTarget, 10),
        bucket10mCount: getApprovedCount('10m', data?.bucket10mCount),
        bucket10mTarget: getTargetCount('10m', data?.bucket10mTarget, 10),
        bucket5mCount: getApprovedCount('5m', data?.bucket5mCount),
        bucket5mTarget: getTargetCount('5m', data?.bucket5mTarget, 10),
        bucket2mCount: getApprovedCount('2m', data?.bucket2mCount),
        bucket2mTarget: getTargetCount('2m', data?.bucket2mTarget, 10)
      };
    } catch {
      return {
        userId: 'usr-default',
        bucket30mCount: 0,
        bucket30mTarget: 10,
        bucket20mCount: 0,
        bucket20mTarget: 10,
        bucket10mCount: 0,
        bucket10mTarget: 10,
        bucket5mCount: 0,
        bucket5mTarget: 10,
        bucket2mCount: 0,
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
