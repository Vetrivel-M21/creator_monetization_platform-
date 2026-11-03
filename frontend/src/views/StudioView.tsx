import React, { useState } from 'react';
import {
  LayoutDashboard,
  Film,
  Award,
  Upload,
  ShieldCheck,
  ArrowDownRight,
  CheckCircle2,
  Clock,
  AlertTriangle,
  ChevronRight,
  User,
  Settings,
  Mail,
  Phone,
  Calendar,
  X,
  Camera,
} from 'lucide-react';
import type { User as UserType, Video, WalletBalance, QuotaProgress, WalletTx } from '../types';
import { authService } from '../services/authService';
import { videoService } from '../services/videoService';

interface StudioViewProps {
  user: UserType;
  videos: Video[];
  wallet: WalletBalance | null;
  quota: QuotaProgress | null;
  activeSubTab?: 'dashboard' | 'content' | 'monetization' | 'payouts';
  onSubTabChange?: (tab: 'dashboard' | 'content' | 'monetization' | 'payouts') => void;
  onOpenUpload: () => void;
  onOpenKYC: () => void;
  onOpenWithdraw: () => void;
  onUserUpdate?: (updatedUser: UserType) => void;
}

export const StudioView: React.FC<StudioViewProps> = ({
  user,
  videos,
  wallet,
  quota,
  activeSubTab = 'dashboard',
  onSubTabChange,
  onOpenUpload,
  onOpenKYC,
  onOpenWithdraw,
  onUserUpdate,
}) => {
  const [currentTab, setCurrentTab] = useState<'dashboard' | 'content' | 'monetization'>(
    activeSubTab === 'payouts' ? 'monetization' : (activeSubTab as 'dashboard' | 'content' | 'monetization') || 'dashboard'
  );

  // Edit Profile / Channel Modal state
  const [isEditProfileOpen, setIsEditProfileOpen] = useState(false);
  const [editName, setEditName] = useState(user.name || '');
  const [editAge, setEditAge] = useState(user.age || 24);
  const [editMobile, setEditMobile] = useState(user.mobile || '');
  const [editChannelName, setEditChannelName] = useState(user.channel_name || user.channelName || '');
  const [editChannelDesc, setEditChannelDesc] = useState(user.channel_description || '');
  const [editLogoUrl, setEditLogoUrl] = useState(user.channel_logo || user.avatar || '');
  const [isUploadingLogo, setIsUploadingLogo] = useState(false);
  const [isSavingProfile, setIsSavingProfile] = useState(false);
  const [profileSaveMsg, setProfileSaveMsg] = useState<string | null>(null);

  const handleTabSwitch = (tab: 'dashboard' | 'content' | 'monetization') => {
    setCurrentTab(tab);
    if (onSubTabChange) onSubTabChange(tab as 'dashboard' | 'content' | 'monetization' | 'payouts');
  };

  const [channelVideos, setChannelVideos] = React.useState<Video[]>([]);
  const [_isLoadingVideos, setIsLoadingVideos] = React.useState(false);

  const loadChannelVideos = async () => {
    try {
      setIsLoadingVideos(true);
      const data = await videoService.getUserVideos(user.id);
      if (Array.isArray(data) && data.length > 0) {
        setChannelVideos(data);
      } else {
        const filtered = videos.filter((v) => v.creatorHandle === user.handle || v.creatorId === user.id || v.user_id === user.id);
        setChannelVideos(filtered);
      }
    } catch {
      const filtered = videos.filter((v) => v.creatorHandle === user.handle || v.creatorId === user.id || v.user_id === user.id);
      setChannelVideos(filtered);
    } finally {
      setIsLoadingVideos(false);
    }
  };

  React.useEffect(() => {
    loadChannelVideos();
  }, [user.id, videos]);

  const userVideos = channelVideos.length > 0
    ? channelVideos
    : videos.filter((v) => v.creatorHandle === user.handle || v.creatorId === user.id || v.user_id === user.id);
  const approvedVideos = userVideos.filter((v) => v.status === 'approved' || !v.status);
  const totalApprovedCount = approvedVideos.length;

  // Active Milestone Tier Focus
  const [selectedMilestoneTier, setSelectedMilestoneTier] = useState<'silver' | 'gold' | 'diamond'>(() => {
    if (user.gold_reward_paid) return 'diamond';
    if (user.silver_reward_paid) return 'gold';
    return 'silver';
  });

  const tierTargetPerBucket = selectedMilestoneTier === 'diamond' ? 50 : selectedMilestoneTier === 'gold' ? 25 : 10;
  const tierTotalTarget = tierTargetPerBucket * 5;
  const tierRewardAmount = selectedMilestoneTier === 'diamond' ? '₹10,000' : selectedMilestoneTier === 'gold' ? '₹5,000' : '₹2,500';

  const buckets = [
    { key: '30m', label: '30+ Min Videos', current: quota?.bucket30mCount || 0, max: tierTargetPerBucket },
    { key: '20m', label: '20-29 Min Videos', current: quota?.bucket20mCount || 0, max: tierTargetPerBucket },
    { key: '10m', label: '10-19 Min Videos', current: quota?.bucket10mCount || 0, max: tierTargetPerBucket },
    { key: '5m', label: '5-9 Min Videos', current: quota?.bucket5mCount || 0, max: tierTargetPerBucket },
    { key: '2m', label: '2-4 Min Videos', current: quota?.bucket2mCount || 0, max: tierTargetPerBucket },
  ];

  const quotaCompleted = buckets.every((b) => b.current >= b.max);

  const handleLogoFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    try {
      setIsUploadingLogo(true);
      const res = await authService.uploadChannelLogo(file);
      setEditLogoUrl(res.logo_url);
      setProfileSaveMsg('Channel logo uploaded! Save changes to apply.');
    } catch (err: any) {
      setProfileSaveMsg(err.message || 'Failed to upload logo');
    } finally {
      setIsUploadingLogo(false);
    }
  };

  const handleSaveProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      setIsSavingProfile(true);
      const res = await authService.updateProfile({
        name: editName,
        age: Number(editAge),
        mobile: editMobile,
        channel_name: editChannelName,
        channel_description: editChannelDesc,
      });

      setProfileSaveMsg('Profile and channel branding updated successfully ✓');
      if (onUserUpdate && res.user) {
        onUserUpdate(res.user);
      }
      setTimeout(() => {
        setIsEditProfileOpen(false);
        setProfileSaveMsg(null);
      }, 1200);
    } catch (err: any) {
      setProfileSaveMsg(err.message || 'Failed to update profile');
    } finally {
      setIsSavingProfile(false);
    }
  };

  return (
    <div className="flex flex-col gap-8 pb-24 max-w-7xl mx-auto animate-fade-in">
      {/* Studio Header Banner */}
      <div className="p-7 sm:p-8 md:p-9 rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-6 sm:gap-8">
        <div className="flex items-center gap-5 sm:gap-6">
          <div className="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl bg-gradient-to-tr from-blue-100 to-blue-50 border border-blue-200 flex items-center justify-center font-bold text-2xl text-[#2563EB] overflow-hidden shadow-sm shrink-0">
            {user.channel_logo || user.avatar ? (
              <img
                src={user.channel_logo || user.avatar}
                alt={user.channel_name || user.name}
                className="w-full h-full object-cover"
              />
            ) : (
              <span>{user.name ? user.name[0].toUpperCase() : 'C'}</span>
            )}
          </div>

          <div className="space-y-2">
            <div className="flex items-center gap-3 flex-wrap">
              <h1 className="text-xl sm:text-2xl md:text-3xl font-bold tracking-tight text-[#0F172A]">
                {user.channel_name || user.channelName || user.name}
              </h1>
              <span className="px-3 py-1 rounded-full bg-[#E0EDFF] border border-[#BFDBFE] text-xs font-mono font-semibold text-[#1D4ED8] uppercase tracking-wider">
                {user.tier || 'Silver'} Creator
              </span>
              <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-50 text-emerald-700 text-[11px] font-mono border border-emerald-200 font-semibold">
                Verified Channel
              </span>
            </div>

            <p className="text-xs sm:text-sm text-[#64748B] font-normal max-w-2xl leading-relaxed">
              {user.channel_description || 'ARMSS Entertainment Verified Channel • Direct Bank Settlement Enabled'}
            </p>

            <div className="flex items-center gap-4 text-xs text-[#64748B] flex-wrap pt-0.5">
              <span className="flex items-center gap-1">
                <User size={13} className="text-[#2563EB]" />
                <strong className="text-[#0F172A]">{user.name}</strong>
              </span>
              <span>•</span>
              <span className="flex items-center gap-1">
                <Calendar size={13} className="text-[#2563EB]" />
                Age: <strong className="text-[#0F172A]">{user.age || 24}</strong>
              </span>
              <span>•</span>
              <span className="flex items-center gap-1">
                <Mail size={13} className="text-[#2563EB]" />
                {user.email}
              </span>
              {user.mobile && (
                <>
                  <span>•</span>
                  <span className="flex items-center gap-1 font-mono">
                    <Phone size={13} className="text-[#2563EB]" />
                    {user.mobile}
                  </span>
                </>
              )}
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3 shrink-0 pt-2 md:pt-0">
          <button
            onClick={() => {
              setEditName(user.name || '');
              setEditAge(user.age || 24);
              setEditMobile(user.mobile || '');
              setEditChannelName(user.channel_name || user.channelName || '');
              setEditChannelDesc(user.channel_description || '');
              setEditLogoUrl(user.channel_logo || user.avatar || '');
              setIsEditProfileOpen(true);
            }}
            className="btn-secondary-pill flex items-center gap-2 px-4 py-3 text-xs sm:text-sm font-semibold text-[#64748B] hover:text-[#0F172A] cursor-pointer"
          >
            <Settings size={15} />
            <span>Channel Settings</span>
          </button>

          <button
            onClick={onOpenUpload}
            className="btn-primary-pill flex items-center gap-2.5 px-6 py-3 text-xs sm:text-sm font-bold tracking-tight shadow-md hover:scale-[1.02] active:scale-[0.98] transition-all cursor-pointer"
          >
            <Upload size={16} strokeWidth={2.4} />
            <span>Upload New Video</span>
          </button>
        </div>
      </div>

      {/* Navigation Sub-Tabs */}
      <div className="flex items-center gap-6 sm:gap-8 border-b border-[#DCE7F6] pb-px">
        {[
          { id: 'dashboard' as const, label: 'Overview', icon: LayoutDashboard },
          { id: 'content' as const, label: `Channel Content (${userVideos.length})`, icon: Film },
          { id: 'monetization' as const, label: 'Monetization & Payouts', icon: Award },
        ].map((tab) => {
          const Icon = tab.icon;
          const isActive = currentTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => handleTabSwitch(tab.id)}
              className={`flex items-center gap-2 pb-3 pt-1 text-xs sm:text-sm transition-all duration-200 cursor-pointer ${
                isActive
                  ? 'border-b-2 border-[#2563EB] pb-2 text-[#2563EB] font-bold'
                  : 'border-b-2 border-transparent text-[#64748B] hover:text-[#0F172A] font-medium'
              }`}
            >
              <Icon size={16} strokeWidth={isActive ? 2.5 : 2} />
              <span>{tab.label}</span>
            </button>
          );
        })}
      </div>

      {/* Tab 1: Overview */}
      {currentTab === 'dashboard' && (
        <div className="flex flex-col gap-8">
          {/* Milestone Status Banner */}
          <div className="p-6 sm:p-7 rounded-3xl bg-[#F0F6FF] border border-[#BFDBFE] flex flex-col md:flex-row md:items-center justify-between gap-6 shadow-sm">
            <div className="space-y-1.5">
              <div className="flex items-center gap-2">
                <span className="px-2.5 py-0.5 rounded-full bg-[#E0EDFF] text-[#1D4ED8] text-[10px] font-mono font-bold uppercase tracking-wider">
                  Pure Tier Monetization
                </span>
                {user.diamond_reward_paid ? (
                  <span className="inline-flex items-center gap-1 text-[11px] font-bold text-purple-700 bg-purple-50 px-2.5 py-0.5 rounded-full border border-purple-200">
                    <CheckCircle2 size={12} /> Diamond Apex Tier Achieved (₹10,000 Disbursed)
                  </span>
                ) : user.gold_reward_paid ? (
                  <span className="inline-flex items-center gap-1 text-[11px] font-bold text-amber-700 bg-amber-50 px-2.5 py-0.5 rounded-full border border-amber-200">
                    <Award size={12} /> Gold Disbursed (₹5,000) • Striving for Diamond (₹10,000)
                  </span>
                ) : user.silver_reward_paid ? (
                  <span className="inline-flex items-center gap-1 text-[11px] font-bold text-emerald-700 bg-emerald-50 px-2.5 py-0.5 rounded-full border border-emerald-200">
                    <CheckCircle2 size={12} /> Silver Disbursed (₹2,500) • Striving for Gold (₹5,000)
                  </span>
                ) : quotaCompleted && wallet?.kycVerified ? (
                  <span className="inline-flex items-center gap-1 text-[11px] font-bold text-blue-700 bg-blue-50 px-2.5 py-0.5 rounded-full border border-blue-200">
                    <Award size={12} /> 50/50 Quota Done & KYC Verified
                  </span>
                ) : quotaCompleted ? (
                  <span className="inline-flex items-center gap-1 text-[11px] font-bold text-amber-800 bg-amber-50 px-2.5 py-0.5 rounded-full border border-amber-200">
                    <AlertTriangle size={12} /> Quota Met! Verify Bank KYC to Claim Reward
                  </span>
                ) : (
                  <span className="text-xs text-[#64748B] font-mono">
                    Progress: {totalApprovedCount} / {tierTotalTarget} videos
                  </span>
                )}
              </div>
              <h3 className="text-base sm:text-lg font-bold text-[#0F172A] tracking-tight">
                {user.diamond_reward_paid
                  ? 'Diamond Partner: Top Platform Tier Attained'
                  : user.gold_reward_paid
                  ? 'Diamond Tier Milestone Reward: ₹10,000.00'
                  : user.silver_reward_paid
                  ? 'Gold Tier Milestone Reward: ₹5,000.00'
                  : 'Silver Tier Milestone Reward: ₹2,500.00'}
              </h3>
              <p className="text-xs sm:text-sm text-[#64748B] leading-relaxed font-normal">
                ARMSS Entertainment rewards creators strictly upon completing required approved videos in each duration bucket ({tierTargetPerBucket} per bucket) and verifying Bank KYC. Individual video uploads do not credit per-video fees.
              </p>
            </div>
            <button
              onClick={() => handleTabSwitch('monetization')}
              className="btn-secondary-pill shrink-0 flex items-center gap-2 px-6 py-3 text-xs sm:text-sm font-semibold cursor-pointer"
            >
              <span>Explore Quotas & Payouts</span>
              <ChevronRight size={15} />
            </button>
          </div>

          {/* Quick Actions */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-5 sm:gap-6">
            <div
              onClick={onOpenUpload}
              className="p-6 sm:p-7 rounded-2xl bg-[#FFFFFF] hover:bg-[#F8FAFC] border border-[#DCE7F6] hover:border-[#BFDBFE] transition-all cursor-pointer flex flex-col justify-between gap-4 group shadow-sm"
            >
              <div className="w-12 h-12 rounded-xl bg-[#E0EDFF] text-[#2563EB] flex items-center justify-center group-hover:scale-105 transition-transform">
                <Upload size={20} strokeWidth={2.4} />
              </div>
              <div className="space-y-1">
                <h4 className="text-sm font-bold text-[#0F172A]">Publish New Video</h4>
                <p className="text-xs text-[#64748B] font-normal leading-relaxed">
                  Upload an MP4 video to advance your 50-video Silver Milestone quota.
                </p>
              </div>
              <div className="text-xs font-semibold text-[#2563EB] flex items-center gap-1 pt-1">
                <span>Open Video Uploader</span>
                <ChevronRight size={13} />
              </div>
            </div>

            <div
              onClick={() => handleTabSwitch('monetization')}
              className="p-6 sm:p-7 rounded-2xl bg-[#FFFFFF] hover:bg-[#F8FAFC] border border-[#DCE7F6] hover:border-[#BFDBFE] transition-all cursor-pointer flex flex-col justify-between gap-4 group shadow-sm"
            >
              <div className="w-12 h-12 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center group-hover:scale-105 transition-transform">
                <Award size={20} strokeWidth={2.4} />
              </div>
              <div className="space-y-1">
                <h4 className="text-sm font-bold text-[#0F172A]">Silver Duration Quotas</h4>
                <p className="text-xs text-[#64748B] font-normal leading-relaxed">
                  Track your progress across 30m, 20m, 10m, 5m, and 2m length categories.
                </p>
              </div>
              <div className="text-xs font-semibold text-emerald-600 flex items-center gap-1 pt-1">
                <span>View Quota Schedules</span>
                <ChevronRight size={13} />
              </div>
            </div>

            <div
              onClick={onOpenKYC}
              className="p-6 sm:p-7 rounded-2xl bg-[#FFFFFF] hover:bg-[#F8FAFC] border border-[#DCE7F6] hover:border-[#BFDBFE] transition-all cursor-pointer flex flex-col justify-between gap-4 group shadow-sm"
            >
              <div className="w-12 h-12 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center group-hover:scale-105 transition-transform">
                <ShieldCheck size={20} strokeWidth={2.4} />
              </div>
              <div className="space-y-1">
                <h4 className="text-sm font-bold text-[#0F172A]">Direct Bank KYC</h4>
                <p className="text-xs text-[#64748B] font-normal leading-relaxed">
                  Link bank account & PAN. Required to receive the ₹2,500 milestone payout.
                </p>
              </div>
              <div className="text-xs font-semibold text-amber-700 flex items-center gap-1 pt-1">
                <span>{wallet?.kycVerified ? 'KYC Verified ✓' : 'Submit Bank KYC'}</span>
                <ChevronRight size={13} />
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Tab 2: Channel Content */}
      {currentTab === 'content' && (
        <div className="rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm overflow-hidden">
          <div className="p-5 sm:p-6 border-b border-[#DCE7F6] flex items-center justify-between">
            <div>
              <h3 className="text-sm font-bold text-[#0F172A] tracking-tight">Channel Uploads & Quota Progress</h3>
              <p className="text-xs text-[#64748B] mt-0.5 font-normal">Real-time status of all submitted videos</p>
            </div>
            <span className="text-xs text-[#64748B] font-mono">{userVideos.length} videos</span>
          </div>

          {userVideos.length === 0 ? (
            <div className="p-16 text-center space-y-3">
              <Film size={32} className="mx-auto text-slate-400" />
              <p className="text-sm font-semibold text-[#0F172A]">No videos uploaded yet</p>
              <p className="text-xs text-[#64748B] max-w-sm mx-auto">
                Upload your first video to start filling your duration buckets toward the 50-video Silver milestone.
              </p>
              <button
                onClick={onOpenUpload}
                className="btn-pill-primary inline-flex items-center gap-2 px-5 py-2.5 text-xs font-semibold mt-2 cursor-pointer"
              >
                <Upload size={14} />
                <span>Upload First Video</span>
              </button>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-[#F8FAFC] text-[#64748B] border-b border-[#DCE7F6] font-mono text-[11px] uppercase tracking-wider">
                  <tr>
                    <th className="py-3.5 px-6 font-semibold">Video</th>
                    <th className="py-3.5 px-6 font-semibold">Duration Tier</th>
                    <th className="py-3.5 px-6 font-semibold">Moderation Status</th>
                    <th className="py-3.5 px-6 font-semibold">Views</th>
                    <th className="py-3.5 px-6 font-semibold">Quota Progression</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#DCE7F6]">
                  {userVideos.map((video) => {
                    const isApproved = video.status === 'approved' || !video.status;
                    const isRejected = video.status === 'rejected';
                    return (
                      <tr key={video.id} className="hover:bg-[#F8FAFC] transition-colors">
                        <td className="py-4 px-6">
                          <div className="flex items-center gap-3.5">
                            <img
                              src={video.thumbnailUrl || video.thumbnail_url}
                              alt={video.title}
                              className="w-16 h-10 object-cover rounded-lg bg-slate-900 border border-[#DCE7F6] shrink-0"
                            />
                            <div className="min-w-0 max-w-sm">
                              <div className="font-semibold text-[#0F172A] truncate">{video.title}</div>
                              <div className="text-[11px] text-[#64748B] mt-0.5">{video.category}</div>
                            </div>
                          </div>
                        </td>
                        <td className="py-4 px-6 font-mono">
                          <span className="px-2.5 py-1 rounded-md bg-[#F1F5F9] border border-[#DCE7F6] text-[#0F172A] text-[11px]">
                            {(video.durationBucket || '10M').toUpperCase()}
                          </span>
                        </td>
                        <td className="py-4 px-6">
                          {isRejected ? (
                            <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold text-red-600 bg-red-50 px-3 py-1 rounded-full border border-red-200">
                              <AlertTriangle size={12} /> Rejected (AI Content)
                            </span>
                          ) : isApproved ? (
                            <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold text-emerald-700 bg-emerald-50 px-3 py-1 rounded-full border border-emerald-200 font-mono">
                              <CheckCircle2 size={12} /> Approved & Counted
                            </span>
                          ) : (
                            <span className="inline-flex items-center gap-1.5 text-[11px] font-semibold text-amber-700 bg-amber-50 px-3 py-1 rounded-full border border-amber-200 font-mono">
                              <Clock size={12} /> In Review
                            </span>
                          )}
                        </td>
                        <td className="py-4 px-6 text-[#64748B] font-mono">
                          {(video.views || video.views_count || 0).toLocaleString()}
                        </td>
                        <td className="py-4 px-6">
                          {isApproved ? (
                            <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full bg-emerald-50 border border-emerald-200 text-emerald-700 text-[11px] font-mono font-semibold">
                              +1 to Bucket Quota
                            </span>
                          ) : (
                            <span className="text-[11px] font-mono text-[#64748B]">
                              Pending Audit
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
      )}

      {/* Tab 3: Monetization & Payouts */}
      {currentTab === 'monetization' && (
        <div className="flex flex-col gap-8">
          {/* Balance Hero Card */}
          <div className="p-6 sm:p-8 rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div className="space-y-2">
              <div className="text-[11px] uppercase font-mono font-semibold tracking-wider text-[#64748B]">
                Available Withdrawable Balance
              </div>
              <div className="text-3xl sm:text-4xl font-extrabold font-mono tracking-tight text-[#0F172A]">
                ₹{((wallet?.availableBalance || 0) + (wallet?.welcomeCredit || 250)).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
              </div>
              <p className="text-xs text-emerald-700 flex items-center gap-1.5 font-mono">
                <CheckCircle2 size={13} />
                Includes ₹250 Welcome Credit {user.silver_reward_paid ? '+ ₹2,500 Silver' : ''}{user.gold_reward_paid ? ' + ₹5,000 Gold' : ''}{user.diamond_reward_paid ? ' + ₹10,000 Diamond' : ''}
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <button
                onClick={onOpenKYC}
                className="btn-secondary-pill flex items-center gap-2 px-4 py-2.5 text-xs font-semibold cursor-pointer"
              >
                <ShieldCheck size={14} className="text-emerald-500" />
                <span>{wallet?.kycVerified ? 'Bank KYC Verified ✓' : 'Verify Bank Account'}</span>
              </button>

              <button
                onClick={onOpenWithdraw}
                className="btn-primary-pill flex items-center gap-2 px-6 py-2.5 text-xs font-semibold shadow-md cursor-pointer"
              >
                <ArrowDownRight size={15} />
                <span>Request Payout</span>
              </button>
            </div>
          </div>

          {/* Pure Tier Partner Milestone Cards */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
            {/* Silver Partner */}
            <div
              onClick={() => setSelectedMilestoneTier('silver')}
              className={`rounded-2xl p-6 flex flex-col justify-between gap-4 shadow-sm cursor-pointer transition-all ${
                selectedMilestoneTier === 'silver'
                  ? 'border-2 border-[#2563EB] bg-[#F0F6FF]'
                  : 'border border-[#DCE7F6] bg-[#FFFFFF] hover:border-[#BFDBFE]'
              }`}
            >
              <div className="flex items-center justify-between gap-2 mb-1">
                {user.silver_reward_paid ? (
                  <span className="text-[10px] font-bold font-mono tracking-wider uppercase px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-800 border border-emerald-300">
                    Disbursed ✓
                  </span>
                ) : (
                  <span className="text-[10px] font-bold font-mono tracking-wider uppercase px-2.5 py-1 rounded-full bg-[#E0EDFF] text-[#1D4ED8] border border-[#BFDBFE]">
                    {user.gold_reward_paid ? 'Completed' : 'Active Goal'}
                  </span>
                )}
                <span className="font-mono text-xs font-bold text-[#2563EB]">Reward: ₹2,500</span>
              </div>
              <div>
                <h3 className="text-xl font-bold tracking-tight text-[#0F172A]">Silver Tier Milestone</h3>
                <p className="text-xs text-[#64748B] mt-1 font-normal">Base Partner Milestone (10 per bucket)</p>
              </div>
              <div className="pt-4 border-t border-[#DCE7F6] text-xs text-[#64748B] space-y-2">
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={13} className={user.silver_reward_paid ? 'text-emerald-600 shrink-0' : 'text-[#2563EB] shrink-0'} />
                  <span>50 Total Videos (10 in each length bucket)</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={13} className={user.silver_reward_paid ? 'text-emerald-600 shrink-0' : 'text-[#2563EB] shrink-0'} />
                  <span>Mandatory Verified Bank KYC</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={13} className={user.silver_reward_paid ? 'text-emerald-600 shrink-0' : 'text-[#2563EB] shrink-0'} />
                  <span>Lump-sum ₹2,500 credited to wallet</span>
                </div>
              </div>
            </div>

            {/* Gold Partner */}
            <div
              onClick={() => setSelectedMilestoneTier('gold')}
              className={`rounded-2xl p-6 flex flex-col justify-between gap-4 shadow-sm cursor-pointer transition-all ${
                selectedMilestoneTier === 'gold'
                  ? 'border-2 border-amber-500 bg-amber-50/50'
                  : 'border border-[#DCE7F6] bg-[#FFFFFF] hover:border-amber-300'
              }`}
            >
              <div className="flex items-center justify-between gap-2 mb-1">
                {user.gold_reward_paid ? (
                  <span className="text-[10px] font-bold font-mono tracking-wider uppercase px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-800 border border-emerald-300">
                    Disbursed ✓
                  </span>
                ) : user.silver_reward_paid ? (
                  <span className="text-[10px] font-bold font-mono tracking-wider uppercase px-2.5 py-1 rounded-full bg-amber-100 text-amber-800 border border-amber-300">
                    Active Goal
                  </span>
                ) : (
                  <span className="text-[10px] font-bold font-mono tracking-wider uppercase px-2.5 py-1 rounded-full bg-[#F1F5F9] text-[#64748B] border border-[#DCE7F6]">
                    Next Tier
                  </span>
                )}
                <span className="font-mono text-xs font-bold text-amber-700">Reward: ₹5,000</span>
              </div>
              <div>
                <h3 className="text-xl font-bold tracking-tight text-[#0F172A]">Gold Partner</h3>
                <p className="text-xs text-[#64748B] mt-1 font-normal">High-Volume Creator Tier (25 per bucket)</p>
              </div>
              <div className="pt-4 border-t border-[#DCE7F6] text-xs text-[#64748B] space-y-2">
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={13} className={user.gold_reward_paid ? 'text-emerald-600 shrink-0' : 'text-amber-600 shrink-0'} />
                  <span>125 Total Videos (25 per bucket)</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={13} className={user.gold_reward_paid ? 'text-emerald-600 shrink-0' : 'text-amber-600 shrink-0'} />
                  <span>Verified KYC Required</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={13} className={user.gold_reward_paid ? 'text-emerald-600 shrink-0' : 'text-amber-600 shrink-0'} />
                  <span>Lump-sum ₹5,000 credited to wallet</span>
                </div>
              </div>
            </div>

            {/* Diamond Partner */}
            <div
              onClick={() => setSelectedMilestoneTier('diamond')}
              className={`rounded-2xl p-6 flex flex-col justify-between gap-4 shadow-sm cursor-pointer transition-all ${
                selectedMilestoneTier === 'diamond'
                  ? 'border-2 border-purple-600 bg-purple-50/50'
                  : 'border border-[#DCE7F6] bg-[#FFFFFF] hover:border-purple-300'
              }`}
            >
              <div className="flex items-center justify-between gap-2 mb-1">
                {user.diamond_reward_paid ? (
                  <span className="text-[10px] font-bold font-mono tracking-wider uppercase px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-800 border border-emerald-300">
                    Disbursed ✓
                  </span>
                ) : user.gold_reward_paid ? (
                  <span className="text-[10px] font-bold font-mono tracking-wider uppercase px-2.5 py-1 rounded-full bg-purple-100 text-purple-800 border border-purple-300">
                    Active Goal
                  </span>
                ) : (
                  <span className="text-[10px] font-bold font-mono tracking-wider uppercase px-2.5 py-1 rounded-full bg-[#F1F5F9] text-[#64748B] border border-[#DCE7F6]">
                    Apex Tier
                  </span>
                )}
                <span className="font-mono text-xs font-bold text-purple-700">Reward: ₹10,000</span>
              </div>
              <div>
                <h3 className="text-xl font-bold tracking-tight text-[#0F172A]">Diamond Partner</h3>
                <p className="text-xs text-[#64748B] mt-1 font-normal">Apex Platform Partner (50 per bucket)</p>
              </div>
              <div className="pt-4 border-t border-[#DCE7F6] text-xs text-[#64748B] space-y-2">
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={13} className={user.diamond_reward_paid ? 'text-emerald-600 shrink-0' : 'text-purple-600 shrink-0'} />
                  <span>250 Total Videos (50 per bucket)</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={13} className={user.diamond_reward_paid ? 'text-emerald-600 shrink-0' : 'text-purple-600 shrink-0'} />
                  <span>Verified KYC Required</span>
                </div>
                <div className="flex items-center gap-2">
                  <CheckCircle2 size={13} className={user.diamond_reward_paid ? 'text-emerald-600 shrink-0' : 'text-purple-600 shrink-0'} />
                  <span>Lump-sum ₹10,000 credited to wallet</span>
                </div>
              </div>
            </div>
          </div>

          {/* Quota Progress Trackers */}
          <div className="p-6 sm:p-8 rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm flex flex-col gap-6">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div>
                <div className="flex items-center gap-2 mb-1">
                  <span className="px-2 py-0.5 rounded text-[10px] font-bold font-mono uppercase bg-blue-100 text-blue-800">
                    {selectedMilestoneTier.toUpperCase()} QUOTA
                  </span>
                  <span className="text-xs text-[#64748B]">({tierTargetPerBucket} videos per bucket)</span>
                </div>
                <h3 className="text-base font-bold tracking-tight text-[#0F172A]">
                  {selectedMilestoneTier.charAt(0).toUpperCase() + selectedMilestoneTier.slice(1)} Tier Duration Quotas
                </h3>
                <p className="text-xs text-[#64748B] mt-0.5 font-normal">
                  Upload {tierTargetPerBucket} approved videos across all 5 duration categories to claim your {tierRewardAmount} milestone reward.
                </p>
              </div>

              {/* Tier Switcher Pills */}
              <div className="flex items-center gap-1.5 p-1 bg-slate-100 rounded-full border border-slate-200">
                {(['silver', 'gold', 'diamond'] as const).map((t) => (
                  <button
                    key={t}
                    onClick={() => setSelectedMilestoneTier(t)}
                    className={`px-3 py-1 text-xs font-semibold rounded-full capitalize transition-all cursor-pointer ${
                      selectedMilestoneTier === t
                        ? 'bg-white text-[#0F172A] shadow-sm'
                        : 'text-slate-500 hover:text-slate-900'
                    }`}
                  >
                    {t} ({t === 'diamond' ? '250' : t === 'gold' ? '125' : '50'})
                  </button>
                ))}
              </div>
            </div>

            <div className="text-xs font-mono font-bold text-[#2563EB] flex items-center justify-between pt-2 border-t border-slate-100">
              <span>Overall Platform Progress:</span>
              <span>{totalApprovedCount} / {tierTotalTarget} Videos Approved</span>
            </div>

            <div className="flex flex-col gap-4">
              {buckets.map((b) => {
                const percentage = Math.min(100, Math.round((b.current / b.max) * 100));
                return (
                  <div key={b.key} className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4">
                    <span className="w-36 text-sm text-[#0F172A] shrink-0 font-medium">{b.label}</span>
                    <div className="h-2 w-full flex-1 bg-[#E2E8F0] border border-[#CBD5E1]/40 rounded-full overflow-hidden">
                      <div
                        className="bg-[#2563EB] h-full rounded-full transition-all duration-300"
                        style={{ width: `${percentage}%` }}
                      />
                    </div>
                    <span className="text-xs font-mono text-[#64748B] sm:w-28 sm:text-right shrink-0">
                      <strong className="text-[#0F172A] font-bold">{b.current}</strong> / {b.max} ({percentage}%)
                    </span>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Ledger Table */}
          <div className="rounded-3xl bg-[#FFFFFF] border border-[#DCE7F6] shadow-sm overflow-hidden">
            <div className="p-5 sm:p-6 border-b border-[#DCE7F6] flex items-center justify-between">
              <div>
                <h3 className="text-sm font-bold text-[#0F172A] tracking-tight">Ledger Transaction History</h3>
                <p className="text-xs text-[#64748B] mt-0.5 font-normal">Immutable payout audit trail</p>
              </div>
              <span className="text-xs text-[#64748B] font-mono">Direct Bank Rails</span>
            </div>

            {wallet?.transactions && wallet.transactions.length > 0 ? (
              <div className="divide-y divide-[#DCE7F6]">
                {wallet.transactions.map((tx: WalletTx) => (
                  <div key={tx.id} className="p-4 sm:p-5 flex items-center justify-between hover:bg-[#F8FAFC] transition-colors">
                    <div>
                      <div className="text-xs font-semibold text-[#0F172A]">{tx.description}</div>
                      <div className="text-[11px] text-[#64748B] font-mono mt-0.5">
                        {new Date(tx.createdAt || tx.created_at || 0).toLocaleDateString()} • Ref #{tx.id.substring(0, 8)}
                      </div>
                    </div>
                    <div className="text-right font-mono">
                      <div
                        className={`text-xs font-bold ${
                          tx.type.includes('credit') ? 'text-emerald-600' : 'text-red-600'
                        }`}
                      >
                        {tx.type.includes('credit') ? '+' : '-'}₹{tx.amount.toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                      </div>
                      <span className="text-[10px] uppercase font-semibold text-[#64748B]">
                        {tx.status || 'completed'}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="p-12 text-center text-xs text-[#64748B] font-mono">
                No withdrawal transactions yet. Once approved, payouts settle directly via bank rails.
              </div>
            )}
          </div>
        </div>
      )}

      {/* Edit Profile & Channel Modal */}
      {isEditProfileOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/40 backdrop-blur-sm animate-fade-in">
          <div className="bg-[#FFFFFF] border border-[#DCE7F6] rounded-3xl max-w-lg w-full p-6 sm:p-8 shadow-2xl space-y-6 relative">
            <button
              onClick={() => setIsEditProfileOpen(false)}
              className="absolute top-5 right-5 text-[#64748B] hover:text-[#0F172A] p-1.5 rounded-full hover:bg-slate-100 transition-colors cursor-pointer"
            >
              <X size={18} />
            </button>

            <div>
              <h2 className="text-lg font-bold text-[#0F172A] tracking-tight">
                Edit Channel Branding & Profile
              </h2>
              <p className="text-xs text-[#64748B] mt-0.5">
                Update personal details and public channel identity
              </p>
            </div>

            {profileSaveMsg && (
              <div className="p-3.5 rounded-xl bg-blue-50 border border-blue-200 text-blue-800 text-xs flex items-center gap-2">
                <CheckCircle2 size={14} className="text-[#2563EB] shrink-0" />
                <span>{profileSaveMsg}</span>
              </div>
            )}

            <form onSubmit={handleSaveProfile} className="space-y-4">
              {/* Channel Logo Upload */}
              <div className="flex items-center gap-4 p-3 rounded-2xl bg-[#F8FAFC] border border-[#DCE7F6]">
                <div className="w-16 h-16 rounded-xl bg-[#E0EDFF] border border-[#BFDBFE] overflow-hidden flex items-center justify-center text-[#2563EB] font-bold text-xl shrink-0">
                  {editLogoUrl ? (
                    <img src={editLogoUrl} alt="Logo" className="w-full h-full object-cover" />
                  ) : (
                    <span>{editName ? editName[0].toUpperCase() : 'C'}</span>
                  )}
                </div>
                <div className="flex-1 space-y-1">
                  <label className="text-xs font-semibold text-[#0F172A] block">Channel Logo</label>
                  <label className="btn-secondary-pill inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-[#2563EB] cursor-pointer">
                    <Camera size={13} />
                    <span>{isUploadingLogo ? 'Uploading...' : 'Upload Logo'}</span>
                    <input
                      type="file"
                      accept="image/*"
                      onChange={handleLogoFileChange}
                      className="hidden"
                      disabled={isUploadingLogo}
                    />
                  </label>
                  <p className="text-[10px] text-[#64748B]">JPG, PNG, or WEBP under 10MB</p>
                </div>
              </div>

              {/* Personal Details: Name, Age, Mobile */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-[#0F172A]">Full Name</label>
                  <input
                    type="text"
                    required
                    value={editName}
                    onChange={(e) => setEditName(e.target.value)}
                    className="w-full p-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs text-[#0F172A] focus:outline-none focus:border-[#2563EB]"
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-xs font-semibold text-[#0F172A]">Age</label>
                  <input
                    type="number"
                    min={13}
                    max={120}
                    required
                    value={editAge}
                    onChange={(e) => setEditAge(Number(e.target.value))}
                    className="w-full p-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs text-[#0F172A] focus:outline-none focus:border-[#2563EB]"
                  />
                </div>
              </div>

              <div className="space-y-1">
                <label className="text-xs font-semibold text-[#0F172A]">Mobile Number (10 Digits)</label>
                <input
                  type="text"
                  placeholder="9876543210"
                  value={editMobile}
                  onChange={(e) => setEditMobile(e.target.value)}
                  className="w-full p-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs text-[#0F172A] font-mono focus:outline-none focus:border-[#2563EB]"
                />
              </div>

              {/* Channel Branding: Name & Description */}
              <div className="space-y-1">
                <label className="text-xs font-semibold text-[#0F172A]">Channel Display Name</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Vetri Tech Studio"
                  value={editChannelName}
                  onChange={(e) => setEditChannelName(e.target.value)}
                  className="w-full p-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs text-[#0F172A] focus:outline-none focus:border-[#2563EB]"
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-semibold text-[#0F172A]">Channel Bio / Description</label>
                <textarea
                  rows={3}
                  placeholder="Tell viewers what your channel creates..."
                  value={editChannelDesc}
                  onChange={(e) => setEditChannelDesc(e.target.value)}
                  className="w-full p-2.5 rounded-xl bg-[#F8FAFC] border border-[#DCE7F6] text-xs text-[#0F172A] focus:outline-none focus:border-[#2563EB]"
                />
              </div>

              <div className="pt-2 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={() => setIsEditProfileOpen(false)}
                  className="px-4 py-2 text-xs font-semibold text-[#64748B] hover:text-[#0F172A] cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={isSavingProfile}
                  className="btn-pill-primary px-5 py-2.5 text-xs font-semibold cursor-pointer"
                >
                  {isSavingProfile ? 'Saving...' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
