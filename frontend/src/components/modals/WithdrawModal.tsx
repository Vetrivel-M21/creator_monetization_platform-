import React, { useState, useEffect } from 'react';
import { X, ArrowDownRight, CheckCircle2, AlertCircle, Building2, ShieldCheck, AlertTriangle } from 'lucide-react';
import { walletService } from '../../services/walletService';

interface WithdrawModalProps {
  isOpen: boolean;
  onClose: () => void;
  availableBalance: number;
  onSuccess: () => void;
  onOpenKYC?: () => void;
}

export const WithdrawModal: React.FC<WithdrawModalProps> = ({
  isOpen,
  onClose,
  availableBalance,
  onSuccess,
  onOpenKYC,
}) => {
  const [amount, setAmount] = useState<number>(availableBalance >= 500 ? availableBalance : 500);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [kycData, setKycData] = useState<{
    isVerified: boolean;
    bankName: string;
    bankAccount: string;
    accountHolder: string;
  } | null>(null);
  const [isLoadingKYC, setIsLoadingKYC] = useState(false);

  useEffect(() => {
    if (isOpen) {
      loadKYCInfo();
      setAmount(availableBalance >= 500 ? availableBalance : 500);
    }
  }, [isOpen, availableBalance]);

  const loadKYCInfo = async () => {
    try {
      setIsLoadingKYC(true);
      const res = await walletService.fetchKYC();
      if (res && res.kyc) {
        setKycData({
          isVerified: !!res.kyc.is_verified,
          bankName: res.kyc.bank_name || 'Bank',
          bankAccount: res.kyc.bank_account || '',
          accountHolder: res.kyc.account_holder || 'Creator',
        });
      }
    } catch {
      // Ignore
    } finally {
      setIsLoadingKYC(false);
    }
  };

  if (!isOpen) return null;

  const handleWithdraw = async (e: React.FormEvent) => {
    e.preventDefault();
    if (amount < 500) {
      setError('Minimum withdrawal amount is ₹500.00');
      return;
    }
    if (amount > availableBalance) {
      setError(`Requested amount exceeds available balance of ₹${availableBalance.toLocaleString()}`);
      return;
    }

    try {
      setLoading(true);
      setError(null);
      await walletService.requestWithdrawal(amount);
      setSuccess(true);
      setTimeout(() => {
        onSuccess();
        onClose();
      }, 1600);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Withdrawal processing failed';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  const isKYCVerified = kycData?.isVerified ?? false;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-md animate-fade-in">
      <div className="relative w-full max-w-md bg-[#FFFFFF] border border-[#DCE7F6] rounded-3xl shadow-[0_25px_60px_rgba(220,231,246,0.95)] overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-5 border-b border-[#DCE7F6] bg-[#FFFFFF]">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-[#E0EDFF] border border-[#BFDBFE] flex items-center justify-center text-[#1D4ED8]">
              <ArrowDownRight size={18} />
            </div>
            <div>
              <h2 className="text-sm sm:text-base font-bold text-[#0F172A] tracking-tight">
                Request Bank Settlement
              </h2>
              <p className="text-[11px] text-[#64748B] font-normal">Direct IMPS / NEFT transfer to verified account</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-[#F8FAFC] hover:bg-[#F0F6FF] border border-[#DCE7F6] flex items-center justify-center text-[#64748B] hover:text-[#0F172A] transition-colors cursor-pointer"
          >
            <X size={16} />
          </button>
        </div>

        {/* Body */}
        <div className="p-6 space-y-4">
          {!isKYCVerified && !isLoadingKYC && (
            <div className="p-4 bg-amber-50 border border-amber-200 rounded-2xl text-xs space-y-2">
              <div className="flex items-center gap-2 font-bold text-amber-900">
                <AlertTriangle size={15} className="shrink-0" />
                <span>Verified KYC Required</span>
              </div>
              <p className="text-amber-800 leading-relaxed">
                Bank payouts are locked until your Aadhaar & PAN details are verified by administrators.
              </p>
              {onOpenKYC && (
                <button
                  type="button"
                  onClick={() => {
                    onClose();
                    onOpenKYC();
                  }}
                  className="px-3 py-1.5 rounded-lg bg-amber-600 hover:bg-amber-700 text-white font-semibold text-xs cursor-pointer inline-flex items-center gap-1.5"
                >
                  <ShieldCheck size={13} />
                  <span>Complete KYC Verification</span>
                </button>
              )}
            </div>
          )}

          {error && (
            <div className="flex items-center gap-2.5 p-3.5 bg-red-50 border border-red-200 rounded-2xl text-red-700 text-xs">
              <AlertCircle size={15} className="shrink-0" />
              <span>{error}</span>
            </div>
          )}

          {success && (
            <div className="flex items-center gap-2.5 p-3.5 bg-emerald-50 border border-emerald-200 rounded-2xl text-emerald-700 text-xs font-mono">
              <CheckCircle2 size={15} className="shrink-0" />
              <span>₹{amount.toFixed(2)} transfer initiated to verified bank account.</span>
            </div>
          )}

          {/* Balance Pill */}
          <div className="p-5 bg-[#F8FAFC] border border-[#DCE7F6] rounded-2xl flex items-center justify-between">
            <div>
              <div className="text-[10px] text-[#64748B] uppercase font-mono tracking-wider font-semibold">
                Available Withdrawable Balance
              </div>
              <div className="text-2xl font-bold font-mono text-[#0F172A] mt-1">
                ₹{availableBalance.toLocaleString('en-IN', { minimumFractionDigits: 2 })}
              </div>
            </div>
            {availableBalance >= 500 && (
              <button
                type="button"
                onClick={() => setAmount(availableBalance)}
                className="text-xs font-semibold px-3 py-1.5 rounded-full bg-[#E0EDFF] hover:bg-[#BFDBFE] border border-[#BFDBFE] text-[#1D4ED8] transition-all font-mono cursor-pointer"
              >
                Withdraw Full
              </button>
            )}
          </div>

          {/* Destination Bank Card */}
          {kycData && isKYCVerified && (
            <div className="p-3.5 rounded-2xl bg-emerald-50/50 border border-emerald-200 text-xs space-y-1">
              <div className="font-semibold text-emerald-950 flex items-center gap-1.5">
                <Building2 size={13} className="text-emerald-700" />
                <span>Destination Bank: {kycData.bankName}</span>
              </div>
              <div className="text-emerald-800 font-mono text-[11px]">
                Account: {kycData.bankAccount} ({kycData.accountHolder})
              </div>
            </div>
          )}

          <form onSubmit={handleWithdraw} className="space-y-4">
            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <label className="text-xs font-semibold text-[#0F172A]">Transfer Amount (INR) *</label>
                <span className="text-[10px] text-[#64748B] font-mono">Min: ₹500</span>
              </div>
              <div className="relative">
                <span className="absolute left-4 top-1/2 -translate-y-1/2 text-sm font-semibold text-[#64748B] font-mono">
                  ₹
                </span>
                <input
                  type="number"
                  min={500}
                  max={availableBalance}
                  value={amount}
                  onChange={(e) => setAmount(Number(e.target.value))}
                  style={{ paddingLeft: '2.5rem' }}
                  className="w-full bg-[#F8FAFC] border border-[#DCE7F6] focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] rounded-xl pr-4 py-2.5 text-sm font-mono font-semibold text-[#0F172A] focus:outline-none"
                />
              </div>

              {/* Quick Preset Amount Chips */}
              <div className="flex items-center gap-1.5 pt-1">
                {[500, 1000, 2500, 5000].map((preset) => (
                  <button
                    key={preset}
                    type="button"
                    disabled={availableBalance < preset}
                    onClick={() => setAmount(preset)}
                    className="text-[11px] font-mono px-2.5 py-1 rounded-lg border border-[#DCE7F6] bg-slate-50 hover:bg-slate-100 disabled:opacity-30 cursor-pointer"
                  >
                    ₹{preset}
                  </button>
                ))}
              </div>
            </div>

            <div className="pt-2 flex items-center justify-end gap-3">
              <button
                type="button"
                onClick={onClose}
                className="px-4 py-2 text-xs font-medium rounded-full border border-[#DCE7F6] bg-[#FFFFFF] text-[#64748B] hover:text-[#0F172A] hover:bg-[#F0F6FF] transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={loading || availableBalance < 500 || !isKYCVerified}
                className="btn-pill-primary px-6 py-2.5 text-xs font-semibold tracking-tight disabled:opacity-50 cursor-pointer"
              >
                {loading ? 'Processing...' : 'Transfer to Bank Account'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};
