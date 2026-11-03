/**
 * Centralized formatting utilities for video duration and metadata.
 */

/**
 * Formats a duration in minutes (which may be a floating-point value like 2.5076388833333336)
 * into a clean MM:SS or HH:MM:SS string (e.g. "02:30").
 */
export function formatDuration(durationMinutes?: number | string, fallbackDuration?: string): string {
  // If fallback is already formatted properly without decimal points (e.g. "02:30", "14:20")
  if (
    fallbackDuration &&
    typeof fallbackDuration === 'string' &&
    fallbackDuration.includes(':') &&
    !fallbackDuration.includes('.')
  ) {
    return fallbackDuration;
  }

  const mins =
    typeof durationMinutes === 'number'
      ? durationMinutes
      : parseFloat(String(durationMinutes || 0));

  if (isNaN(mins) || mins <= 0) {
    return '00:00';
  }

  const totalSeconds = Math.round(mins * 60);
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;

  if (h > 0) {
    return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }
  return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
}
