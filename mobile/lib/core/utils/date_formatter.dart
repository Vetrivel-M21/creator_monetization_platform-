/// Utility for formatting timestamps into human-readable relative time strings
/// e.g. "Just now", "5m ago", "2h ago", "3d ago", "2w ago", "1mo ago", "1y ago"
String formatTimeAgo(DateTime? dateTime) {
  if (dateTime == null) return 'Recently';

  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.isNegative) {
    return 'Just now';
  }

  if (difference.inSeconds < 45) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    final mins = difference.inMinutes;
    return mins <= 1 ? '1m ago' : '${mins}m ago';
  } else if (difference.inHours < 24) {
    final hours = difference.inHours;
    return hours <= 1 ? '1h ago' : '${hours}h ago';
  } else if (difference.inDays < 7) {
    final days = difference.inDays;
    return days <= 1 ? 'Yesterday' : '${days}d ago';
  } else if (difference.inDays < 30) {
    final weeks = (difference.inDays / 7).floor();
    return weeks <= 1 ? '1w ago' : '${weeks}w ago';
  } else if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return months <= 1 ? '1mo ago' : '${months}mo ago';
  } else {
    final years = (difference.inDays / 365).floor();
    return years <= 1 ? '1y ago' : '${years}y ago';
  }
}

/// Formats category slugs like "promotion", "self", "product", "business"
/// into user-friendly names "Promotion & Sponsorship", "Self / Personal Brand", etc.
String formatCategoryTitle(String? slugOrName) {
  if (slugOrName == null || slugOrName.isEmpty) return 'General';
  final lower = slugOrName.trim().toLowerCase();
  switch (lower) {
    case 'all':
      return 'All Channels';
    case 'self':
      return 'Self / Personal Brand';
    case 'promotion':
      return 'Promotion & Sponsorship';
    case 'product':
      return 'Product Review';
    case 'business':
      return 'Business & MSME';
    default:
      // Title case fallback
      return slugOrName
          .split('-')
          .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
          .join(' ');
  }
}

