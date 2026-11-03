export type CreatorTier = 'silver' | 'gold' | 'diamond';
export type VideoCategory = 'promotion' | 'product' | 'business' | 'self' | 'Tech & Code' | 'Productivity' | 'Gaming' | 'Design & UI' | 'Finance & Startups';
export type VideoStatus = 'pending_review' | 'approved' | 'rejected';

export interface Category {
  id: string;
  name: string;
  slug: string;
  description: string;
  icon?: string;
  is_active: boolean;
  video_count?: number;
  created_at?: string;
  updated_at?: string;
}

export interface User {
  id: string;
  name: string;
  email: string;
  mobile?: string;
  age?: number;
  role: 'user' | 'admin' | 'creator';
  tier?: CreatorTier | string;
  is_active?: boolean;
  wallet_amount?: number;
  balance?: number;
  handle?: string;
  avatar?: string;
  channelName?: string;
  channel_name?: string;
  channel_logo?: string;
  channel_description?: string;
  silver_reward_paid?: boolean;
  silver_reward_paid_at?: string;
  gold_reward_paid?: boolean;
  gold_reward_paid_at?: string;
  diamond_reward_paid?: boolean;
  diamond_reward_paid_at?: string;
  account_status?: 'pending_approval' | 'active' | 'suspended' | 'rejected' | string;
  suspension_reason?: string;
  subscribersCount?: number;
}

export interface AdminUserAuditItem {
  id: string;
  email: string;
  mobile: string;
  name: string;
  age: number;
  role: string;
  tier: string;
  is_active: boolean;
  account_status: 'pending_approval' | 'active' | 'suspended' | 'rejected' | string;
  suspension_reason?: string;
  suspended_at?: string;
  approved_at?: string;
  approved_by?: string;
  rejection_reason?: string;
  wallet_amount: number;
  channel_name: string;
  channel_logo: string;
  channel_description: string;
  silver_reward_paid: boolean;
  silver_reward_paid_at?: string;
  gold_reward_paid?: boolean;
  gold_reward_paid_at?: string;
  diamond_reward_paid?: boolean;
  diamond_reward_paid_at?: string;
  approved_videos: number;
  quota_completed: boolean;
  gold_quota_completed?: boolean;
  diamond_quota_completed?: boolean;
  is_kyc_verified: boolean;
  milestone_status: string;
  created_at: string;
  updated_at: string;
}

export interface SupportThread {
  id: string;
  user_id: string;
  user_name: string;
  user_email: string;
  subject: string;
  status: 'open' | 'resolved';
  unread_admin_count: number;
  unread_user_count: number;
  last_message: string;
  last_message_at: string;
  created_at: string;
  updated_at: string;
}

export interface SupportMessage {
  id: string;
  thread_id: string;
  sender_id: string;
  sender_name: string;
  sender_role: 'user' | 'admin';
  message: string;
  created_at: string;
}

export interface UserKYC {
  user_id: string;
  aadhaar_number: string;
  pan_number: string;
  bank_account: string;
  ifsc_code: string;
  bank_name: string;
  account_holder: string;
  agreement_agreed: boolean;
  is_verified: boolean;
  verified_at?: string;
}

export interface AdminKYCItem {
  user_id: string;
  name: string;
  email: string;
  mobile: string;
  tier: string;
  aadhaar_number: string;
  pan_number: string;
  bank_account: string;
  ifsc_code: string;
  bank_name: string;
  account_holder: string;
  is_verified: boolean;
  verified_at?: string;
}

export interface Video {
  id: string;
  user_id?: string;
  creatorId?: string;
  creator_name?: string;
  creatorName?: string;
  creatorHandle?: string;
  creatorAvatar?: string;
  creator_tier?: CreatorTier;
  title: string;
  description: string;
  category: string;
  video_type?: 'landscape' | 'short';
  duration_minutes?: number;
  durationMinutes?: number;
  duration?: string;
  durationBucket?: string;
  video_url?: string;
  videoUrl?: string;
  hls_url?: string;
  hlsUrl?: string;
  transcode_status?: string;
  transcodeStatus?: string;
  thumbnail_url?: string;
  thumbnailUrl?: string;
  status?: VideoStatus | string;
  reject_reason?: string;
  views_count?: number;
  views?: number;
  likes_count?: number;
  likes?: number;
  shares_count?: number;
  comments_count?: number;
  commentsCount?: number;
  total_watch_mins?: number;
  total_earned?: number;
  tags?: string[];
  created_at?: string;
  createdAt?: string;
}

export interface WalletTx {
  id: string;
  amount: number;
  type: string;
  description: string;
  balance_after?: number;
  status?: string;
  created_at?: string;
  createdAt?: string;
}

export interface WalletBalance {
  userId: string;
  availableBalance: number;
  welcomeCredit: number;
  approvedEarnings: number;
  kycVerified: boolean;
  transactions: WalletTx[];
}

export interface QuotaProgress {
  userId: string;
  bucket30mCount: number;
  bucket30mTarget: number;
  bucket20mCount: number;
  bucket20mTarget: number;
  bucket10mCount: number;
  bucket10mTarget: number;
  bucket5mCount: number;
  bucket5mTarget: number;
  bucket2mCount: number;
  bucket2mTarget: number;
}

export interface DurationBucketQuota {
  key: string;
  label: string;
  min_minutes: number;
  approved_count: number;
  target_count: number;
  completed: boolean;
  rate_per_view: number;
}

export interface CreatorEligibility {
  user_id: string;
  current_tier: CreatorTier;
  is_monetized: boolean;
  total_earned: number;
  tier_cap: number;
  total_videos: number;
  buckets: DurationBucketQuota[];
  status_message: string;
  next_tier?: 'gold' | 'diamond';
  next_target?: number;
}

export interface PlatformSettings {
  payout_mode: 'fixed_per_video' | 'duration_weighted' | 'milestone_batch';
  fixed_rate_silver: number;
  fixed_rate_gold: number;
  fixed_rate_diamond: number;
  rate_30m: number;
  rate_20m: number;
  rate_10m: number;
  rate_5m: number;
  rate_2m: number;
  milestone_silver: number;
  milestone_gold: number;
  milestone_diamond: number;
  ban_ai_videos: boolean;
}

export interface ReelComment {
  id: string;
  videoId?: string;
  userId?: string;
  author?: string;
  userName?: string;
  userHandle?: string;
  avatar?: string;
  userAvatar?: string;
  text: string;
  likes?: number;
  time?: string;
  createdAt?: string;
}

export type MainNavTab = 'discover' | 'feed' | 'subscriptions' | 'library' | 'studio' | 'admin';
export type StudioSection = 'dashboard' | 'content' | 'monetization' | 'payouts';
