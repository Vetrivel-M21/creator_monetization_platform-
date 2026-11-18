// TODO: Backend should generate video thumbnail frame at roughly 10% of the video length via ffmpeg transcode pipeline

const API_HOST = 'https://entertainment.aurapictures.online';

export function toAbsoluteMediaUrl(url: string | undefined | null): string {
  if (!url || url.trim() === '') return '';
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url.replace(/^http:\/\//, 'https://');
  }
  return API_HOST + (url.startsWith('/') ? url : '/' + url);
}

export function formatRelativeTime(dateString: string | undefined | null): string {
  if (!dateString) return 'recently';
  try {
    const then = new Date(dateString).getTime();
    const now = Date.now();
    const diffMs = now - then;
    if (isNaN(diffMs) || diffMs < 0) return 'just now';

    const diffMins = Math.floor(diffMs / 60000);
    if (diffMins < 1) return 'just now';
    if (diffMins < 60) return `${diffMins}m ago`;

    const diffHours = Math.floor(diffMins / 60);
    if (diffHours < 24) return `${diffHours}h ago`;

    const diffDays = Math.floor(diffHours / 24);
    if (diffDays === 1) return 'yesterday';
    if (diffDays < 30) return `${diffDays}d ago`;

    return new Date(dateString).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  } catch {
    return 'recently';
  }
}
