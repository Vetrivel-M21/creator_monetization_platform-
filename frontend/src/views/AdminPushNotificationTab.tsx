import React, { useState, useEffect } from 'react';
import {
  Bell,
  Send,
  Users,
  Smartphone,
  Globe,
  CheckCircle2,
  AlertTriangle,
  RefreshCw,
  Image,
  Shield,
  Sparkles,
  Flame,
  Award,
  ChevronRight,
  Clock,
  X
} from 'lucide-react';
import { adminService } from '../services/adminService';
import type { AdminUserAuditItem, PushJobHistoryItem, CustomPushRequest } from '../types';

interface AdminPushNotificationTabProps {
  auditUsers: AdminUserAuditItem[];
}

export const AdminPushNotificationTab: React.FC<AdminPushNotificationTabProps> = ({ auditUsers }) => {
  // Form State
  const [targetAudience, setTargetAudience] = useState<CustomPushRequest['target_audience']>('all');
  const [targetUserId, setTargetUserId] = useState('');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [targetScreen, setTargetScreen] = useState('explore');
  const [targetId, setTargetId] = useState('');

  // UI & Feedback State
  const [previewDevice, setPreviewDevice] = useState<'mobile' | 'desktop'>('mobile');
  const [isSending, setIsSending] = useState(false);
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  // History State
  const [historyJobs, setHistoryJobs] = useState<PushJobHistoryItem[]>([]);
  const [isLoadingHistory, setIsLoadingHistory] = useState(false);

  const loadHistory = async () => {
    try {
      setIsLoadingHistory(true);
      const data = await adminService.fetchPushHistory();
      setHistoryJobs(data);
    } catch (err: any) {
      console.error('Failed loading push history:', err);
    } finally {
      setIsLoadingHistory(false);
    }
  };

  useEffect(() => {
    loadHistory();
  }, []);

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !body.trim()) {
      setFeedback({ type: 'error', message: 'Title and notification message are required.' });
      return;
    }

    if (targetAudience === 'user' && !targetUserId.trim()) {
      setFeedback({ type: 'error', message: 'Please specify a target user ID.' });
      return;
    }

    try {
      setIsSending(true);
      setFeedback(null);

      await adminService.sendCustomPush({
        title: title.trim(),
        body: body.trim(),
        image_url: imageUrl.trim() || undefined,
        target_audience: targetAudience,
        target_user_id: targetAudience === 'user' ? targetUserId.trim() : undefined,
        target_screen: targetScreen,
        target_id: targetId.trim() || undefined,
      });

      setFeedback({
        type: 'success',
        message: '✓ Push notification queued for dispatch! Background worker is delivering across devices.',
      });

      // Clear non-critical inputs
      setTitle('');
      setBody('');
      setImageUrl('');
      setTargetId('');

      // Reload history table after 2 seconds
      setTimeout(loadHistory, 2500);
    } catch (err: any) {
      setFeedback({
        type: 'error',
        message: err.message || 'Failed to dispatch push notification.',
      });
    } finally {
      setIsSending(false);
    }
  };

  // Quick Preset Samples
  const applyPreset = (presetTitle: string, presetBody: string, presetImage: string, presetScreen: string) => {
    setTitle(presetTitle);
    setBody(presetBody);
    setImageUrl(presetImage);
    setTargetScreen(presetScreen);
  };

  // Metrics summary
  const totalSent = historyJobs.reduce((acc, j) => acc + (j.sent_count || 0), 0);
  const totalFailed = historyJobs.reduce((acc, j) => acc + (j.failed_count || 0), 0);

  return (
    <div className="space-y-8 animate-fade-in">
      {/* Top Header Card */}
      <div className="p-6 rounded-3xl bg-gradient-to-r from-blue-900/10 via-indigo-900/5 to-transparent border border-blue-100 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-[#2563EB] mb-1">
            <Bell size={14} />
            <span>FCM Push Notification Hub</span>
          </div>
          <h2 className="text-xl sm:text-2xl font-bold text-[#0F172A]">
            Push Broadcast & Notification Control Desk
          </h2>
          <p className="text-xs sm:text-sm text-[#64748B] mt-0.5 max-w-2xl">
            Dispatch instant push messages directly to user mobile phones and desktop browsers. Target specific creator tiers, individuals, or all active platform members.
          </p>
        </div>

        {/* Quick Stats Badges */}
        <div className="flex items-center gap-3">
          <div className="px-4 py-2.5 rounded-2xl bg-white border border-[#DCE7F6] shadow-xs text-center min-w-[90px]">
            <span className="text-[10px] uppercase font-bold text-[#64748B] block">Delivered</span>
            <span className="text-base font-extrabold text-emerald-600">{totalSent.toLocaleString()}</span>
          </div>
          <div className="px-4 py-2.5 rounded-2xl bg-white border border-[#DCE7F6] shadow-xs text-center min-w-[90px]">
            <span className="text-[10px] uppercase font-bold text-[#64748B] block">Failed</span>
            <span className="text-base font-extrabold text-rose-500">{totalFailed.toLocaleString()}</span>
          </div>
          <div className="px-4 py-2.5 rounded-2xl bg-white border border-[#DCE7F6] shadow-xs text-center min-w-[90px]">
            <span className="text-[10px] uppercase font-bold text-[#64748B] block">Campaigns</span>
            <span className="text-base font-extrabold text-[#0F172A]">{historyJobs.length}</span>
          </div>
        </div>
      </div>

      {feedback && (
        <div
          className={`p-4 rounded-2xl border text-xs sm:text-sm flex items-center justify-between gap-3 shadow-xs animate-fade-in ${
            feedback.type === 'success'
              ? 'bg-emerald-50 border-emerald-200 text-emerald-800'
              : 'bg-red-50 border-red-200 text-red-800'
          }`}
        >
          <div className="flex items-center gap-2">
            {feedback.type === 'success' ? (
              <CheckCircle2 size={18} className="text-emerald-600 shrink-0" />
            ) : (
              <AlertTriangle size={18} className="text-red-600 shrink-0" />
            )}
            <span className="font-medium">{feedback.message}</span>
          </div>
          <button
            onClick={() => setFeedback(null)}
            className="text-gray-400 hover:text-gray-600 p-1 rounded-md"
          >
            <X size={15} />
          </button>
        </div>
      )}

      {/* Main 2-Column Grid: Composer & Device Simulation */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
        {/* Left Column: Notification Composer (7 Cols) */}
        <div className="lg:col-span-7 space-y-6">
          <div className="p-6 sm:p-7 rounded-3xl bg-white border border-[#DCE7F6] shadow-xs">
            <h3 className="text-base font-bold text-[#0F172A] flex items-center gap-2 mb-5">
              <Send size={16} className="text-[#2563EB]" />
              <span>Compose Custom Notification</span>
            </h3>

            {/* Quick Inspiration Presets */}
            <div className="mb-6">
              <span className="text-[11px] font-bold text-[#64748B] uppercase tracking-wider block mb-2">
                Quick Template Presets
              </span>
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() =>
                    applyPreset(
                      '🎉 Creator Milestone Challenge',
                      'Double payout rewards unlocked for all approved Silver and Gold uploads this weekend!',
                      'https://images.unsplash.com/photo-1579208575657-c595a05383b7?w=1280&q=80',
                      'studio'
                    )
                  }
                  className="px-2.5 py-1 text-xs rounded-full bg-blue-50 text-blue-700 hover:bg-blue-100 border border-blue-200 font-medium transition cursor-pointer"
                >
                  🚀 Weekend Bonus
                </button>
                <button
                  type="button"
                  onClick={() =>
                    applyPreset(
                      '⚡ Platform Maintenance Complete',
                      'Ultra-fast CMAF HLS streaming engine is now live. Enjoy instant video playback!',
                      'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1280&q=80',
                      'explore'
                    )
                  }
                  className="px-2.5 py-1 text-xs rounded-full bg-purple-50 text-purple-700 hover:bg-purple-100 border border-purple-200 font-medium transition cursor-pointer"
                >
                  ⚙️ System Update
                </button>
                <button
                  type="button"
                  onClick={() =>
                    applyPreset(
                      '✨ New Featured Creator Series',
                      'Explore today\'s trending tech & startup documentaries handpicked by ARMSS editors.',
                      'https://images.unsplash.com/photo-1536240478700-b869070f9279?w=1280&q=80',
                      'explore'
                    )
                  }
                  className="px-2.5 py-1 text-xs rounded-full bg-amber-50 text-amber-800 hover:bg-amber-100 border border-amber-200 font-medium transition cursor-pointer"
                >
                  ⭐ Featured Content
                </button>
              </div>
            </div>

            <form onSubmit={handleSend} className="space-y-4">
              {/* Audience Target */}
              <div>
                <label className="block text-xs font-bold text-[#0F172A] mb-1.5">
                  Target Recipient Audience
                </label>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                  {[
                    { id: 'all', label: 'All Users', icon: Users },
                    { id: 'admins', label: 'Admins Only', icon: Shield },
                    { id: 'tier:silver', label: 'Silver Creators', icon: Award },
                    { id: 'tier:gold', label: 'Gold Creators', icon: Sparkles },
                    { id: 'tier:diamond', label: 'Diamond Tier', icon: Flame },
                    { id: 'user', label: 'Specific User', icon: Smartphone },
                  ].map((aud) => {
                    const Icon = aud.icon;
                    const isSelected = targetAudience === aud.id;
                    return (
                      <button
                        type="button"
                        key={aud.id}
                        onClick={() => setTargetAudience(aud.id as any)}
                        className={`p-2.5 rounded-xl border text-xs font-semibold flex items-center gap-2 transition cursor-pointer text-left ${
                          isSelected
                            ? 'bg-blue-50 border-[#2563EB] text-[#2563EB] shadow-xs'
                            : 'bg-[#F8FAFC] border-[#DCE7F6] text-[#475569] hover:bg-slate-100'
                        }`}
                      >
                        <Icon size={14} className={isSelected ? 'text-[#2563EB]' : 'text-[#64748B]'} />
                        <span className="truncate">{aud.label}</span>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Target User ID (Conditional) */}
              {targetAudience === 'user' && (
                <div className="p-3.5 rounded-2xl bg-blue-50/50 border border-blue-200 space-y-2">
                  <label className="block text-xs font-bold text-blue-900">
                    Target User ID or Search Creator
                  </label>
                  <div className="flex gap-2">
                    <input
                      type="text"
                      value={targetUserId}
                      onChange={(e) => setTargetUserId(e.target.value)}
                      placeholder="e.g. usr-01 or user UUID"
                      className="w-full px-3 py-2 text-xs rounded-xl bg-white border border-[#DCE7F6] focus:border-[#2563EB] focus:outline-none"
                    />
                    {auditUsers.length > 0 && (
                      <select
                        onChange={(e) => setTargetUserId(e.target.value)}
                        className="px-3 py-2 text-xs rounded-xl bg-white border border-[#DCE7F6] text-[#475569] focus:outline-none max-w-[140px]"
                      >
                        <option value="">Select User...</option>
                        {auditUsers.map((u) => (
                          <option key={u.id} value={u.id}>
                            {u.name} ({u.tier})
                          </option>
                        ))}
                      </select>
                    )}
                  </div>
                </div>
              )}

              {/* Title Input */}
              <div>
                <div className="flex justify-between items-center mb-1">
                  <label className="text-xs font-bold text-[#0F172A]">Notification Title</label>
                  <span className="text-[10px] text-[#94A3B8] font-mono">{title.length}/60</span>
                </div>
                <input
                  type="text"
                  maxLength={65}
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="e.g. 🎬 New video upload approved!"
                  className="w-full px-3.5 py-2.5 text-xs sm:text-sm rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-[#0F172A] focus:bg-white focus:border-[#2563EB] focus:outline-none transition"
                />
              </div>

              {/* Body Textarea */}
              <div>
                <div className="flex justify-between items-center mb-1">
                  <label className="text-xs font-bold text-[#0F172A]">Message Body</label>
                  <span className="text-[10px] text-[#94A3B8] font-mono">{body.length}/180</span>
                </div>
                <textarea
                  rows={3}
                  maxLength={200}
                  value={body}
                  onChange={(e) => setBody(e.target.value)}
                  placeholder="e.g. Your video 'How to build in Go' is now live and published to your channel subscribers."
                  className="w-full px-3.5 py-2.5 text-xs sm:text-sm rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-[#0F172A] focus:bg-white focus:border-[#2563EB] focus:outline-none transition resize-none"
                />
              </div>

              {/* Image URL */}
              <div>
                <label className="block text-xs font-bold text-[#0F172A] mb-1">
                  Rich Banner Image URL (Optional)
                </label>
                <div className="relative">
                  <input
                    type="url"
                    value={imageUrl}
                    onChange={(e) => setImageUrl(e.target.value)}
                    placeholder="https://... (PNG/JPG image thumbnail)"
                    className="w-full pl-9 pr-3.5 py-2.5 text-xs rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-[#0F172A] focus:bg-white focus:border-[#2563EB] focus:outline-none transition"
                  />
                  <Image size={14} className="absolute left-3 top-3 text-[#94A3B8]" />
                </div>
                <p className="text-[11px] text-[#64748B] mt-1">
                  Public HTTPS image shown on Android BigPicture banner and Web desktop notification.
                </p>
              </div>

              {/* Deep Link Destination */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
                <div>
                  <label className="block text-xs font-bold text-[#0F172A] mb-1">
                    On-Tap Target Screen
                  </label>
                  <select
                    value={targetScreen}
                    onChange={(e) => setTargetScreen(e.target.value)}
                    className="w-full px-3.5 py-2.5 text-xs rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-[#0F172A] focus:bg-white focus:border-[#2563EB] focus:outline-none transition"
                  >
                    <option value="explore">Explore Feed</option>
                    <option value="studio">Creator Studio</option>
                    <option value="video">Video Player</option>
                    <option value="admin">Admin Moderation</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-bold text-[#0F172A] mb-1">
                    Target Resource ID (Optional)
                  </label>
                  <input
                    type="text"
                    value={targetId}
                    onChange={(e) => setTargetId(e.target.value)}
                    placeholder="e.g. vid-01 or user-id"
                    className="w-full px-3.5 py-2.5 text-xs rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-[#0F172A] focus:bg-white focus:border-[#2563EB] focus:outline-none transition"
                  />
                </div>
              </div>

              {/* Submit Button */}
              <div className="pt-3">
                <button
                  type="submit"
                  disabled={isSending}
                  className="w-full py-3 px-5 rounded-2xl bg-[#2563EB] hover:bg-blue-700 text-white font-bold text-xs sm:text-sm flex items-center justify-center gap-2 shadow-sm transition cursor-pointer disabled:opacity-60"
                >
                  <Send size={15} className={isSending ? 'animate-bounce' : ''} />
                  <span>{isSending ? 'Queueing Push Broadcast...' : 'Dispatch Push Notification'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>

        {/* Right Column: Interactive Device Simulation Preview (5 Cols) */}
        <div className="lg:col-span-5 space-y-4">
          <div className="p-6 rounded-3xl bg-white border border-[#DCE7F6] shadow-xs">
            <div className="flex items-center justify-between mb-4">
              <span className="text-xs font-bold text-[#0F172A] flex items-center gap-2">
                <Smartphone size={14} className="text-[#2563EB]" />
                <span>Live Rendering Preview</span>
              </span>

              {/* Toggle Device View */}
              <div className="flex items-center p-0.5 rounded-lg bg-[#F1F5F9] border border-[#E2E8F0] text-[11px] font-semibold">
                <button
                  type="button"
                  onClick={() => setPreviewDevice('mobile')}
                  className={`px-2.5 py-1 rounded-md transition cursor-pointer flex items-center gap-1 ${
                    previewDevice === 'mobile'
                      ? 'bg-white text-[#2563EB] shadow-xs'
                      : 'text-[#64748B] hover:text-[#0F172A]'
                  }`}
                >
                  <Smartphone size={12} />
                  <span>Mobile</span>
                </button>
                <button
                  type="button"
                  onClick={() => setPreviewDevice('desktop')}
                  className={`px-2.5 py-1 rounded-md transition cursor-pointer flex items-center gap-1 ${
                    previewDevice === 'desktop'
                      ? 'bg-white text-[#2563EB] shadow-xs'
                      : 'text-[#64748B] hover:text-[#0F172A]'
                  }`}
                >
                  <Globe size={12} />
                  <span>Web</span>
                </button>
              </div>
            </div>

            {/* Mobile Android 14 Frame */}
            {previewDevice === 'mobile' ? (
              <div className="mx-auto max-w-[310px] rounded-[36px] p-3.5 bg-slate-900 shadow-2xl border-4 border-slate-700">
                {/* Phone Speaker Notch */}
                <div className="w-16 h-3 bg-slate-800 rounded-full mx-auto mb-3" />

                {/* Status Bar */}
                <div className="flex justify-between items-center text-[10px] text-slate-300 font-mono px-2 mb-4">
                  <span>9:41</span>
                  <div className="flex items-center gap-1">
                    <span>5G</span>
                    <span className="w-3 h-2 bg-slate-300 rounded-xs inline-block" />
                  </div>
                </div>

                {/* Push Notification Card inside Lockscreen / Shade */}
                <div className="p-3.5 rounded-2xl bg-slate-800/90 border border-slate-700 backdrop-blur-md shadow-lg space-y-2">
                  <div className="flex items-center justify-between text-[11px] text-slate-300">
                    <div className="flex items-center gap-1.5">
                      <div className="w-4 h-4 rounded-full bg-[#2563EB] flex items-center justify-center text-white text-[8px] font-bold">
                        A
                      </div>
                      <span className="font-semibold text-white">ARMSS Media</span>
                      <span className="text-slate-400">• now</span>
                    </div>
                  </div>

                  <div>
                    <h4 className="text-xs font-bold text-white leading-snug">
                      {title.trim() || 'Notification Title Goes Here'}
                    </h4>
                    <p className="text-[11px] text-slate-300 mt-0.5 line-clamp-3 leading-normal">
                      {body.trim() || 'This preview shows how your message renders on Android and iOS lock screens and heads-up banners.'}
                    </p>
                  </div>

                  {/* Banner Image Preview */}
                  {imageUrl.trim() && (
                    <div className="rounded-xl overflow-hidden mt-2 bg-slate-950 aspect-[2/1] border border-slate-700">
                      <img
                        src={imageUrl.trim()}
                        alt="Notification Banner"
                        className="w-full h-full object-cover"
                        onError={(e) => {
                          (e.target as HTMLElement).style.display = 'none';
                        }}
                      />
                    </div>
                  )}

                  {/* Action Link Footer */}
                  <div className="pt-1.5 flex items-center justify-between text-[10px] text-blue-400 font-medium">
                    <span>Open in {targetScreen}</span>
                    <ChevronRight size={12} />
                  </div>
                </div>

                <div className="w-24 h-1 bg-slate-600 rounded-full mx-auto mt-6 mb-1" />
              </div>
            ) : (
              /* Desktop Web Push Notification Card */
              <div className="p-4 rounded-2xl bg-[#0F172A] text-white shadow-xl border border-slate-800 space-y-2.5 max-w-sm mx-auto">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <div className="w-5 h-5 rounded-lg bg-[#2563EB] flex items-center justify-center text-white text-[10px] font-bold">
                      A
                    </div>
                    <div>
                      <span className="text-[11px] font-semibold block text-slate-200">ARMSS Platform</span>
                      <span className="text-[9px] text-slate-400">entertainment.aurapictures.online</span>
                    </div>
                  </div>
                  <span className="text-[10px] text-slate-400">Just now</span>
                </div>

                <div>
                  <h4 className="text-xs font-bold text-white">
                    {title.trim() || 'Web Push Alert Title'}
                  </h4>
                  <p className="text-[11px] text-slate-300 mt-0.5 line-clamp-3">
                    {body.trim() || 'Desktop browser notification shown via Firebase Service Worker.'}
                  </p>
                </div>

                {imageUrl.trim() && (
                  <div className="rounded-lg overflow-hidden bg-slate-900 aspect-[16/9] border border-slate-700">
                    <img
                      src={imageUrl.trim()}
                      alt="Banner Preview"
                      className="w-full h-full object-cover"
                      onError={(e) => {
                        (e.target as HTMLElement).style.display = 'none';
                      }}
                    />
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Bottom Section: Delivery Metrics & Sent Notification History */}
      <div className="p-6 sm:p-7 rounded-3xl bg-white border border-[#DCE7F6] shadow-xs space-y-4">
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div>
            <h3 className="text-base font-bold text-[#0F172A] flex items-center gap-2">
              <Clock size={16} className="text-[#2563EB]" />
              <span>Push Notification Dispatch History & Delivery Metrics</span>
            </h3>
            <p className="text-xs text-[#64748B] mt-0.5">
              Real-time audit log of all automated video triggers and custom broadcast jobs dispatched by the background worker.
            </p>
          </div>

          <button
            onClick={loadHistory}
            disabled={isLoadingHistory}
            className="px-3.5 py-1.5 text-xs font-semibold rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-[#475569] hover:bg-slate-100 flex items-center gap-1.5 transition cursor-pointer"
          >
            <RefreshCw size={13} className={isLoadingHistory ? 'animate-spin' : ''} />
            <span>Refresh Metrics</span>
          </button>
        </div>

        {/* History Table */}
        <div className="overflow-x-auto rounded-2xl border border-[#DCE7F6]">
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="bg-[#F8FAFC] border-b border-[#DCE7F6] text-[#64748B] uppercase font-bold text-[10px] tracking-wider">
                <th className="py-3 px-4">Job ID</th>
                <th className="py-3 px-4">Kind / Audience</th>
                <th className="py-3 px-4">Notification Content</th>
                <th className="py-3 px-4">Status</th>
                <th className="py-3 px-4 text-center">Delivered</th>
                <th className="py-3 px-4 text-center">Failed</th>
                <th className="py-3 px-4 text-right">Created At</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[#E2E8F0]">
              {historyJobs.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-8 text-center text-[#64748B]">
                    {isLoadingHistory ? 'Loading history...' : 'No push notification jobs sent yet.'}
                  </td>
                </tr>
              ) : (
                historyJobs.map((job) => {
                  const isDone = job.status === 'done';
                  const isProcessing = job.status === 'processing';
                  const isFailed = job.status === 'failed';

                  return (
                    <tr key={job.id} className="hover:bg-slate-50/70 transition">
                      <td className="py-3.5 px-4 font-mono text-[11px] text-[#0F172A] font-semibold">
                        #{job.id}
                      </td>

                      <td className="py-3.5 px-4">
                        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-blue-50 text-blue-700 border border-blue-200">
                          {job.kind}
                          {job.target_filter ? ` (${job.target_filter})` : job.target_id ? ` #${job.target_id}` : ''}
                        </span>
                      </td>

                      <td className="py-3.5 px-4 max-w-xs sm:max-w-md">
                        <div className="font-semibold text-[#0F172A] truncate">
                          {job.payload?.title || 'Untitled Notification'}
                        </div>
                        <div className="text-[11px] text-[#64748B] truncate mt-0.5">
                          {job.payload?.body || 'No description'}
                        </div>
                        {job.last_error && (
                          <div className="text-[10px] text-red-600 font-mono mt-1">
                            Note: {job.last_error}
                          </div>
                        )}
                      </td>

                      <td className="py-3.5 px-4">
                        <span
                          className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-bold capitalize ${
                            isDone
                              ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                              : isProcessing
                              ? 'bg-amber-50 text-amber-700 border border-amber-200 animate-pulse'
                              : isFailed
                              ? 'bg-red-50 text-red-700 border border-red-200'
                              : 'bg-blue-50 text-blue-700 border border-blue-200'
                          }`}
                        >
                          {job.status}
                        </span>
                      </td>

                      <td className="py-3.5 px-4 text-center font-bold text-emerald-600">
                        {job.sent_count || 0}
                      </td>

                      <td className="py-3.5 px-4 text-center font-bold text-red-500">
                        {job.failed_count || 0}
                      </td>

                      <td className="py-3.5 px-4 text-right text-[11px] text-[#64748B] whitespace-nowrap">
                        {job.created_at ? new Date(job.created_at).toLocaleString() : 'Just now'}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
