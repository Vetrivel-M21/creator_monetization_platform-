export const API_BASE = '/api';

export function getAuthToken(): string {
  return (
    localStorage.getItem('aura_token') ||
    localStorage.getItem('kinetic_token') ||
    localStorage.getItem('creator_token') ||
    localStorage.getItem('armss_token') ||
    ''
  );
}

export function getAuthHeaders(): Record<string, string> {
  const token = getAuthToken();
  return token ? { 'Authorization': `Bearer ${token}` } : {};
}

export async function request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
  const url = `${API_BASE}${endpoint}`;
  const isFormData = options.body instanceof FormData;
  const headers: Record<string, string> = {
    ...getAuthHeaders(),
    ...(options.headers as Record<string, string> || {})
  };
  if (!isFormData && !headers['Content-Type']) {
    headers['Content-Type'] = 'application/json';
  }

  const res = await fetch(url, { ...options, headers });
  if (!res.ok) {
    let errMessage = `Request failed: ${res.status}`;
    try {
      const errData = await res.json();
      if (errData.error) errMessage = errData.error;
    } catch {}
    throw new Error(errMessage);
  }

  return res.json();
}

