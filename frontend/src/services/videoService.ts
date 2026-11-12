import { request, getAuthToken } from './api';
import type { Video, ReelComment } from '../types';
import { formatDuration } from '../utils/formatters';

const FALLBACK_VIDEOS: Video[] = [];

function sanitizeMediaUrl(url: any): string {
  if (!url || typeof url !== 'string') return '';
  if (typeof window !== 'undefined' && window.location.protocol === 'https:' && url.startsWith('http://')) {
    return url.replace('http://', 'https://');
  }
  return url;
}

function normalizeVideo(v: any): Video {
  const durationMins = v.duration_minutes || (v.durationBucket === '30m' ? 30 : v.durationBucket === '20m' ? 20 : 10);
  const bucket = v.durationBucket || (durationMins >= 30 ? '30m' : durationMins >= 20 ? '20m' : durationMins >= 10 ? '10m' : durationMins >= 5 ? '5m' : '2m');
  const hls = sanitizeMediaUrl(v.hls_url || v.hlsUrl);
  const mp4 = sanitizeMediaUrl(v.video_url || v.videoUrl);
  return {
    ...v,
    duration_minutes: durationMins,
    duration: formatDuration(durationMins, v.duration),
    durationBucket: bucket,
    video_url: mp4,
    videoUrl: mp4,
    hls_url: hls,
    hlsUrl: hls,
    transcode_status: v.transcode_status || v.transcodeStatus || 'ready',
    transcodeStatus: v.transcode_status || v.transcodeStatus || 'ready',
    thumbnail_url: v.thumbnail_url || v.thumbnailUrl,
    thumbnailUrl: v.thumbnail_url || v.thumbnailUrl,
    creator_name: v.creator_name || v.creatorName || 'ARMSS Creator',
    creatorName: v.creator_name || v.creatorName || 'ARMSS Creator',
    creatorHandle: v.creatorHandle || v.creator_name?.toLowerCase().replace(/\s+/g, '_') || 'creator',
    creatorAvatar: v.creatorAvatar || `https://api.dicebear.com/7.x/bottts/svg?seed=${v.creator_name || v.id}`,
    views: v.views_count ?? v.views ?? 1200,
    views_count: v.views_count ?? v.views ?? 1200,
    likes: v.likes_count ?? v.likes ?? 84,
    likes_count: v.likes_count ?? v.likes ?? 84,
    shares_count: v.shares_count ?? 12,
    commentsCount: v.comments_count ?? v.commentsCount ?? 6,
    comments_count: v.comments_count ?? v.commentsCount ?? 6,
    status: v.status || 'approved',
    createdAt: v.created_at || v.createdAt || new Date().toISOString()
  };
}

export const videoService = {
  getFallbackVideos: (): Video[] => FALLBACK_VIDEOS,

  getFeed: async (): Promise<Video[]> => {
    try {
      const data = await request<any[]>('/videos?category=all');
      if (Array.isArray(data) && data.length > 0) {
        return data.map(normalizeVideo);
      }
      return FALLBACK_VIDEOS;
    } catch {
      return FALLBACK_VIDEOS;
    }
  },

  fetchVideos: (category = 'all') =>
    request<Video[]>(`/videos?category=${category}`).then(data => data.map(normalizeVideo)),

  getUserVideos: async (userId?: string): Promise<Video[]> => {
    try {
      const endpoint = userId ? `/videos?user_id=${encodeURIComponent(userId)}` : '/videos?status=all';
      const data = await request<any[]>(endpoint);
      if (Array.isArray(data)) {
        return data.map(normalizeVideo);
      }
      return [];
    } catch (e) {
      console.warn('Failed to load user videos:', e);
      return [];
    }
  },

  uploadVideoFile: async (formData: FormData): Promise<{ message: string; video: Video }> => {
    try {
      const res = await request<any>('/videos/upload', {
        method: 'POST',
        body: formData,
      });
      return {
        message: res.message,
        video: normalizeVideo(res.video),
      };
    } catch (err: unknown) {
      console.warn('[VideoService] Vite proxy upload stream failed, retrying directly via port 8085...', err);
      // Fallback directly to Go backend HTTP API with full CORS
      const token = getAuthToken();
      const headers: Record<string, string> = token ? { 'Authorization': `Bearer ${token}` } : {};
      
      const host = typeof window !== 'undefined' && window.location.hostname ? window.location.hostname : '127.0.0.1';
      const directUrl = `http://${host}:8085/api/videos/upload`;
      const directRes = await fetch(directUrl, {
        method: 'POST',
        body: formData,
        headers,
      });

      if (!directRes.ok) {
        let errMessage = `Upload rejected (${directRes.status})`;
        try {
          const errData = await directRes.json();
          if (errData.error) errMessage = errData.error;
        } catch {
          try {
            const text = await directRes.text();
            if (text) errMessage = text;
          } catch {}
        }
        throw new Error(errMessage);
      }

      const res = await directRes.json();
      return {
        message: res.message,
        video: normalizeVideo(res.video),
      };
    }
  },

  uploadVideo: async (payload: {
    title: string;
    description: string;
    videoUrl: string;
    thumbnailUrl: string;
    category: string;
    durationBucket: string;
    tags: string[];
    video_type?: 'landscape' | 'short';
  }) => {
    const mins = payload.durationBucket === '30m' ? 30 : payload.durationBucket === '20m' ? 20 : payload.durationBucket === '10m' ? 10 : payload.durationBucket === '5m' ? 5 : 2;
    return request<any>('/videos', {
      method: 'POST',
      body: JSON.stringify({
        title: payload.title,
        description: payload.description,
        category: payload.category,
        duration_minutes: mins,
        video_url: payload.videoUrl,
        thumbnail_url: payload.thumbnailUrl,
        video_type: payload.video_type || (payload.durationBucket === '2m' ? 'short' : 'landscape')
      })
    });
  },

  likeVideo: (videoId: string, unlike = false) =>
    request<{ status: string }>(`/videos/${videoId}/like`, {
      method: 'POST',
      body: JSON.stringify({ unlike })
    }),

  shareVideo: (videoId: string) =>
    request<{ status: string }>(`/videos/${videoId}/share`, {
      method: 'POST'
    }),

  getComments: async (videoId: string): Promise<ReelComment[]> => {
    try {
      const data = await request<any[]>(`/videos/${videoId}/comments`);
      return (data || []).map((c: any): ReelComment => ({
        id: c.id,
        videoId,
        author: c.user_name || 'Community Member',
        userName: c.user_name || 'Community Member',
        userHandle: c.user_handle || 'user',
        avatar: c.user_avatar || `https://api.dicebear.com/7.x/bottts/svg?seed=${c.id}`,
        text: c.content || c.text || '',
        likes: c.likes || 0,
        time: c.created_at ? new Date(c.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'Just now'
      }));
    } catch {
      return [
        {
          id: `cmt-${videoId}-1`,
          videoId,
          author: 'Priya CodeCraft',
          userName: 'Priya CodeCraft',
          userHandle: 'priya_dev',
          avatar: 'https://api.dicebear.com/7.x/bottts/svg?seed=priya_dev',
          text: 'Great human-authored breakdown! So much better than low-effort AI summaries.',
          likes: 14,
          time: '5m ago'
        }
      ];
    }
  },

  postComment: (videoId: string, text: string) =>
    request<any>(`/videos/${videoId}/comments`, {
      method: 'POST',
      body: JSON.stringify({ content: text, text })
    })
};
