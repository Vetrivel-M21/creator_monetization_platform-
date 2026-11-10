import React, { useState } from 'react';
import { X, ShieldCheck, CheckCircle2, AlertCircle } from 'lucide-react';
import { walletService } from '../../services/walletService';

interface KYCModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  onOpenTerms?: () => void;
}

export const KYCModal: React.FC<KYCModalProps> = ({ isOpen, onClose, onSuccess, onOpenTerms }) => {
  const [panNumber, setPanNumber] = useState('');
  const [aadhaarNumber, setAadhaarNumber] = useState('');
  const [bankAccount, setBankAccount] = useState('');
  const [ifscCode, setIfscCode] = useState('');
  const [agreed, setAgreed] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!panNumber || !aadhaarNumber || !bankAccount || !ifscCode) {
      setError('Please fill in all banking and identity fields');
      return;
    }
    if (!agreed) {
      setError('You must accept the Human Creator Monetization Policy');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      await walletService.submitKYC({
        panNumber: panNumber.toUpperCase(),
        aadhaarNumber,
        bankAccount,
        ifscCode: ifscCode.toUpperCase(),
      });
      setSuccess(true);
      setTimeout(() => {
        onSuccess();
        onClose();
      }, 1200);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'KYC submission failed';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-md animate-fade-in">
      <div className="relative w-full max-w-lg bg-[#FFFFFF] border border-[#DCE7F6] rounded-3xl shadow-[0_25px_60px_rgba(220,231,246,0.95)] overflow-hidden flex flex-col">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-5 border-b border-[#DCE7F6] bg-[#FFFFFF]">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-[#E0EDFF] border border-[#BFDBFE] flex items-center justify-center text-[#1D4ED8]">
              <ShieldCheck size={18} />
            </div>
            <div>
              <h2 className="text-sm sm:text-base font-bold text-[#0F172A] tracking-tight">
                Direct Bank KYC Verification
              </h2>
              <p className="text-[11px] text-[#64748B] font-normal">
                Link bank account for direct creator royalties settlement
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-[#F8FAFC] hover:bg-[#F0F6FF] border border-[#DCE7F6] flex items-center justify-center text-[#64748B] hover:text-[#0F172A] transition-colors cursor-pointer"
          >
            <X size={16} />
          </button>
        </div>

        {/* Form Body */}
        <div className="p-6 space-y-4">
          {error && (
            <div className="flex items-center gap-2.5 p-3.5 bg-red-50 border border-red-200 rounded-2xl text-red-700 text-xs">
              <AlertCircle size={15} className="shrink-0" />
              <span>{error}</span>
            </div>
          )}

          {success && (
            <div className="flex items-center gap-2.5 p-3.5 bg-emerald-50 border border-emerald-200 rounded-2xl text-emerald-700 text-xs font-mono">
              <CheckCircle2 size={15} className="shrink-0" />
              <span>KYC successfully verified! Direct bank payouts enabled.</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-[#0F172A]">
                Permanent Account Number (PAN) *
              </label>
              <input
                type="text"
                required
                maxLength={10}
                placeholder="ABCDE1234F"
                value={panNumber}
                onChange={(e) => setPanNumber(e.target.value.toUpperCase())}
                className="w-full bg-[#F8FAFC] border border-[#DCE7F6] focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] rounded-xl px-4 py-2.5 text-xs text-[#0F172A] placeholder:text-[#94A3B8] focus:outline-none font-mono uppercase tracking-wider"
              />
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-[#0F172A]">
                Aadhaar Identification Number *
              </label>
              <input
                type="text"
                required
                maxLength={12}
                placeholder="XXXX XXXX XXXX"
                value={aadhaarNumber}
                onChange={(e) => setAadhaarNumber(e.target.value.replace(/\D/g, ''))}
                className="w-full bg-[#F8FAFC] border border-[#DCE7F6] focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] rounded-xl px-4 py-2.5 text-xs text-[#0F172A] placeholder:text-[#94A3B8] focus:outline-none font-mono tracking-wider"
              />
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-[#0F172A]">Bank Account Number *</label>
                <input
                  type="text"
                  required
                  placeholder="9876543210123"
                  value={bankAccount}
                  onChange={(e) => setBankAccount(e.target.value)}
                  className="w-full bg-[#F8FAFC] border border-[#DCE7F6] focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] rounded-xl px-4 py-2.5 text-xs text-[#0F172A] placeholder:text-[#94A3B8] focus:outline-none font-mono"
                />
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-[#0F172A]">Bank IFSC Code *</label>
                <input
                  type="text"
                  required
                  placeholder="HDFC0001234"
                  value={ifscCode}
                  onChange={(e) => setIfscCode(e.target.value.toUpperCase())}
                  className="w-full bg-[#F8FAFC] border border-[#DCE7F6] focus:border-[#2563EB] focus:ring-1 focus:ring-[#2563EB] rounded-xl px-4 py-2.5 text-xs text-[#0F172A] placeholder:text-[#94A3B8] focus:outline-none font-mono uppercase tracking-wider"
                />
              </div>
            </div>

            <div className="p-4 bg-[#F8FAFC] border border-[#DCE7F6] rounded-2xl">
              <label className="flex items-start gap-3 text-xs text-[#64748B] cursor-pointer">
                <input
                  type="checkbox"
                  checked={agreed}
                  onChange={(e) => setAgreed(e.target.checked)}
                  className="mt-0.5 rounded border-[#CBD5E1] accent-[#2563EB] text-[#2563EB] focus:ring-0"
                />
                <span className="leading-relaxed">
                  I certify that all uploaded content is 100% human-authored and compliant with ARMSS Entertainment{' '}
                  <button
                    type="button"
                    onClick={(e) => {
                      e.preventDefault();
                      onOpenTerms?.();
                    }}
                    className="text-[#2563EB] underline font-semibold hover:text-[#1D4ED8]"
                  >
                    Anti-AI Policies and Creator Payout Terms
                  </button>.
                </span>
              </label>
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
                disabled={loading}
                className="btn-pill-primary px-5 py-2.5 text-xs font-semibold tracking-tight disabled:opacity-50 cursor-pointer"
              >
                {loading ? 'Verifying...' : 'Confirm Bank Details'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};
