import React, { useState, useEffect } from 'react';
import {
  ArrowDownRight,
  CheckCircle2,
  XCircle,
  Clock,
  Search,
  RefreshCw,
  Building2,
  AlertCircle,
  AlertTriangle,
  X
} from 'lucide-react';
import { adminService } from '../services/adminService';
import type { AdminPayoutItem } from '../types';

export const AdminPayoutsTab: React.FC = () => {
  const [payouts, setPayouts] = useState<AdminPayoutItem[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [filter, setFilter] = useState<'all' | 'pending' | 'processed' | 'failed'>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [processingId, setProcessingId] = useState<string | null>(null);

  // Settle Modal State
  const [settleModalItem, setSettleModalItem] = useState<AdminPayoutItem | null>(null);
  const [utrNumber, setUtrNumber] = useState('');

  // Reject Modal State
  const [rejectModalItem, setRejectModalItem] = useState<AdminPayoutItem | null>(null);
  const [rejectReason, setRejectReason] = useState('');

  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const loadPayouts = async () => {
    try {
      setIsLoading(true);
      const data = await adminService.fetchPayouts(filter === 'all' ? undefined : filter);
      setPayouts(data || []);
    } catch (err: any) {
      console.error('Failed to load payouts:', err);
      setFeedback({ type: 'error', text: err.message || 'Failed to load payouts' });
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadPayouts();
  }, [filter]);

  const handleSettleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!settleModalItem) return;
    try {
      setProcessingId(settleModalItem.id);
      setFeedback(null);
      const res = await adminService.settlePayout(
        settleModalItem.id,
        'mark_processed',
        utrNumber.trim() || undefined
      );
      setFeedback({
        type: 'success',
        text: `Payout #${settleModalItem.id} of ₹${settleModalItem.amount.toLocaleString()} marked as settled! Reference: ${res.utr_number}`,
      });
      setSettleModalItem(null);
      setUtrNumber('');
      await loadPayouts();
    } catch (err: any) {
      setFeedback({ type: 'error', text: err.message || 'Failed to settle payout' });
    } finally {
      setProcessingId(null);
    }
  };

  const handleRejectSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!rejectModalItem) return;
    const reason = rejectReason.trim();
    if (!reason) {
      alert('Please specify a rejection reason.');
      return;
    }
    try {
      setProcessingId(rejectModalItem.id);
      setFeedback(null);
      await adminService.settlePayout(
        rejectModalItem.id,
        'reject',
        undefined,
        reason
      );
      setFeedback({
        type: 'success',
        text: `Payout #${rejectModalItem.id} rejected and ₹${rejectModalItem.amount.toLocaleString()} refunded to user's wallet.`,
      });
      setRejectModalItem(null);
      setRejectReason('');
      await loadPayouts();
    } catch (err: any) {
      setFeedback({ type: 'error', text: err.message || 'Failed to reject and refund payout' });
    } finally {
      setProcessingId(null);
    }
  };

  // Search filter
  const filteredList = payouts.filter((item) => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    return (
      item.id.toLowerCase().includes(q) ||
      (item.user_name && item.user_name.toLowerCase().includes(q)) ||
      (item.channel_name && item.channel_name.toLowerCase().includes(q)) ||
      (item.beneficiary_name && item.beneficiary_name.toLowerCase().includes(q)) ||
      (item.utr_number && item.utr_number.toLowerCase().includes(q)) ||
      item.bank_account.includes(q)
    );
  });

  // Aggregates
  const totalVolumeSettled = payouts
    .filter((p) => p.status === 'processed')
    .reduce((acc, p) => acc + p.amount, 0);

  const pendingPayouts = payouts.filter((p) => p.status === 'pending' || p.status === 'processing');
  const pendingVolume = pendingPayouts.reduce((acc, p) => acc + p.amount, 0);
  const processedCount = payouts.filter((p) => p.status === 'processed').length;
  const failedCount = payouts.filter((p) => p.status === 'failed').length;

  return (
    <div className="space-y-6">
      {/* Top Metric Cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="p-4 sm:p-5 rounded-2xl bg-white border border-[#DCE7F6] shadow-sm">
          <div className="text-[11px] font-mono uppercase font-bold text-[#64748B]">Total Settled Volume</div>
          <div className="text-2xl font-extrabold text-[#0F172A] mt-1 font-mono">
            ₹{totalVolumeSettled.toLocaleString('en-IN', { minimumFractionDigits: 2 })}
          </div>
        </div>
        <div className="p-4 sm:p-5 rounded-2xl bg-amber-50/60 border border-amber-200 shadow-sm">
          <div className="text-[11px] font-mono uppercase font-bold text-amber-800">Pending Settlement</div>
          <div className="text-2xl font-extrabold text-amber-900 mt-1 font-mono">
            ₹{pendingVolume.toLocaleString('en-IN', { minimumFractionDigits: 2 })}
            <span className="text-xs font-normal text-amber-700 ml-1.5 font-sans">({pendingPayouts.length} reqs)</span>
          </div>
        </div>
        <div className="p-4 sm:p-5 rounded-2xl bg-emerald-50/60 border border-emerald-200 shadow-sm">
          <div className="text-[11px] font-mono uppercase font-bold text-emerald-800">Processed Settlements</div>
          <div className="text-2xl font-extrabold text-emerald-900 mt-1 font-mono">{processedCount}</div>
        </div>
        <div className="p-4 sm:p-5 rounded-2xl bg-red-50/60 border border-red-200 shadow-sm">
          <div className="text-[11px] font-mono uppercase font-bold text-red-800">Rejected & Refunded</div>
          <div className="text-2xl font-extrabold text-red-900 mt-1 font-mono">{failedCount}</div>
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

      {/* Control Bar */}
      <div className="p-5 rounded-3xl bg-white border border-[#DCE7F6] shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-4">
        {/* Filter Pills */}
        <div className="flex flex-wrap items-center gap-2">
          {(
            [
              { id: 'all', label: `All (${payouts.length})` },
              { id: 'pending', label: `Pending (${pendingPayouts.length})` },
              { id: 'processed', label: `Processed (${processedCount})` },
              { id: 'failed', label: `Refunded (${failedCount})` },
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
              placeholder="Search creator, UTR, account..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-9 pr-3.5 py-1.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs focus:outline-none focus:border-[#2563EB]"
            />
          </div>

          <button
            onClick={loadPayouts}
            disabled={isLoading}
            className="p-2 rounded-xl bg-[#F8FAFC] hover:bg-[#F1F5F9] border border-[#DCE7F6] text-[#64748B] hover:text-[#0F172A] transition-colors cursor-pointer"
            title="Refresh payouts list"
          >
            <RefreshCw size={14} className={isLoading ? 'animate-spin text-[#2563EB]' : ''} />
          </button>
        </div>
      </div>

      {/* Payouts Table */}
      <div className="rounded-3xl bg-white border border-[#DCE7F6] shadow-sm overflow-hidden">
        {filteredList.length === 0 ? (
          <div className="p-16 text-center space-y-2">
            <ArrowDownRight size={36} className="mx-auto text-slate-300" />
            <h4 className="text-sm font-bold text-[#0F172A]">No withdrawal requests match this filter</h4>
            <p className="text-xs text-[#64748B] max-w-sm mx-auto">
              When creators request wallet settlements, payouts will appear here for processing and bank settlement.
            </p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-[#F8FAFC] text-[#64748B] border-b border-[#DCE7F6] font-mono text-[11px] uppercase tracking-wider">
                <tr>
                  <th className="py-3.5 px-6 font-semibold">Request & Creator</th>
                  <th className="py-3.5 px-6 font-semibold">Amount</th>
                  <th className="py-3.5 px-6 font-semibold">Bank Destination</th>
                  <th className="py-3.5 px-6 font-semibold">Status & Settlement UTR</th>
                  <th className="py-3.5 px-6 font-semibold text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#DCE7F6]">
                {filteredList.map((item) => {
                  const isPending = item.status === 'pending' || item.status === 'processing';
                  const isProcessed = item.status === 'processed';
                  const isFailed = item.status === 'failed';
                  const isProcessing = processingId === item.id;

                  return (
                    <tr key={item.id} className="hover:bg-[#F8FAFC] transition-colors">
                      {/* Creator */}
                      <td className="py-4 px-6">
                        <div className="space-y-0.5">
                          <div className="font-semibold text-[#0F172A] flex items-center gap-1.5">
                            <span>{item.user_name || item.beneficiary_name}</span>
                            {item.channel_name && (
                              <span className="text-[11px] text-[#2563EB] font-normal">
                                (@{item.channel_name})
                              </span>
                            )}
                          </div>
                          <div className="text-[11px] text-[#64748B] font-mono">
                            Ref #{item.id.substring(0, 10)} • {new Date(item.created_at).toLocaleString()}
                          </div>
                          <div className="text-[10px] text-[#64748B]">
                            {item.user_email} {item.user_mobile ? `• ${item.user_mobile}` : ''}
                          </div>
                        </div>
                      </td>

                      {/* Amount */}
                      <td className="py-4 px-6 font-mono">
                        <span className="text-sm font-extrabold text-[#0F172A]">
                          ₹{item.amount.toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                        </span>
                      </td>

                      {/* Bank Details */}
                      <td className="py-4 px-6">
                        <div className="space-y-0.5">
                          <div className="font-semibold text-[#0F172A] flex items-center gap-1.5">
                            <Building2 size={13} className="text-[#2563EB]" />
                            <span>{item.beneficiary_name}</span>
                          </div>
                          <div className="font-mono text-xs text-[#0F172A]">
                            Acct: {item.bank_account}
                          </div>
                          <div className="text-[11px] text-[#64748B] font-mono">
                            IFSC: {item.ifsc}
                          </div>
                        </div>
                      </td>

                      {/* Status */}
                      <td className="py-4 px-6">
                        {isProcessed ? (
                          <div className="space-y-1">
                            <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold text-emerald-800 bg-emerald-50 px-2.5 py-1 rounded-full border border-emerald-200">
                              <CheckCircle2 size={12} className="text-emerald-600" />
                              <span>Settled via Bank</span>
                            </span>
                            {item.utr_number && (
                              <div className="text-[11px] text-[#0F172A] font-mono font-medium">
                                UTR: {item.utr_number}
                              </div>
                            )}
                          </div>
                        ) : isFailed ? (
                          <div className="space-y-1 max-w-xs">
                            <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold text-red-800 bg-red-50 px-2.5 py-1 rounded-full border border-red-200">
                              <XCircle size={12} className="text-red-600" />
                              <span>Rejected & Refunded</span>
                            </span>
                            {item.failure_reason && (
                              <p className="text-[11px] text-red-700 bg-red-50/50 p-2 rounded-lg border border-red-100">
                                {item.failure_reason}
                              </p>
                            )}
                          </div>
                        ) : (
                          <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold text-amber-800 bg-amber-50 px-2.5 py-1 rounded-full border border-amber-200 font-mono">
                            <Clock size={12} className="text-amber-600" />
                            <span>Pending Settlement</span>
                          </span>
                        )}
                      </td>

                      {/* Actions */}
                      <td className="py-4 px-6 text-right">
                        {isPending ? (
                          <div className="flex items-center justify-end gap-2">
                            <button
                              onClick={() => {
                                setSettleModalItem(item);
                                setUtrNumber(`IMPS${Date.now()}`);
                              }}
                              disabled={isProcessing}
                              className="px-3.5 py-1.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-semibold text-xs shadow-xs transition-colors inline-flex items-center gap-1.5 cursor-pointer disabled:opacity-50"
                            >
                              <CheckCircle2 size={13} />
                              <span>Mark Settled</span>
                            </button>
                            <button
                              onClick={() => {
                                setRejectModalItem(item);
                                setRejectReason('');
                              }}
                              disabled={isProcessing}
                              className="px-3 py-1.5 rounded-xl bg-red-50 hover:bg-red-100 text-red-700 border border-red-200 font-semibold text-xs transition-colors inline-flex items-center gap-1.5 cursor-pointer"
                            >
                              <XCircle size={13} />
                              <span>Reject & Refund</span>
                            </button>
                          </div>
                        ) : (
                          <span className="text-[11px] text-[#64748B] font-mono">
                            {isProcessed ? 'Completed' : 'Refunded'}
                          </span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Settle / Mark Processed Modal */}
      {settleModalItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs animate-fade-in">
          <div className="w-full max-w-md bg-white rounded-3xl border border-[#DCE7F6] shadow-2xl p-6 space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-emerald-100 text-emerald-700 flex items-center justify-center">
                  <CheckCircle2 size={18} />
                </div>
                <div>
                  <h3 className="text-base font-bold text-[#0F172A]">Record Bank Settlement</h3>
                  <p className="text-xs text-[#64748B]">Complete payout transfer and notify creator</p>
                </div>
              </div>
              <button
                onClick={() => setSettleModalItem(null)}
                className="p-1 rounded-full text-slate-400 hover:text-slate-600"
              >
                <X size={18} />
              </button>
            </div>

            <div className="p-3.5 rounded-2xl bg-emerald-50 border border-emerald-200 text-xs text-emerald-900 space-y-1 font-mono">
              <div className="text-sm font-bold">
                Payout Amount: ₹{settleModalItem.amount.toLocaleString('en-IN', { minimumFractionDigits: 2 })}
              </div>
              <div>Beneficiary: {settleModalItem.beneficiary_name}</div>
              <div>Account: {settleModalItem.bank_account} • IFSC: {settleModalItem.ifsc}</div>
            </div>

            <form onSubmit={handleSettleSubmit} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-[#0F172A] block mb-1">
                  Bank UTR / Transaction Reference Number *
                </label>
                <input
                  type="text"
                  required
                  value={utrNumber}
                  onChange={(e) => setUtrNumber(e.target.value)}
                  className="w-full p-3 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs font-mono focus:outline-none focus:border-[#2563EB]"
                  placeholder="e.g. IMPS1234567890 or CMS987654321"
                />
                <p className="text-[10px] text-[#64748B] mt-1">
                  This reference will be visible to the creator in their transaction ledger and push notification.
                </p>
              </div>

              <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setSettleModalItem(null)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={processingId !== null}
                  className="px-5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-semibold text-xs shadow-sm transition-colors cursor-pointer"
                >
                  {processingId ? 'Recording...' : 'Confirm Bank Settlement'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Reject & Refund Modal */}
      {rejectModalItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs animate-fade-in">
          <div className="w-full max-w-md bg-white rounded-3xl border border-[#DCE7F6] shadow-2xl p-6 space-y-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-red-100 text-red-600 flex items-center justify-center">
                  <AlertTriangle size={18} />
                </div>
                <div>
                  <h3 className="text-base font-bold text-[#0F172A]">Reject Payout & Refund</h3>
                  <p className="text-xs text-[#64748B]">Instantly refunds ₹{rejectModalItem.amount} to creator wallet</p>
                </div>
              </div>
              <button
                onClick={() => setRejectModalItem(null)}
                className="p-1 rounded-full text-slate-400 hover:text-slate-600"
              >
                <X size={18} />
              </button>
            </div>

            <div className="p-3.5 rounded-2xl bg-red-50 border border-red-200 text-xs text-red-900 space-y-1 font-mono">
              <div>Amount to Refund: <strong>₹{rejectModalItem.amount.toLocaleString()}</strong></div>
              <div>User: {rejectModalItem.user_name || rejectModalItem.beneficiary_name} ({rejectModalItem.user_email})</div>
            </div>

            <form onSubmit={handleRejectSubmit} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-[#0F172A] block mb-1">
                  Reason for Rejection *
                </label>
                <textarea
                  rows={3}
                  required
                  placeholder="e.g. Bank beneficiary name returned error: Account closed or dormant."
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  className="w-full p-3 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs focus:outline-none focus:border-red-500"
                />
              </div>

              {/* Presets */}
              <div className="space-y-1.5">
                <span className="text-[10px] font-mono uppercase text-[#64748B] block">Common Reasons:</span>
                <div className="flex flex-wrap gap-1.5">
                  {[
                    'Bank account invalid or dormant',
                    'Name mismatch on bank records',
                    'Bank server transfer timeout / reversed',
                  ].map((preset) => (
                    <button
                      key={preset}
                      type="button"
                      onClick={() => setRejectReason(preset)}
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
                  disabled={processingId !== null}
                  className="px-5 py-2 rounded-xl bg-red-600 hover:bg-red-700 text-white font-semibold text-xs shadow-sm transition-colors cursor-pointer"
                >
                  {processingId ? 'Refunding...' : 'Confirm Rejection & Refund'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
