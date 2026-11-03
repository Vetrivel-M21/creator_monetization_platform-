import React, { useState, useEffect } from 'react';
import {
  ShieldAlert,
  CheckCircle2,
  XCircle,
  AlertTriangle,
  Play,
  Award,
  RefreshCw,
  Coins,
  ShieldCheck,
  AlertCircle,
  Plus,
  Trash2,
  Shield,
  UserCog,
  X,
  MessageSquare,
  Send,
  Ban,
  Clock,
  Sparkles,
} from 'lucide-react';
import type { Video, AdminUserAuditItem, Category, SupportThread, SupportMessage } from '../types';
import { adminService } from '../services/adminService';
import { formatDuration } from '../utils/formatters';

interface AdminViewProps {
  videos: Video[];
  onModerateSuccess: () => void;
  onSelectVideo: (video: Video) => void;
}

export const AdminView: React.FC<AdminViewProps> = ({
  videos,
  onModerateSuccess,
  onSelectVideo,
}) => {
  const [activeTab, setActiveTab] = useState<'moderation' | 'creators' | 'categories' | 'settings' | 'support'>('moderation');
  const [processingId, setProcessingId] = useState<string | null>(null);
  const [actionMessage, setActionMessage] = useState<string | null>(null);
  const [actionType, setActionType] = useState<'success' | 'warning' | 'info'>('info');

  // Platform Dynamic Settings
  const [silverMilestoneReward, setSilverMilestoneReward] = useState(2500);
  const [goldMilestoneReward, setGoldMilestoneReward] = useState(5000);
  const [diamondMilestoneReward, setDiamondMilestoneReward] = useState(10000);
  const [fixedRateSilver, setFixedRateSilver] = useState(50);
  const [fixedRateGold, setFixedRateGold] = useState(65);
  const [fixedRateDiamond, setFixedRateDiamond] = useState(85);
  const [settingsSaved, setSettingsSaved] = useState(false);

  // Moderation Videos Queue
  const [moderationVideos, setModerationVideos] = useState<Video[]>([]);
  const [isLoadingVideos, setIsLoadingVideos] = useState(false);
  const [statusFilter, setStatusFilter] = useState<'all' | 'pending' | 'approved' | 'rejected'>('all');

  const loadModerationVideos = async () => {
    try {
      setIsLoadingVideos(true);
      const data = await adminService.fetchVideos();
      if (Array.isArray(data) && data.length > 0) {
        setModerationVideos(data);
      } else if (videos && videos.length > 0) {
        setModerationVideos(videos);
      }
    } catch (err) {
      console.error('Failed to load moderation videos:', err);
      if (videos && videos.length > 0) {
        setModerationVideos(videos);
      }
    } finally {
      setIsLoadingVideos(false);
    }
  };

  // Live Creators & Users Audit List
  const [auditUsers, setAuditUsers] = useState<AdminUserAuditItem[]>([]);
  const [isLoadingUsers, setIsLoadingUsers] = useState(false);
  const [userStatusFilter, setUserStatusFilter] = useState<'all' | 'active' | 'pending' | 'suspended'>('all');

  const loadAuditUsers = async () => {
    try {
      setIsLoadingUsers(true);
      const data = await adminService.fetchUsers();
      setAuditUsers(data);
    } catch (err) {
      console.error('Failed to load audit users:', err);
    } finally {
      setIsLoadingUsers(false);
    }
  };

  // Category Management State
  const [categories, setCategories] = useState<Category[]>([]);
  const [isLoadingCategories, setIsLoadingCategories] = useState(false);
  const [isCategoryModalOpen, setIsCategoryModalOpen] = useState(false);
  const [editingCategory, setEditingCategory] = useState<Category | null>(null);
  const [catName, setCatName] = useState('');
  const [catSlug, setCatSlug] = useState('');
  const [catDescription, setCatDescription] = useState('');
  const [catIcon, setCatIcon] = useState('Tag');
  const [catIsActive, setCatIsActive] = useState(true);
  const [isSubmittingCat, setIsSubmittingCat] = useState(false);
  const [catError, setCatError] = useState<string | null>(null);

  const loadCategories = async () => {
    try {
      setIsLoadingCategories(true);
      const data = await adminService.fetchCategories(true);
      setCategories(data);
    } catch (err) {
      console.error('Failed to load categories:', err);
    } finally {
      setIsLoadingCategories(false);
    }
  };

  // Support Chat Desk State
  const [supportThreads, setSupportThreads] = useState<SupportThread[]>([]);
  const [selectedThread, setSelectedThread] = useState<SupportThread | null>(null);
  const [supportMessages, setSupportMessages] = useState<SupportMessage[]>([]);
  const [isLoadingThreads, setIsLoadingThreads] = useState(false);
  const [isLoadingMessages, setIsLoadingMessages] = useState(false);
  const [replyText, setReplyText] = useState('');
  const [isSendingReply, setIsSendingReply] = useState(false);

  const loadSupportThreads = async () => {
    try {
      setIsLoadingThreads(true);
      const data = await adminService.fetchSupportThreads();
      setSupportThreads(data);
      if (data.length > 0 && !selectedThread) {
        handleSelectThread(data[0]);
      }
    } catch (err) {
      console.error('Failed to load support threads:', err);
    } finally {
      setIsLoadingThreads(false);
    }
  };

  const handleSelectThread = async (thread: SupportThread) => {
    setSelectedThread(thread);
    try {
      setIsLoadingMessages(true);
      const msgs = await adminService.fetchSupportMessages(thread.id);
      setSupportMessages(msgs);
      // Reset local unread counter
      setSupportThreads((prev) =>
        prev.map((t) => (t.id === thread.id ? { ...t, unread_admin_count: 0 } : t))
      );
    } catch (err) {
      console.error('Failed to load thread messages:', err);
    } finally {
      setIsLoadingMessages(false);
    }
  };

  const handleSendReply = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedThread || !replyText.trim() || isSendingReply) return;

    try {
      setIsSendingReply(true);
      const newMsg = await adminService.replySupportThread(selectedThread.id, replyText.trim());
      setSupportMessages((prev) => [...prev, newMsg]);
      setReplyText('');
      loadSupportThreads();
    } catch (err) {
      console.error('Failed to send reply:', err);
    } finally {
      setIsSendingReply(false);
    }
  };

  const handleToggleThreadStatus = async () => {
    if (!selectedThread) return;
    const newStatus = selectedThread.status === 'open' ? 'resolved' : 'open';
    try {
      await adminService.updateSupportStatus(selectedThread.id, newStatus);
      setSelectedThread({ ...selectedThread, status: newStatus });
      setSupportThreads((prev) =>
        prev.map((t) => (t.id === selectedThread.id ? { ...t, status: newStatus } : t))
      );
    } catch (err) {
      console.error('Failed to toggle status:', err);
    }
  };

  // Load Platform Settings
  const loadSettings = async () => {
    try {
      const s = await adminService.fetchSettings();
      if (s) {
        if (s.milestone_silver) setSilverMilestoneReward(s.milestone_silver);
        if (s.milestone_gold) setGoldMilestoneReward(s.milestone_gold);
        if (s.milestone_diamond) setDiamondMilestoneReward(s.milestone_diamond);
        if (s.fixed_rate_silver) setFixedRateSilver(s.fixed_rate_silver);
        if (s.fixed_rate_gold) setFixedRateGold(s.fixed_rate_gold);
        if (s.fixed_rate_diamond) setFixedRateDiamond(s.fixed_rate_diamond);
      }
    } catch (_) {}
  };

  useEffect(() => {
    loadModerationVideos();
    loadAuditUsers();
    loadCategories();
    loadSettings();
    loadSupportThreads();
  }, []);

  const handleModerate = async (videoId: string, action: 'approve' | 'reject', reason?: string) => {
    try {
      setProcessingId(videoId);
      const res = await adminService.moderateVideo(videoId, action, reason);
      await loadModerationVideos();
      onModerateSuccess();

      if (action === 'approve') {
        if (res.milestone_awarded) {
          setActionType('success');
          setActionMessage(
            `🎉 Milestone Unlocked! ₹${res.milestone_amount?.toLocaleString()} Milestone Reward credited to creator wallet!`
          );
        } else {
          setActionType('info');
          setActionMessage(
            res.message || 'Video approved! Counts toward creator milestone quotas.'
          );
        }
      } else {
        setActionType('warning');
        setActionMessage(reason ? `Video rejected: ${reason}` : 'Video rejected as synthetic AI content.');
      }

      loadAuditUsers();
      setTimeout(() => {
        setActionMessage(null);
        onModerateSuccess();
      }, 2500);
    } catch {
      setActionType('warning');
      setActionMessage('Failed to update video status');
    } finally {
      setProcessingId(null);
    }
  };

  // User Actions: Approve, Reject, Block, Unblock, Delete
  const handleApproveUser = async (userId: string) => {
    try {
      await adminService.approveUser(userId);
      setAuditUsers((prev) =>
        prev.map((u) => (u.id === userId ? { ...u, account_status: 'active', is_active: true } : u))
      );
      setActionType('success');
      setActionMessage('Creator account approved successfully! Creator can now upload videos and monetize.');
      setTimeout(() => setActionMessage(null), 3000);
    } catch (err) {
      console.error('Failed to approve user:', err);
    }
  };

  const handleRejectUser = async (userId: string) => {
    const reason = window.prompt('Enter rejection reason for this creator application:', 'Profile information does not meet verification criteria');
    if (reason === null) return;

    try {
      await adminService.rejectUser(userId, reason);
      setAuditUsers((prev) =>
        prev.map((u) => (u.id === userId ? { ...u, account_status: 'rejected', is_active: false, rejection_reason: reason } : u))
      );
      setActionType('warning');
      setActionMessage(`Creator application rejected.`);
      setTimeout(() => setActionMessage(null), 3000);
    } catch (err) {
      console.error('Failed to reject user:', err);
    }
  };

  const handleBlockUser = async (userId: string) => {
    const reason = window.prompt('Enter reason for temporary suspension / block:', 'Violation of community guidelines');
    if (reason === null) return;

    try {
      await adminService.blockUser(userId, reason);
      setAuditUsers((prev) =>
        prev.map((u) => (u.id === userId ? { ...u, account_status: 'suspended', is_active: false, suspension_reason: reason } : u))
      );
      setActionType('warning');
      setActionMessage(`User account temporarily suspended.`);
      setTimeout(() => setActionMessage(null), 3000);
    } catch (err) {
      console.error('Failed to block user:', err);
    }
  };

  const handleUnblockUser = async (userId: string) => {
    try {
      await adminService.unblockUser(userId);
      setAuditUsers((prev) =>
        prev.map((u) => (u.id === userId ? { ...u, account_status: 'active', is_active: true, suspension_reason: undefined } : u))
      );
      setActionType('success');
      setActionMessage(`Account suspension lifted. Access restored.`);
      setTimeout(() => setActionMessage(null), 3000);
    } catch (err) {
      console.error('Failed to unblock user:', err);
    }
  };

  const handleDeleteUser = async (user: AdminUserAuditItem) => {
    const confirm = window.prompt(`DANGER: Are you sure you want to permanently delete "${user.name}" (${user.email}) and all their videos/data?\nType DELETE to confirm:`);
    if (confirm !== 'DELETE') return;

    try {
      await adminService.deleteUser(user.id);
      setAuditUsers((prev) => prev.filter((u) => u.id !== user.id));
      setActionType('success');
      setActionMessage(`Account for "${user.name}" has been permanently deleted.`);
      setTimeout(() => setActionMessage(null), 3000);
    } catch (err: any) {
      alert(err.message || 'Failed to delete user');
    }
  };

  const handleUpdateRole = async (userId: string, targetRole: 'admin' | 'user') => {
    const actionLabel = targetRole === 'admin' ? 'promote this user to Administrator' : 'demote this user to Creator';
    if (!window.confirm(`Are you sure you want to ${actionLabel}?`)) return;

    try {
      await adminService.updateUserRole(userId, targetRole);
      setAuditUsers((prev) =>
        prev.map((u) => (u.id === userId ? { ...u, role: targetRole } : u))
      );
      setActionType('success');
      setActionMessage(`User role updated to ${targetRole}.`);
      setTimeout(() => setActionMessage(null), 2500);
    } catch (err) {
      console.error('Failed to update user role:', err);
    }
  };

  const handleSaveSettings = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await adminService.updateSettings({
        payout_mode: 'fixed_per_video',
        fixed_rate_silver: fixedRateSilver,
        fixed_rate_gold: fixedRateGold,
        fixed_rate_diamond: fixedRateDiamond,
        rate_30m: 80,
        rate_20m: 60,
        rate_10m: 50,
        rate_5m: 35,
        rate_2m: 25,
        milestone_silver: silverMilestoneReward,
        milestone_gold: goldMilestoneReward,
        milestone_diamond: diamondMilestoneReward,
        ban_ai_videos: true,
      });
      setSettingsSaved(true);
      setTimeout(() => setSettingsSaved(false), 2500);
    } catch (err) {
      console.error('Failed to save settings:', err);
    }
  };

  // Category Handlers
  const handleOpenCreateCategory = () => {
    setEditingCategory(null);
    setCatName('');
    setCatSlug('');
    setCatDescription('');
    setCatIcon('Tag');
    setCatIsActive(true);
    setCatError(null);
    setIsCategoryModalOpen(true);
  };

  const handleSaveCategory = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!catName.trim()) {
      setCatError('Category name is required');
      return;
    }
    try {
      setIsSubmittingCat(true);
      setCatError(null);
      if (editingCategory) {
        await adminService.updateCategory(editingCategory.id, {
          name: catName.trim(),
          slug: catSlug.trim(),
          description: catDescription.trim(),
          icon: catIcon.trim(),
          is_active: catIsActive,
        });
      } else {
        await adminService.createCategory({
          name: catName.trim(),
          slug: catSlug.trim(),
          description: catDescription.trim(),
          icon: catIcon.trim(),
          is_active: catIsActive,
        });
      }
      await loadCategories();
      setIsCategoryModalOpen(false);
    } catch (err: any) {
      setCatError(err.message || 'Failed to save category');
    } finally {
      setIsSubmittingCat(false);
    }
  };

  const handleDeleteCategory = async (cat: Category) => {
    if (!window.confirm(`Are you sure you want to permanently delete category "${cat.name}"?`)) return;
    try {
      await adminService.deleteCategory(cat.id);
      setCategories((prev) => prev.filter((c) => c.id !== cat.id));
    } catch (err: any) {
      alert(err.message || 'Failed to delete category');
    }
  };

  const pendingCreatorsCount = auditUsers.filter((u) => u.account_status === 'pending_approval').length;
  const totalUnreadSupport = supportThreads.reduce((acc, t) => acc + (t.unread_admin_count || 0), 0);

  return (
    <div className="flex flex-col gap-6 pb-24 max-w-7xl mx-auto animate-fade-in">
      {/* Top Banner (Bento Style) */}
      <div className="p-6 sm:p-8 rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-2xl bg-blue-50 border border-blue-200 flex items-center justify-center text-[#2563EB] shrink-0">
            <ShieldAlert size={22} />
          </div>
          <div>
            <h1 className="text-xl sm:text-2xl font-bold tracking-tight text-[#0F172A]">
              Admin Moderation & Platform Control
            </h1>
            <p className="text-xs text-[#64748B] mt-0.5 font-normal">
              Approvals & Lifecycle • Multi-Tier Monetization (Silver/Gold/Diamond) • Live Support Desk
            </p>
          </div>
        </div>

        {/* Tab Switcher */}
        <div className="flex items-center gap-6 sm:gap-8 border-b border-[#DCE7F6] pb-px overflow-x-auto">
          {[
            { id: 'moderation' as const, label: 'Moderation Queue' },
            {
              id: 'creators' as const,
              label: `Users & Roles (${auditUsers.length})`,
              badge: pendingCreatorsCount > 0 ? `${pendingCreatorsCount} Pending` : undefined,
              badgeColor: 'bg-amber-100 text-amber-800 border-amber-300',
            },
            { id: 'categories' as const, label: `Categories (${categories.length})` },
            { id: 'settings' as const, label: 'Monetization Rules' },
            {
              id: 'support' as const,
              label: 'Support Desk',
              badge: totalUnreadSupport > 0 ? `${totalUnreadSupport} New` : undefined,
              badgeColor: 'bg-blue-100 text-blue-800 border-blue-300',
            },
          ].map((tab) => {
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => {
                  setActiveTab(tab.id);
                  if (tab.id === 'creators') loadAuditUsers();
                  if (tab.id === 'categories') loadCategories();
                  if (tab.id === 'support') loadSupportThreads();
                }}
                className={`pb-3 pt-1 text-xs sm:text-sm whitespace-nowrap transition-all duration-200 cursor-pointer flex items-center gap-1.5 ${
                  isActive
                    ? 'border-b-2 border-[#2563EB] pb-2 text-[#0F172A] font-semibold'
                    : 'border-b-2 border-transparent text-[#64748B] hover:text-[#0F172A] font-normal'
                }`}
              >
                <span>{tab.label}</span>
                {tab.badge && (
                  <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded-full border ${tab.badgeColor}`}>
                    {tab.badge}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {actionMessage && (
        <div
          className={`p-4 rounded-2xl border text-xs flex items-center gap-2.5 shadow-sm animate-fade-in font-medium ${
            actionType === 'success'
              ? 'bg-emerald-50 border-emerald-200 text-emerald-800'
              : actionType === 'warning'
              ? 'bg-amber-50 border-amber-200 text-amber-800'
              : 'bg-blue-50 border-blue-200 text-blue-800'
          }`}
        >
          {actionType === 'success' ? (
            <CheckCircle2 size={16} className="text-emerald-600 shrink-0" />
          ) : actionType === 'warning' ? (
            <AlertTriangle size={16} className="text-amber-600 shrink-0" />
          ) : (
            <Coins size={16} className="text-[#2563EB] shrink-0" />
          )}
          <span>{actionMessage}</span>
        </div>
      )}

      {/* Tab 1: Video Moderation Queue */}
      {activeTab === 'moderation' && (() => {
        const allList = moderationVideos.length > 0 ? moderationVideos : videos;
        const filteredList = allList.filter((v) => {
          if (statusFilter === 'pending') return v.status === 'pending_review';
          if (statusFilter === 'approved') return v.status === 'approved';
          if (statusFilter === 'rejected') return v.status === 'rejected';
          return true;
        });

        return (
          <div className="space-y-5">
            <div className="p-4 rounded-2xl bg-[#FFFFFF] border border-[#DCE7F6] flex flex-wrap items-center justify-between gap-4">
              <div className="flex items-center gap-2">
                {(['all', 'pending', 'approved', 'rejected'] as const).map((s) => (
                  <button
                    key={s}
                    onClick={() => setStatusFilter(s)}
                    className={`px-3 py-1.5 rounded-full text-xs font-semibold capitalize transition-all cursor-pointer ${
                      statusFilter === s
                        ? 'bg-[#2563EB] text-white shadow-xs'
                        : 'bg-[#F8FAFC] text-[#64748B] hover:bg-[#E2E8F0] border border-[#DCE7F6]'
                    }`}
                  >
                    {s} ({allList.filter((v) => (s === 'all' ? true : s === 'pending' ? v.status === 'pending_review' : v.status === s)).length})
                  </button>
                ))}
              </div>
              <button
                onClick={loadModerationVideos}
                disabled={isLoadingVideos}
                className="btn-secondary-pill flex items-center gap-1.5 px-3.5 py-1.5 text-xs font-semibold text-[#64748B] hover:text-[#0F172A] cursor-pointer"
              >
                <RefreshCw size={13} className={isLoadingVideos ? 'animate-spin' : ''} />
                <span>Refresh</span>
              </button>
            </div>

            {filteredList.length === 0 ? (
              <div className="p-12 text-center rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] text-xs text-[#64748B]">
                No videos found in this filter.
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
                {filteredList.map((video) => (
                  <div
                    key={video.id}
                    className="rounded-2xl bg-[#FFFFFF] border border-[#DCE7F6] overflow-hidden flex flex-col justify-between hover:shadow-md transition-shadow"
                  >
                    <div>
                      <div className="relative aspect-video bg-black group cursor-pointer" onClick={() => onSelectVideo(video)}>
                        <img src={video.thumbnailUrl || video.thumbnail_url} alt={video.title} className="w-full h-full object-cover" />
                        <div className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                          <Play size={28} className="text-white" />
                        </div>
                        <div className="absolute bottom-2 right-2 px-2 py-0.5 rounded bg-black/80 text-[10px] text-white font-mono">
                          {formatDuration(video.durationMinutes || video.duration_minutes || 0)}
                        </div>
                      </div>
                      <div className="p-4 space-y-2">
                        <div className="flex items-center justify-between text-xs">
                          <span className="font-semibold text-[#0F172A]">{video.creatorName || video.creator_name}</span>
                          <span
                            className={`px-2 py-0.5 rounded-full text-[10px] font-bold font-mono ${
                              video.status === 'approved'
                                ? 'bg-emerald-50 text-emerald-700'
                                : video.status === 'rejected'
                                ? 'bg-red-50 text-red-700'
                                : 'bg-amber-50 text-amber-700'
                            }`}
                          >
                            {video.status}
                          </span>
                        </div>
                        <h4 className="text-xs font-bold text-[#0F172A] line-clamp-2">{video.title}</h4>
                      </div>
                    </div>
                    <div className="p-3 border-t border-[#F1F5F9] flex gap-2">
                      <button
                        onClick={() => handleModerate(video.id, 'approve')}
                        disabled={processingId === video.id || video.status === 'approved'}
                        className="flex-1 btn-pill-primary py-2 text-xs font-semibold flex items-center justify-center gap-1 cursor-pointer disabled:opacity-40"
                      >
                        <CheckCircle2 size={13} />
                        <span>Approve</span>
                      </button>
                      <button
                        onClick={() => {
                          const reason = window.prompt('Enter rejection reason:', 'Content guidelines violation');
                          if (reason !== null) handleModerate(video.id, 'reject', reason);
                        }}
                        disabled={processingId === video.id || video.status === 'rejected'}
                        className="flex-1 py-2 text-xs font-semibold rounded-full border border-red-200 text-red-600 bg-red-50 hover:bg-red-100 flex items-center justify-center gap-1 cursor-pointer disabled:opacity-40"
                      >
                        <XCircle size={13} />
                        <span>Reject</span>
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        );
      })()}

      {/* Tab 2: Users & Creator Roles Management (With Approvals, Blocking, Deletion) */}
      {activeTab === 'creators' && (() => {
        const filteredUsers = auditUsers.filter((u) => {
          if (userStatusFilter === 'active') return u.account_status === 'active' && u.is_active;
          if (userStatusFilter === 'pending') return u.account_status === 'pending_approval';
          if (userStatusFilter === 'suspended') return u.account_status === 'suspended' || !u.is_active;
          return true;
        });

        return (
          <div className="rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm overflow-hidden space-y-0">
            <div className="p-5 sm:p-6 border-b border-[#DCE7F6] flex flex-col md:flex-row md:items-center justify-between gap-4">
              <div>
                <h3 className="text-sm font-bold text-[#0F172A] tracking-tight">
                  User & Role Lifecycle Management
                </h3>
                <p className="text-xs text-[#64748B] mt-0.5 font-normal">
                  Approve first-time creator registrations, enforce temporary policy suspensions, and manage platform administrator privileges
                </p>
              </div>
              <div className="flex items-center gap-3">
                <button
                  onClick={loadAuditUsers}
                  disabled={isLoadingUsers}
                  className="btn-secondary-pill flex items-center gap-1.5 px-3.5 py-1.5 text-xs font-semibold text-[#64748B] hover:text-[#0F172A] cursor-pointer"
                >
                  <RefreshCw size={13} className={isLoadingUsers ? 'animate-spin' : ''} />
                  <span>Refresh Users</span>
                </button>
              </div>
            </div>

            {/* Status Filter Chips */}
            <div className="px-6 py-3 bg-[#F8FAFC] border-b border-[#DCE7F6] flex items-center gap-2">
              {[
                { id: 'all' as const, label: 'All Users', count: auditUsers.length },
                { id: 'pending' as const, label: 'Pending Review', count: pendingCreatorsCount, highlight: pendingCreatorsCount > 0 },
                { id: 'active' as const, label: 'Active', count: auditUsers.filter((u) => u.account_status === 'active').length },
                { id: 'suspended' as const, label: 'Temporarily Blocked', count: auditUsers.filter((u) => u.account_status === 'suspended' || !u.is_active).length },
              ].map((f) => (
                <button
                  key={f.id}
                  onClick={() => setUserStatusFilter(f.id)}
                  className={`px-3 py-1.5 rounded-full text-xs font-semibold transition-all cursor-pointer flex items-center gap-1.5 ${
                    userStatusFilter === f.id
                      ? 'bg-[#2563EB] text-white shadow-xs'
                      : f.highlight
                      ? 'bg-amber-100 text-amber-900 border border-amber-300'
                      : 'bg-[#FFFFFF] text-[#64748B] hover:bg-[#F1F5F9] border border-[#DCE7F6]'
                  }`}
                >
                  <span>{f.label}</span>
                  <span className={`text-[10px] font-mono px-1.5 py-0.2 rounded-full ${userStatusFilter === f.id ? 'bg-white/20' : 'bg-slate-100'}`}>
                    {f.count}
                  </span>
                </button>
              ))}
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-[#F8FAFC] text-[#64748B] border-b border-[#DCE7F6] font-mono text-[11px] uppercase tracking-wider">
                  <tr>
                    <th className="py-3.5 px-6 font-semibold">User & Channel</th>
                    <th className="py-3.5 px-6 font-semibold">Account Status</th>
                    <th className="py-3.5 px-6 font-semibold">Role</th>
                    <th className="py-3.5 px-6 font-semibold">Milestone / Quota</th>
                    <th className="py-3.5 px-6 font-semibold">KYC</th>
                    <th className="py-3.5 px-6 font-semibold text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#DCE7F6]">
                  {filteredUsers.map((c) => {
                    const isPending = c.account_status === 'pending_approval';
                    const isSuspended = c.account_status === 'suspended' || !c.is_active;

                    return (
                      <tr key={c.id} className="hover:bg-[#F0F6FF]/60 transition-colors">
                        {/* User Branding */}
                        <td className="py-4 px-6">
                          <div className="flex items-start gap-3">
                            <div className="w-10 h-10 rounded-xl bg-[#E0EDFF] border border-[#BFDBFE] overflow-hidden flex items-center justify-center font-bold text-sm text-[#2563EB] shrink-0">
                              {c.channel_logo ? (
                                <img src={c.channel_logo} alt={c.name} className="w-full h-full object-cover" />
                              ) : (
                                <span>{c.name ? c.name[0].toUpperCase() : 'U'}</span>
                              )}
                            </div>
                            <div className="min-w-0 max-w-xs">
                              <div className="font-bold text-[#0F172A] truncate">
                                {c.channel_name || `${c.name}'s Channel`}
                              </div>
                              <div className="text-[11px] text-[#64748B] truncate">{c.email}</div>
                              <span className="inline-block mt-1 px-2 py-0.5 rounded-md bg-[#F1F5F9] text-[#64748B] text-[10px] font-mono uppercase font-semibold">
                                Tier: {c.tier}
                              </span>
                            </div>
                          </div>
                        </td>

                        {/* Account Lifecycle Status */}
                        <td className="py-4 px-6">
                          {isPending ? (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-amber-50 text-amber-800 border border-amber-300 font-mono">
                              <Clock size={12} className="text-amber-600" /> Pending Review
                            </span>
                          ) : isSuspended ? (
                            <div className="space-y-0.5">
                              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-red-50 text-red-700 border border-red-200 font-mono">
                                <Ban size={12} className="text-red-600" /> Suspended
                              </span>
                              {c.suspension_reason && (
                                <p className="text-[10px] text-red-600 line-clamp-1 italic">{c.suspension_reason}</p>
                              )}
                            </div>
                          ) : (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-emerald-50 text-emerald-700 border border-emerald-200 font-mono">
                              <CheckCircle2 size={12} className="text-emerald-600" /> Active
                            </span>
                          )}
                        </td>

                        {/* Role Badge */}
                        <td className="py-4 px-6">
                          {c.role === 'admin' ? (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-bold bg-purple-50 text-purple-700 border border-purple-200 font-mono">
                              <Shield size={12} className="text-purple-600" /> Admin
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-medium bg-slate-100 text-slate-700 border border-slate-200 font-mono">
                              <UserCog size={12} className="text-slate-500" /> Creator
                            </span>
                          )}
                        </td>

                        {/* Quota & Milestone Status */}
                        <td className="py-4 px-6">
                          <div className="space-y-1 min-w-[150px]">
                            <div className="text-[11px] font-bold text-[#0F172A]">{c.milestone_status}</div>
                            <div className="text-[10px] text-[#64748B] font-mono">
                              Approved: {c.approved_videos} videos | Wallet: ₹{c.wallet_amount.toLocaleString()}
                            </div>
                          </div>
                        </td>

                        {/* KYC */}
                        <td className="py-4 px-6">
                          {c.is_kyc_verified ? (
                            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 font-mono">
                              <ShieldCheck size={12} /> Verified
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-amber-50 text-amber-700 border border-amber-200 font-mono">
                              <AlertCircle size={12} /> Unverified
                            </span>
                          )}
                        </td>

                        {/* Action Buttons */}
                        <td className="py-4 px-6 text-right space-x-1.5 whitespace-nowrap">
                          {isPending && (
                            <>
                              <button
                                onClick={() => handleApproveUser(c.id)}
                                className="px-3 py-1.5 text-xs font-semibold rounded-full bg-emerald-600 text-white hover:bg-emerald-700 transition-colors cursor-pointer shadow-xs"
                              >
                                Approve Account
                              </button>
                              <button
                                onClick={() => handleRejectUser(c.id)}
                                className="px-3 py-1.5 text-xs font-semibold rounded-full border border-red-200 bg-red-50 text-red-600 hover:bg-red-100 transition-colors cursor-pointer"
                              >
                                Reject
                              </button>
                            </>
                          )}

                          {!isPending && isSuspended && (
                            <button
                              onClick={() => handleUnblockUser(c.id)}
                              className="px-3 py-1.5 text-xs font-semibold rounded-full border border-emerald-300 bg-emerald-50 text-emerald-700 hover:bg-emerald-100 transition-colors cursor-pointer"
                            >
                              Unblock Account
                            </button>
                          )}

                          {!isPending && !isSuspended && (
                            <button
                              onClick={() => handleBlockUser(c.id)}
                              className="px-3 py-1.5 text-xs font-semibold rounded-full border border-amber-200 bg-amber-50 text-amber-700 hover:bg-amber-100 transition-colors cursor-pointer"
                            >
                              Temporary Block
                            </button>
                          )}

                          {c.role === 'admin' ? (
                            <button
                              onClick={() => handleUpdateRole(c.id, 'user')}
                              className="px-2.5 py-1.5 text-xs font-semibold rounded-full border border-purple-200 bg-purple-50 text-purple-700 hover:bg-purple-100 transition-colors cursor-pointer"
                            >
                              Revoke Admin
                            </button>
                          ) : (
                            <button
                              onClick={() => handleUpdateRole(c.id, 'admin')}
                              className="px-2.5 py-1.5 text-xs font-semibold rounded-full border border-blue-200 bg-blue-50 text-[#2563EB] hover:bg-blue-100 transition-colors cursor-pointer"
                            >
                              Make Admin
                            </button>
                          )}

                          <button
                            onClick={() => handleDeleteUser(c)}
                            title="Delete Account"
                            className="p-1.5 rounded-full text-slate-400 hover:text-red-600 hover:bg-red-50 transition-colors cursor-pointer"
                          >
                            <Trash2 size={15} />
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        );
      })()}

      {/* Tab 3: Dynamic Category Management */}
      {activeTab === 'categories' && (
        <div className="rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm overflow-hidden space-y-0">
          <div className="p-5 sm:p-6 border-b border-[#DCE7F6] flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h3 className="text-sm font-bold text-[#0F172A] tracking-tight">
                Video Categories
              </h3>
              <p className="text-xs text-[#64748B] mt-0.5 font-normal">
                Define dynamic categories available during video upload and for audience discovery
              </p>
            </div>
            <div className="flex items-center gap-3">
              <button
                onClick={loadCategories}
                disabled={isLoadingCategories}
                className="btn-secondary-pill flex items-center gap-1.5 px-3.5 py-1.5 text-xs font-semibold text-[#64748B] hover:text-[#0F172A] cursor-pointer"
              >
                <RefreshCw size={13} className={isLoadingCategories ? 'animate-spin' : ''} />
                <span>Refresh</span>
              </button>
              <button
                onClick={handleOpenCreateCategory}
                className="btn-pill-primary flex items-center gap-1.5 px-4 py-1.5 text-xs font-semibold cursor-pointer shadow-sm"
              >
                <Plus size={14} />
                <span>Add Category</span>
              </button>
            </div>
          </div>

          <div className="divide-y divide-[#DCE7F6]">
            {categories.map((cat) => (
              <div key={cat.id} className="p-4 sm:p-5 flex items-center justify-between hover:bg-[#F8FAFC]">
                <div>
                  <div className="font-bold text-sm text-[#0F172A]">{cat.name}</div>
                  <div className="text-xs text-[#64748B]">{cat.description || 'No description'}</div>
                  <span className="text-[10px] font-mono text-[#2563EB]">slug: {cat.slug}</span>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => handleDeleteCategory(cat)}
                    className="p-1.5 text-slate-400 hover:text-red-600 rounded-full hover:bg-red-50"
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Tab 4: Multi-Tier Monetization Rules (Silver, Gold, Diamond) */}
      {activeTab === 'settings' && (
        <div className="p-6 sm:p-8 rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm space-y-6">
          <div>
            <h3 className="text-sm font-bold text-[#0F172A] tracking-tight">
              Multi-Tier Monetization Engine & Milestone Rules
            </h3>
            <p className="text-xs text-[#64748B] mt-0.5">
              Set automated milestone bonuses and RPM view rates across Silver, Gold, and Diamond tiers
            </p>
          </div>

          <form onSubmit={handleSaveSettings} className="space-y-6 max-w-2xl">
            {/* Silver Tier */}
            <div className="p-5 rounded-2xl bg-slate-50 border border-slate-200 space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Award size={18} className="text-slate-500" />
                  <span className="font-bold text-sm text-[#0F172A]">Silver Tier Rules</span>
                </div>
                <span className="text-[11px] font-mono bg-white px-2 py-0.5 rounded border border-slate-200">Quota: 50 Videos (10 per bucket)</span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-[11px] font-semibold text-[#0F172A]">Milestone Payout (INR)</label>
                  <input
                    type="number"
                    value={silverMilestoneReward}
                    onChange={(e) => setSilverMilestoneReward(Number(e.target.value))}
                    className="w-full mt-1 p-2.5 rounded-xl bg-white border border-[#DCE7F6] text-xs font-mono"
                  />
                </div>
                <div>
                  <label className="text-[11px] font-semibold text-[#0F172A]">Base View Rate (INR)</label>
                  <input
                    type="number"
                    value={fixedRateSilver}
                    onChange={(e) => setFixedRateSilver(Number(e.target.value))}
                    className="w-full mt-1 p-2.5 rounded-xl bg-white border border-[#DCE7F6] text-xs font-mono"
                  />
                </div>
              </div>
            </div>

            {/* Gold Tier */}
            <div className="p-5 rounded-2xl bg-amber-50/60 border border-amber-200 space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Sparkles size={18} className="text-amber-600" />
                  <span className="font-bold text-sm text-[#0F172A]">Gold Tier Rules</span>
                </div>
                <span className="text-[11px] font-mono bg-white px-2 py-0.5 rounded border border-amber-200">Quota: 125 Videos (25 per bucket)</span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-[11px] font-semibold text-[#0F172A]">Milestone Payout (INR)</label>
                  <input
                    type="number"
                    value={goldMilestoneReward}
                    onChange={(e) => setGoldMilestoneReward(Number(e.target.value))}
                    className="w-full mt-1 p-2.5 rounded-xl bg-white border border-[#DCE7F6] text-xs font-mono"
                  />
                </div>
                <div>
                  <label className="text-[11px] font-semibold text-[#0F172A]">Boost View Rate (INR)</label>
                  <input
                    type="number"
                    value={fixedRateGold}
                    onChange={(e) => setFixedRateGold(Number(e.target.value))}
                    className="w-full mt-1 p-2.5 rounded-xl bg-white border border-[#DCE7F6] text-xs font-mono"
                  />
                </div>
              </div>
            </div>

            {/* Diamond Tier */}
            <div className="p-5 rounded-2xl bg-blue-50/60 border border-blue-200 space-y-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <ShieldCheck size={18} className="text-[#2563EB]" />
                  <span className="font-bold text-sm text-[#0F172A]">Diamond Tier Rules</span>
                </div>
                <span className="text-[11px] font-mono bg-white px-2 py-0.5 rounded border border-blue-200">Quota: 250 Videos (50 per bucket)</span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-[11px] font-semibold text-[#0F172A]">Milestone Payout (INR)</label>
                  <input
                    type="number"
                    value={diamondMilestoneReward}
                    onChange={(e) => setDiamondMilestoneReward(Number(e.target.value))}
                    className="w-full mt-1 p-2.5 rounded-xl bg-white border border-[#DCE7F6] text-xs font-mono"
                  />
                </div>
                <div>
                  <label className="text-[11px] font-semibold text-[#0F172A]">VIP View Rate (INR)</label>
                  <input
                    type="number"
                    value={fixedRateDiamond}
                    onChange={(e) => setFixedRateDiamond(Number(e.target.value))}
                    className="w-full mt-1 p-2.5 rounded-xl bg-white border border-[#DCE7F6] text-xs font-mono"
                  />
                </div>
              </div>
            </div>

            <button
              type="submit"
              className="btn-pill-primary w-full py-3 text-xs font-semibold tracking-tight shadow-md cursor-pointer"
            >
              {settingsSaved ? 'Platform Rules Saved Successfully ✓' : 'Save Multi-Tier Platform Rules'}
            </button>
          </form>
        </div>
      )}

      {/* Tab 5: Live Creator Support Chat Desk */}
      {activeTab === 'support' && (
        <div className="rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm overflow-hidden h-[600px] flex flex-col md:flex-row">
          {/* Left Column: Support Threads List */}
          <div className="w-full md:w-80 border-r border-[#DCE7F6] flex flex-col bg-[#F8FAFC]">
            <div className="p-4 border-b border-[#DCE7F6] flex items-center justify-between">
              <div className="flex items-center gap-2">
                <MessageSquare size={16} className="text-[#2563EB]" />
                <span className="font-bold text-xs text-[#0F172A]">Creator Inquiries</span>
              </div>
              <button
                onClick={loadSupportThreads}
                className="p-1 rounded text-slate-500 hover:text-slate-800"
              >
                <RefreshCw size={12} className={isLoadingThreads ? 'animate-spin' : ''} />
              </button>
            </div>

            <div className="flex-1 overflow-y-auto divide-y divide-[#DCE7F6]">
              {supportThreads.length === 0 ? (
                <div className="p-8 text-center text-xs text-[#64748B]">No support threads yet.</div>
              ) : (
                supportThreads.map((t) => {
                  const isSelected = selectedThread?.id === t.id;
                  return (
                    <div
                      key={t.id}
                      onClick={() => handleSelectThread(t)}
                      className={`p-3.5 cursor-pointer transition-colors ${
                        isSelected ? 'bg-white border-l-4 border-[#2563EB]' : 'hover:bg-white/60'
                      }`}
                    >
                      <div className="flex items-center justify-between mb-1">
                        <span className="font-bold text-xs text-[#0F172A] truncate">{t.user_name}</span>
                        {t.unread_admin_count > 0 && (
                          <span className="px-1.5 py-0.5 rounded-full text-[10px] font-bold bg-[#2563EB] text-white">
                            {t.unread_admin_count}
                          </span>
                        )}
                      </div>
                      <div className="text-[11px] text-[#64748B] line-clamp-1">{t.last_message || t.subject}</div>
                      <div className="mt-1 flex items-center justify-between text-[10px] text-slate-400 font-mono">
                        <span>{t.user_email}</span>
                        <span className={t.status === 'open' ? 'text-emerald-600 font-semibold' : 'text-slate-400'}>
                          {t.status}
                        </span>
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </div>

          {/* Right Column: Chat Transcript & Reply Window */}
          <div className="flex-1 flex flex-col bg-white">
            {selectedThread ? (
              <>
                {/* Header */}
                <div className="p-4 border-b border-[#DCE7F6] flex items-center justify-between bg-white">
                  <div>
                    <div className="font-bold text-xs text-[#0F172A]">{selectedThread.user_name}</div>
                    <div className="text-[11px] text-[#64748B]">{selectedThread.user_email} • {selectedThread.subject}</div>
                  </div>
                  <button
                    onClick={handleToggleThreadStatus}
                    className={`px-3 py-1 rounded-full text-xs font-semibold border cursor-pointer ${
                      selectedThread.status === 'open'
                        ? 'border-emerald-200 bg-emerald-50 text-emerald-700'
                        : 'border-slate-200 bg-slate-50 text-slate-600'
                    }`}
                  >
                    {selectedThread.status === 'open' ? 'Mark Resolved' : 'Reopen Thread'}
                  </button>
                </div>

                {/* Messages Body */}
                <div className="flex-1 overflow-y-auto p-4 space-y-3 bg-[#F0F6FF]/30">
                  {isLoadingMessages ? (
                    <div className="flex justify-center p-8">
                      <RefreshCw size={20} className="animate-spin text-[#2563EB]" />
                    </div>
                  ) : supportMessages.length === 0 ? (
                    <div className="text-center p-8 text-xs text-[#64748B]">No messages in this conversation.</div>
                  ) : (
                    supportMessages.map((m) => {
                      const isAdmin = m.sender_role === 'admin';
                      return (
                        <div
                          key={m.id}
                          className={`flex flex-col ${isAdmin ? 'items-end' : 'items-start'}`}
                        >
                          <div
                            className={`max-w-md p-3 rounded-2xl text-xs leading-relaxed ${
                              isAdmin
                                ? 'bg-[#2563EB] text-white rounded-br-none shadow-xs'
                                : 'bg-white border border-[#DCE7F6] text-[#0F172A] rounded-bl-none shadow-xs'
                            }`}
                          >
                            <div className="font-bold text-[10px] mb-1 opacity-80">{m.sender_name}</div>
                            <div>{m.message}</div>
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>

                {/* Reply Input Bar */}
                <form onSubmit={handleSendReply} className="p-3 border-t border-[#DCE7F6] flex items-center gap-2 bg-white">
                  <input
                    type="text"
                    value={replyText}
                    onChange={(e) => setReplyText(e.target.value)}
                    placeholder="Type support reply to creator..."
                    className="flex-1 p-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs text-[#0F172A] focus:outline-none focus:border-[#2563EB]"
                  />
                  <button
                    type="submit"
                    disabled={isSendingReply || !replyText.trim()}
                    className="btn-pill-primary px-4 py-2 text-xs font-semibold flex items-center gap-1.5 cursor-pointer disabled:opacity-50"
                  >
                    <Send size={13} />
                    <span>Send</span>
                  </button>
                </form>
              </>
            ) : (
              <div className="flex-1 flex items-center justify-center text-xs text-[#64748B]">
                Select a support thread to view messages and respond.
              </div>
            )}
          </div>
        </div>
      )}

      {/* Category Create / Edit Modal */}
      {isCategoryModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-xs">
          <div className="w-full max-w-md bg-[#FFFFFF] rounded-3xl border border-[#DCE7F6] shadow-xl p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-bold text-[#0F172A]">
                {editingCategory ? 'Edit Video Category' : 'Create Video Category'}
              </h3>
              <button onClick={() => setIsCategoryModalOpen(false)} className="p-1 rounded-full text-slate-400">
                <X size={18} />
              </button>
            </div>
            {catError && <div className="p-2.5 rounded bg-red-50 text-red-700 text-xs">{catError}</div>}
            <form onSubmit={handleSaveCategory} className="space-y-3">
              <div>
                <label className="text-xs font-semibold text-[#0F172A]">Category Name *</label>
                <input
                  type="text"
                  required
                  value={catName}
                  onChange={(e) => {
                    setCatName(e.target.value);
                    if (!editingCategory) {
                      setCatSlug(e.target.value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, ''));
                    }
                  }}
                  className="w-full mt-1 p-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs"
                />
              </div>
              <div>
                <label className="text-xs font-semibold text-[#0F172A]">Slug</label>
                <input
                  type="text"
                  value={catSlug}
                  onChange={(e) => setCatSlug(e.target.value)}
                  className="w-full mt-1 p-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs font-mono"
                />
              </div>
              <div>
                <label className="text-xs font-semibold text-[#0F172A]">Description</label>
                <textarea
                  rows={2}
                  value={catDescription}
                  onChange={(e) => setCatDescription(e.target.value)}
                  className="w-full mt-1 p-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs"
                />
              </div>
              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsCategoryModalOpen(false)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSubmittingCat}
                  className="btn-pill-primary px-5 py-2 text-xs font-semibold"
                >
                  {isSubmittingCat ? 'Saving...' : 'Save Category'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
