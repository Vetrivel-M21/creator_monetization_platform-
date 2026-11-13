import { request } from './api';
import type { Video, AdminUserAuditItem, AdminKYCItem, PlatformSettings, Category, SupportThread, SupportMessage } from '../types';

const API_HOST = 'https://entertainment.aurapictures.online';

/** Ensures a media URL is absolute and uses HTTPS */
function absoluteMediaUrl(url: any): string {
  if (!url || typeof url !== 'string' || url.trim() === '') return '';
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url.replace(/^http:\/\//, 'https://');
  }
  // Relative path — prefix with API host
  return API_HOST + (url.startsWith('/') ? url : '/' + url);
}

/** Normalize a raw video API response into the standard Video shape */
function normalizeAdminVideo(v: any): Video {
  const hls = absoluteMediaUrl(v.hls_url || v.hlsUrl);
  const mp4 = absoluteMediaUrl(v.video_url || v.videoUrl);
  const thumb = absoluteMediaUrl(v.thumbnail_url || v.thumbnailUrl);
  return {
    ...v,
    id: v.id,
    title: v.title || '',
    hls_url: hls,
    hlsUrl: hls,
    video_url: mp4,
    videoUrl: mp4,
    thumbnail_url: thumb,
    thumbnailUrl: thumb,
    transcode_status: v.transcode_status || v.transcodeStatus || 'ready',
    transcodeStatus: v.transcode_status || v.transcodeStatus || 'ready',
    creator_name: v.creator_name || v.creatorName || 'Creator',
    creatorName: v.creator_name || v.creatorName || 'Creator',
    duration_minutes: v.duration_minutes || v.durationMinutes || 0,
    durationMinutes: v.duration_minutes || v.durationMinutes || 0,
    status: v.status || 'pending',
    views: v.views_count ?? v.views ?? 0,
    views_count: v.views_count ?? v.views ?? 0,
    likes: v.likes_count ?? v.likes ?? 0,
    likes_count: v.likes_count ?? v.likes ?? 0,
    commentsCount: v.comments_count ?? v.commentsCount ?? 0,
    comments_count: v.comments_count ?? v.commentsCount ?? 0,
  };
}

export const adminService = {
  fetchVideos: () =>
    request<any[]>('/admin/videos').then(data => Array.isArray(data) ? data.map(normalizeAdminVideo) : []),

  moderateVideo: (videoId: string, action: 'approve' | 'reject', reason?: string) =>
    request<any>(`/admin/videos/${videoId}/verify`, {
      method: 'PUT',
      body: JSON.stringify({ action, reason })
    }),

  verifyVideo: (videoId: string, action: 'approve' | 'reject', reason?: string) =>
    request<any>(`/admin/videos/${videoId}/verify`, {
      method: 'PUT',
      body: JSON.stringify({ action, reason })
    }),

  deleteVideo: (videoId: string) =>
    request<any>(`/admin/videos/${videoId}`, {
      method: 'DELETE'
    }),

  fetchUsers: () =>
    request<AdminUserAuditItem[]>('/admin/users'),

  toggleUserActive: (userId: string, isActive: boolean) =>
    request<any>(`/admin/users/${userId}/toggle-active`, {
      method: 'PUT',
      body: JSON.stringify({ is_active: isActive })
    }),

  updateUserRole: (userId: string, role: 'admin' | 'user') =>
    request<any>(`/admin/users/${userId}/role`, {
      method: 'PUT',
      body: JSON.stringify({ role })
    }),

  deleteUser: (userId: string) =>
    request<any>(`/admin/users/${userId}`, {
      method: 'DELETE'
    }),

  blockUser: (userId: string, reason: string) =>
    request<any>(`/admin/users/${userId}/block`, {
      method: 'POST',
      body: JSON.stringify({ reason })
    }),

  unblockUser: (userId: string) =>
    request<any>(`/admin/users/${userId}/unblock`, {
      method: 'POST'
    }),

  approveUser: (userId: string) =>
    request<any>(`/admin/users/${userId}/approve`, {
      method: 'POST'
    }),

  rejectUser: (userId: string, reason: string) =>
    request<any>(`/admin/users/${userId}/reject`, {
      method: 'POST',
      body: JSON.stringify({ reason })
    }),

  // Category Management
  fetchCategories: (all: boolean = true) =>
    request<Category[]>(`/categories${all ? '?all=true' : ''}`),

  createCategory: (data: { name: string; slug?: string; description?: string; icon?: string; is_active?: boolean }) =>
    request<Category>('/admin/categories', {
      method: 'POST',
      body: JSON.stringify(data)
    }),

  updateCategory: (id: string, data: { name?: string; slug?: string; description?: string; icon?: string; is_active?: boolean }) =>
    request<Category>(`/admin/categories/${id}`, {
      method: 'PUT',
      body: JSON.stringify(data)
    }),

  deleteCategory: (id: string) =>
    request<any>(`/admin/categories/${id}`, {
      method: 'DELETE'
    }),

  fetchKYCList: () =>
    request<AdminKYCItem[]>('/admin/kyc'),

  verifyKYC: (userId: string, approve: boolean) =>
    request<any>(`/admin/kyc/${userId}/verify`, {
      method: 'PUT',
      body: JSON.stringify({ approve })
    }),

  fetchSettings: () =>
    request<PlatformSettings>('/settings'),

  updateSettings: (settings: PlatformSettings) =>
    request<any>('/admin/settings', {
      method: 'PUT',
      body: JSON.stringify(settings)
    }),

  // Support Chat (Admin Desk)
  fetchSupportThreads: () =>
    request<SupportThread[]>('/admin/support/threads'),

  fetchSupportMessages: (threadId: string) =>
    request<SupportMessage[]>(`/admin/support/threads/${threadId}/messages`),

  replySupportThread: (threadId: string, message: string) =>
    request<SupportMessage>(`/admin/support/threads/${threadId}/reply`, {
      method: 'POST',
      body: JSON.stringify({ message })
    }),

  updateSupportStatus: (threadId: string, status: 'open' | 'resolved') =>
    request<any>(`/admin/support/threads/${threadId}/status`, {
      method: 'PUT',
      body: JSON.stringify({ status })
    })
};

export const supportService = {
  fetchThread: () =>
    request<{ thread: SupportThread; messages: SupportMessage[] }>('/support/thread'),

  sendMessage: (message: string) =>
    request<SupportMessage>('/support/message', {
      method: 'POST',
      body: JSON.stringify({ message })
    })
};

export const categoryService = {
  fetchCategories: (all: boolean = false) =>
    request<Category[]>(`/categories${all ? '?all=true' : ''}`)
};
