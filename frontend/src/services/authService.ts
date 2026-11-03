import { request } from './api';
import type { User } from '../types';

export interface SendOTPResponse {
  status: string;
  message: string;
  email: string;
  demo_otp?: string;
}

export interface VerifyOTPResponse {
  status: string;
  is_new_user: boolean;
  email?: string;
  token?: string;
  user?: User;
  message?: string;
}

export interface AuthResponse {
  status: string;
  token: string;
  user: User;
  message?: string;
}

const STORAGE_KEY_USER = 'kinetic_user';
const STORAGE_KEY_TOKEN = 'kinetic_token';

export const authService = {
  getStoredUser: (): User | null => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY_USER);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  },

  getStoredToken: (): string | null => {
    return localStorage.getItem(STORAGE_KEY_TOKEN) || localStorage.getItem('creator_token');
  },

  setStoredAuth: (token: string, user: User) => {
    localStorage.setItem(STORAGE_KEY_TOKEN, token);
    localStorage.setItem('creator_token', token);
    localStorage.setItem(STORAGE_KEY_USER, JSON.stringify(user));
  },

  logout: () => {
    localStorage.removeItem(STORAGE_KEY_TOKEN);
    localStorage.removeItem('creator_token');
    localStorage.removeItem(STORAGE_KEY_USER);
  },

  sendOTP: (email: string) => 
    request<SendOTPResponse>('/auth/send-otp', {
      method: 'POST',
      body: JSON.stringify({ email })
    }),

  verifyOTP: async (email: string, otp: string) => {
    const res = await request<VerifyOTPResponse>('/auth/verify-otp', {
      method: 'POST',
      body: JSON.stringify({ email, otp }),
    });
    if (res.token && res.user) {
      authService.setStoredAuth(res.token, res.user);
    }
    return res;
  },

  registerWithOTP: async (name: string, email: string, password: string) => {
    const res = await request<AuthResponse>('/auth/register', {
      method: 'POST',
      body: JSON.stringify({ name, email, password })
    });
    if (res.token && res.user) {
      authService.setStoredAuth(res.token, res.user);
    }
    return res;
  },

  loginWithPassword: async (identifier: string, password: string) => {
    const res = await request<AuthResponse>('/auth/login', {
      method: 'POST',
      body: JSON.stringify({ identifier, password })
    });
    if (res.token && res.user) {
      authService.setStoredAuth(res.token, res.user);
    }
    return res;
  },

  loginWithGoogleCredential: async (payload: { credential?: string; code?: string }): Promise<AuthResponse> => {
    const res = await request<AuthResponse>('/auth/google', {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    if (res.token && res.user) {
      authService.setStoredAuth(res.token, res.user);
    }
    return res;
  },

  loginWithGoogle: async (): Promise<AuthResponse> => {
    const googleClientId =
      import.meta.env.VITE_GOOGLE_CLIENT_ID || '';

    return new Promise((resolve, reject) => {
      // Check if Google Identity Services SDK is loaded
      const google = (window as any).google;
      if (!google || !google.accounts) {
        reject(
          new Error(
            'Google Sign-In is initializing or blocked by an ad-blocker. Please refresh the page or try email login.'
          )
        );
        return;
      }

      // 1. Google OAuth2 Popup flow (initCodeClient)
      if (google.accounts.oauth2) {
        try {
          const client = google.accounts.oauth2.initCodeClient({
            client_id: googleClientId,
            scope: 'openid email profile',
            ux_mode: 'popup',
            callback: async (response: any) => {
              if (response.error) {
                reject(new Error(response.error_description || response.error || 'Google Sign-In canceled'));
                return;
              }
              try {
                const authRes = await authService.loginWithGoogleCredential({ code: response.code });
                resolve(authRes);
              } catch (err) {
                reject(err);
              }
            },
            error_callback: (nonOAuthError: any) => {
              reject(new Error(nonOAuthError?.message || 'Google authentication encountered an error'));
            },
          });
          client.requestCode();
          return;
        } catch (e: any) {
          console.warn('initCodeClient failed, attempting accounts.id fallback:', e);
        }
      }

      // 2. Google Identity Services ID Token flow (init ID client fallback)
      if (google.accounts.id) {
        google.accounts.id.initialize({
          client_id: googleClientId,
          callback: async (response: any) => {
            if (!response.credential) {
              reject(new Error('No Google credential returned'));
              return;
            }
            try {
              const authRes = await authService.loginWithGoogleCredential({ credential: response.credential });
              resolve(authRes);
            } catch (err) {
              reject(err);
            }
          },
        });
        google.accounts.id.prompt((notification: any) => {
          if (notification.isNotDisplayed() || notification.isSkippedMoment()) {
            reject(new Error('Google prompt was dismissed or unavailable. Please try again.'));
          }
        });
        return;
      }

      reject(new Error('Google Authentication is not supported in this browser environment.'));
    });
  },

  getProfile: async () => {
    return request<User>('/user/profile', { method: 'GET' });
  },

  updateProfile: async (data: { name: string; age: number; mobile: string; channel_name: string; channel_description: string }) => {
    const res = await request<{ status: string; message: string; user: User }>('/user/profile', {
      method: 'PUT',
      body: JSON.stringify(data),
    });
    if (res.user) {
      const token = authService.getStoredToken();
      if (token) {
        authService.setStoredAuth(token, res.user);
      }
    }
    return res;
  },

  uploadChannelLogo: async (file: File) => {
    const token = authService.getStoredToken();
    const formData = new FormData();
    formData.append('logo', file);

    const res = await fetch('/api/user/channel-logo', {
      method: 'POST',
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: formData,
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: 'Upload failed' }));
      throw new Error(err.error || 'Failed to upload channel logo');
    }
    return res.json() as Promise<{ status: string; logo_url: string; message: string }>;
  }
};
