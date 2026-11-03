import { request } from './api';
import type { Video, AdminUserAuditItem, AdminKYCItem, PlatformSettings, Category, SupportThread, SupportMessage } from '../types';

export const adminService = {
  fetchVideos: () =>
    request<Video[]>('/admin/videos'),

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
