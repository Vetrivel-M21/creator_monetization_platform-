import React, { useState, useEffect } from 'react';
import {
  ShieldCheck,
  CheckCircle2,
  XCircle,
  AlertTriangle,
  Clock,
  Search,
  RefreshCw,
  Building2,
  X,
  AlertCircle
} from 'lucide-react';
import { adminService } from '../services/adminService';
import type { AdminKYCItem } from '../types';

export const AdminKYCTab: React.FC = () => {
  const [kycList, setKycList] = useState<AdminKYCItem[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [filter, setFilter] = useState<'all' | 'pending' | 'verified' | 'rejected'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [processingUserId, setProcessingUserId] = useState<string | null>(null);
  const [rejectModalItem, setRejectModalItem] = useState<AdminKYCItem | null>(null);
  const [rejectionReason, setRejectionReason] = useState('');
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const loadKYC = async () => {
    try {
      setIsLoading(true);
      const data = await adminService.fetchKYCList(filter === 'all' ? undefined : filter);
      setKycList(data || []);
    } catch (err: any) {
      console.error('Failed to load KYC list:', err);
      setFeedback({ type: 'error', text: err.message || 'Failed to load KYC records' });
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadKYC();
  }, [filter]);

  const handleApprove = async (item: AdminKYCItem) => {
    if (!window.confirm(`Approve bank KYC for ${item.name} (${item.channel_name || 'Creator'})? This will unlock direct payouts and milestone bonuses.`)) {
      return;
    }
    try {
      setProcessingUserId(item.user_id);
      setFeedback(null);
      const res = await adminService.verifyKYC(item.user_id, true);
      let successMsg = `KYC approved for ${item.name}!`;
      if (res?.milestone_awarded) {
        successMsg += ` 🎉 Silver Milestone Award of ₹${res.milestone_amount} automatically credited!`;
      }
      setFeedback({ type: 'success', text: successMsg });
      await loadKYC();
    } catch (err: any) {
      setFeedback({ type: 'error', text: err.message || 'Failed to approve KYC' });
    } finally {
      setProcessingUserId(null);
    }
  };

  const handleRejectSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!rejectModalItem) return;
    const reason = rejectionReason.trim();
    if (!reason) {
      alert('Please provide a specific rejection reason for the creator.');
      return;
    }
    try {
      setProcessingUserId(rejectModalItem.user_id);
      setFeedback(null);
      await adminService.verifyKYC(rejectModalItem.user_id, false, reason);
      setFeedback({
        type: 'success',
        text: `KYC for ${rejectModalItem.name} rejected. Feedback notification dispatched to user.`,
      });
      setRejectModalItem(null);
      setRejectionReason('');
      await loadKYC();
    } catch (err: any) {
      setFeedback({ type: 'error', text: err.message || 'Failed to reject KYC' });
    } finally {
      setProcessingUserId(null);
    }
  };

  // Filtered list
  const filteredList = kycList.filter((item) => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    return (
      item.name.toLowerCase().includes(q) ||
      (item.channel_name && item.channel_name.toLowerCase().includes(q)) ||
      (item.email && item.email.toLowerCase().includes(q)) ||
      item.pan_number.toLowerCase().includes(q) ||
      item.bank_name.toLowerCase().includes(q) ||
      item.bank_account.includes(q)
    );
  });

  const totalCount = kycList.length;
  const pendingCount = kycList.filter((k) => !k.is_verified && !k.rejection_reason).length;
  const verifiedCount = kycList.filter((k) => k.is_verified).length;
  const rejectedCount = kycList.filter((k) => !k.is_verified && k.rejection_reason).length;

  return (
    <div className="space-y-6">
      {/* Top Metric Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="p-4 sm:p-5 rounded-2xl bg-white border border-[#DCE7F6] shadow-sm">
          <div className="text-[11px] font-mono uppercase font-bold text-[#64748B]">Total Submissions</div>
          <div className="text-2xl font-extrabold text-[#0F172A] mt-1 font-mono">{totalCount}</div>
        </div>
        <div className="p-4 sm:p-5 rounded-2xl bg-amber-50/60 border border-amber-200 shadow-sm">
          <div className="text-[11px] font-mono uppercase font-bold text-amber-800">Pending Review</div>
          <div className="text-2xl font-extrabold text-amber-900 mt-1 font-mono">{pendingCount}</div>
        </div>
        <div className="p-4 sm:p-5 rounded-2xl bg-emerald-50/60 border border-emerald-200 shadow-sm">
          <div className="text-[11px] font-mono uppercase font-bold text-emerald-800">Verified & Active</div>
          <div className="text-2xl font-extrabold text-emerald-900 mt-1 font-mono">{verifiedCount}</div>
        </div>
        <div className="p-4 sm:p-5 rounded-2xl bg-red-50/60 border border-red-200 shadow-sm">
          <div className="text-[11px] font-mono uppercase font-bold text-red-800">Action Required</div>
          <div className="text-2xl font-extrabold text-red-900 mt-1 font-mono">{rejectedCount}</div>
        </div>
      </div>

      {feedback && (
        <div
          className={`p-4 rounded-2xl border text-xs flex items-center gap-2.5 shadow-sm font-medium ${
            feedback.type === 'success'
              ? 'bg-emerald-50 border-emerald-200 text-emerald-800'
              : 'bg-red-50 border-red-200 text-red-800'
          }`}
        >
          {feedback.type === 'success' ? (
            <CheckCircle2 size={16} className="text-emerald-600 shrink-0" />
          ) : (
            <AlertCircle size={16} className="text-red-600 shrink-0" />
          )}
          <span>{feedback.text}</span>
        </div>
      )}

      {/* Control Bar: Filters & Search */}
      <div className="p-5 rounded-3xl bg-white border border-[#DCE7F6] shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-4">
        {/* Filter Pills */}
        <div className="flex flex-wrap items-center gap-2">
          {(
            [
              { id: 'all', label: `All (${totalCount})` },
              { id: 'pending', label: `Pending (${pendingCount})` },
              { id: 'verified', label: `Verified (${verifiedCount})` },
              { id: 'rejected', label: `Rejected (${rejectedCount})` },
            ] as const
          ).map((t) => (
            <button
              key={t.id}
              onClick={() => setFilter(t.id)}
              className={`px-3.5 py-1.5 rounded-full text-xs font-semibold transition-all cursor-pointer ${
                filter === t.id
                  ? 'bg-[#2563EB] text-white shadow-sm'
                  : 'bg-[#F8FAFC] text-[#64748B] hover:text-[#0F172A] border border-[#DCE7F6]'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>

        {/* Search & Refresh */}
        <div className="flex items-center gap-3">
          <div className="relative flex-1 sm:w-64">
            <Search size={14} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              placeholder="Search creator, PAN, bank..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-3.5 py-1.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs focus:outline-none focus:border-[#2563EB]"
            />
          </div>

          <button
            onClick={loadKYC}
            disabled={isLoading}
            className="p-2 rounded-xl bg-[#F8FAFC] hover:bg-[#F1F5F9] border border-[#DCE7F6] text-[#64748B] hover:text-[#0F172A] transition-colors cursor-pointer"
            title="Refresh KYC list"
          >
            <RefreshCw size={14} className={isLoading ? 'animate-spin text-[#2563EB]' : ''} />
          </button>
        </div>
      </div>

      {/* KYC Submissions Table */}
      <div className="rounded-3xl bg-white border border-[#DCE7F6] shadow-sm overflow-hidden">
        {filteredList.length === 0 ? (
          <div className="p-16 text-center space-y-2">
            <ShieldCheck size={36} className="mx-auto text-slate-300" />
            <h4 className="text-sm font-bold text-[#0F172A]">No KYC submissions match this filter</h4>
            <p className="text-xs text-[#64748B] max-w-sm mx-auto">
              {searchQuery ? 'Try clearing your search query.' : 'Creator bank KYC submissions will appear here for audit.'}
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-[#F8FAFC] text-[#64748B] border-b border-[#DCE7F6] font-mono text-[11px] uppercase tracking-wider">
                <tr>
                  <th className="py-3.5 px-6 font-semibold">Creator & Channel</th>
                  <th className="py-3.5 px-6 font-semibold">Identity Details</th>
                  <th className="py-3.5 px-6 font-semibold">Bank Settlement Rails</th>
                  <th className="py-3.5 px-6 font-semibold">Status & Audit</th>
                  <th className="py-3.5 px-6 font-semibold text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#DCE7F6]">
                {filteredList.map((item) => {
                  const isRejected = !item.is_verified && !!item.rejection_reason;
                  const isVerified = item.is_verified;
                  const isProcessing = processingUserId === item.user_id;

                  return (
                    <tr key={item.user_id} className="hover:bg-[#F8FAFC] transition-colors">
                      {/* Creator */}
                      <td className="py-4 px-6">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-xl bg-blue-100 text-[#2563EB] font-bold flex items-center justify-center shrink-0">
                            {item.name ? item.name[0].toUpperCase() : 'U'}
                          </div>
                          <div>
                            <div className="font-semibold text-[#0F172A] flex items-center gap-1.5">
                              <span>{item.name}</span>
                              <span className="text-[10px] uppercase font-mono px-1.5 py-0.2 rounded bg-slate-100 border border-slate-200 text-slate-600">
                                {item.tier || 'Silver'}
                              </span>
                            </div>
                            <div className="text-[11px] text-[#2563EB] font-medium">
                              {item.channel_name ? `@${item.channel_name}` : 'Personal Channel'}
                            </div>
                            <div className="text-[10px] text-[#64748B] font-mono mt-0.5">
                              {item.email} {item.mobile ? `• ${item.mobile}` : ''}
                            </div>
                          </div>
                        </div>
                      </td>

                      {/* Identity */}
                      <td className="py-4 px-6 font-mono space-y-1">
                        <div>
                          <span className="text-[10px] text-[#64748B] block">PAN CARD</span>
                          <span className="font-bold text-[#0F172A] bg-slate-100 px-2 py-0.5 rounded border border-slate-200 inline-block">
                            {item.pan_number}
                          </span>
                        </div>
                        <div>
                          <span className="text-[10px] text-[#64748B] block">AADHAAR</span>
                          <span className="text-[#0F172A]">{item.aadhaar_number}</span>
                        </div>
                      </td>

                      {/* Bank Details */}
                      <td className="py-4 px-6">
                        <div className="space-y-0.5">
                          <div className="font-semibold text-[#0F172A] flex items-center gap-1.5">
                            <Building2 size={13} className="text-[#2563EB]" />
                            <span>{item.bank_name}</span>
                          </div>
                          <div className="font-mono text-xs text-[#0F172A]">
                            Acct: {item.bank_account}
                          </div>
                          <div className="text-[11px] text-[#64748B]">
                            Holder: <strong className="text-[#0F172A]">{item.account_holder}</strong> • IFSC: <span className="font-mono">{item.ifsc_code}</span>
                          </div>
                        </div>
                      </td>

                      {/* Status */}
                      <td className="py-4 px-6">
                        {isVerified ? (
                          <div className="space-y-1">
                            <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold text-emerald-800 bg-emerald-50 px-2.5 py-1 rounded-full border border-emerald-200">
                              <CheckCircle2 size={12} className="text-emerald-600" />
                              <span>Verified Bank Account</span>
                            </span>
                            {item.verified_at && (
                              <div className="text-[10px] text-[#64748B] font-mono">
                                Approved: {new Date(item.verified_at).toLocaleDateString()}
                              </div>
                            )}
                          </div>
                        ) : isRejected ? (
                          <div className="space-y-1 max-w-xs">
                            <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold text-red-800 bg-red-50 px-2.5 py-1 rounded-full border border-red-200">
                              <XCircle size={12} className="text-red-600" />
                              <span>Rejected</span>
                            </span>
                            <p className="text-[11px] text-red-700 bg-red-50/50 p-2 rounded-lg border border-red-100">
                              {item.rejection_reason}
                            </p>
                          </div>
                        ) : (
                          <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold text-amber-800 bg-amber-50 px-2.5 py-1 rounded-full border border-amber-200 font-mono">
                            <Clock size={12} className="text-amber-600" />
                            <span>Pending Audit</span>
                          </span>
                        )}
                      </td>

                      {/* Actions */}
                      <td className="py-4 px-6 text-right">
                        <div className="flex items-center justify-end gap-2">
                          {!isVerified ? (
                            <>
                              <button
                                onClick={() => handleApprove(item)}
                                disabled={isProcessing}
                                className="px-3.5 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-semibold text-xs shadow-xs transition-colors inline-flex items-center gap-1.5 cursor-pointer disabled:opacity-50"
                              >
                                <CheckCircle2 size={13} />
                                <span>{isProcessing ? 'Saving...' : 'Approve'}</span>
                              </button>
                              <button
                                onClick={() => {
                                  setRejectModalItem(item);
                                  setRejectionReason(item.rejection_reason || '');
                                }}
                                disabled={isProcessing}
                                className="px-3 py-1.5 rounded-xl bg-red-50 hover:bg-red-100 text-red-700 border border-red-200 font-semibold text-xs transition-colors inline-flex items-center gap-1.5 cursor-pointer"
                              >
                                <XCircle size={13} />
                                <span>Reject</span>
                              </button>
                            </>
                          ) : (
                            <button
                              onClick={() => {
                                setRejectModalItem(item);
                                setRejectionReason('');
                              }}
                              className="px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-red-50 text-slate-600 hover:text-red-700 font-medium text-xs transition-colors cursor-pointer"
                            >
                              Revoke / Request Re-audit
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Reject Reason Modal */}
      {rejectModalItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs animate-fade-in">
          <div className="w-full max-w-md bg-white rounded-3xl border border-[#DCE7F6] shadow-2xl p-6 space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-red-100 text-red-600 flex items-center justify-center">
                  <AlertTriangle size={18} />
                </div>
                <div>
                  <h3 className="text-base font-bold text-[#0F172A]">Reject Creator KYC</h3>
                  <p className="text-xs text-[#64748B]">Provide rejection reason to send to creator</p>
                </div>
              </div>
              <button
                onClick={() => setRejectModalItem(null)}
                className="p-1 rounded-full text-slate-400 hover:text-slate-600"
              >
                <X size={18} />
              </button>
            </div>

            <div className="p-3 rounded-2xl bg-slate-50 border border-slate-200 text-xs text-slate-700 space-y-1">
              <div>
                <strong>Creator:</strong> {rejectModalItem.name} ({rejectModalItem.email})
              </div>
              <div>
                <strong>PAN:</strong> {rejectModalItem.pan_number} • <strong>Bank:</strong> {rejectModalItem.bank_name}
              </div>
            </div>

            <form onSubmit={handleRejectSubmit} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-[#0F172A] block mb-1">
                  Rejection Reason *
                </label>
                <textarea
                  rows={3}
                  required
                  placeholder="e.g. Name on bank account does not match PAN card. Please upload valid proof."
                  value={rejectionReason}
                  onChange={(e) => setRejectionReason(e.target.value)}
                  className="w-full p-3 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs focus:outline-none focus:border-red-500"
                />
              </div>

              {/* Quick Preset Buttons */}
              <div className="space-y-1.5">
                <span className="text-[10px] font-mono uppercase text-[#64748B] block">Quick Presets:</span>
                <div className="flex flex-wrap gap-1.5">
                  {[
                    'Name mismatch on PAN vs Bank Account',
                    'Invalid or unrecognized IFSC code',
                    'Account number digits mismatch',
                    'Aadhaar document blurred or invalid',
                  ].map((preset) => (
                    <button
                      key={preset}
                      type="button"
                      onClick={() => setRejectionReason(preset)}
                      className="text-[10px] px-2.5 py-1 rounded-full bg-slate-100 hover:bg-slate-200 text-slate-700 transition-colors"
                    >
                      {preset}
                    </button>
                  ))}
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setRejectModalItem(null)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={processingUserId !== null}
                  className="px-5 py-2 rounded-xl bg-red-600 hover:bg-red-700 text-white font-semibold text-xs shadow-sm transition-colors cursor-pointer"
                >
                  {processingUserId ? 'Submitting...' : 'Confirm Rejection'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
