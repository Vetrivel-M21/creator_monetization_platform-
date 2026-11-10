import '../../core/utils/date_formatter.dart';

class VideoModel {
  static const String serverBase = 'http://10.10.100.251:2085';

  static String resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('blob:')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '$serverBase$url';
    }
    return '$serverBase/$url';
  }

  final String id;
  final String title;
  final String description;
  final String category;
  final String videoType; // 'landscape' or 'short'
  final double durationMinutes;
  final String durationFormatted;
  final String durationBucket;
  final String videoUrl;
  final String hlsUrl;
  final String thumbnailUrl;
  final String creatorName;
  final String creatorHandle;
  final String creatorAvatar;
  final String creatorTier;
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final bool isSaved;
  final bool isSubscribed;
  final DateTime createdAt;

  VideoModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.videoType = 'landscape',
    required this.durationMinutes,
    required this.durationFormatted,
    required this.durationBucket,
    required this.videoUrl,
    required this.hlsUrl,
    required this.thumbnailUrl,
    required this.creatorName,
    required this.creatorHandle,
    required this.creatorAvatar,
    this.creatorTier = 'Silver',
    this.viewsCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isSubscribed = false,
    required this.createdAt,
  });

  bool get isShort => videoType == 'short';
  String get timeAgo => formatTimeAgo(createdAt);
  String get displayCategory => formatCategoryTitle(category);

  VideoModel copyWith({
    bool? isLiked,
    bool? isSaved,
    bool? isSubscribed,
    int? likesCount,
    int? commentsCount,
    int? viewsCount,
  }) {
    return VideoModel(
      id: id,
      title: title,
      description: description,
      category: category,
      videoType: videoType,
      durationMinutes: durationMinutes,
      durationFormatted: durationFormatted,
      durationBucket: durationBucket,
      videoUrl: videoUrl,
      hlsUrl: hlsUrl,
      thumbnailUrl: thumbnailUrl,
      creatorName: creatorName,
      creatorHandle: creatorHandle,
      creatorAvatar: creatorAvatar,
      creatorTier: creatorTier,
      viewsCount: viewsCount ?? this.viewsCount,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      createdAt: createdAt,
    );
  }

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    final mins = (json['duration_minutes'] as num?)?.toDouble() ?? 2.0;
    String bucket = '2m';
    if (mins >= 30) {
      bucket = '30m';
    } else if (mins >= 20) {
      bucket = '20m';
    } else if (mins >= 10) {
      bucket = '10m';
    } else if (mins >= 5) {
      bucket = '5m';
    }

    final totalSecs = (mins * 60).round();
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    final formatted = '$m:${s.toString().padLeft(2, '0')}';

    final rawVideoUrl = json['video_url']?.toString() ?? '';
    final rawHlsUrl = json['hls_url']?.toString() ?? '';
    final rawThumbUrl = json['thumbnail_url']?.toString() ?? '';

    final resolvedVideoUrl = resolveUrl(rawVideoUrl);
    final resolvedHlsUrl = resolveUrl(rawHlsUrl);
    final resolvedThumbUrl = rawThumbUrl.isNotEmpty
        ? resolveUrl(rawThumbUrl)
        : 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&q=80';

    String vType = (json['video_type']?.toString().toLowerCase()) ?? '';
    if (vType != 'short' && vType != 'landscape') {
      vType = mins <= 2.0 ? 'short' : 'landscape';
    }

    final cName = json['creator_name']?.toString() ?? 'Creator';

    return VideoModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Promotion & Sponsorship',
      videoType: vType,
      durationMinutes: mins,
      durationFormatted: formatted,
      durationBucket: bucket,
      videoUrl: resolvedVideoUrl,
      hlsUrl: resolvedHlsUrl,
      thumbnailUrl: resolvedThumbUrl,
      creatorName: cName,
      creatorHandle: cName.toLowerCase().replaceAll(' ', '_'),
      creatorAvatar: 'https://api.dicebear.com/7.x/bottts/svg?seed=${json['id'] ?? cName}',
      creatorTier: json['creator_tier']?.toString() ?? 'Silver',
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class CommentModel {
  final String id;
  final String videoId;
  final String author;
  final String avatar;
  final String text;
  final int likes;
  final DateTime? createdAt;
  final String timeFormatted;

  CommentModel({
    required this.id,
    required this.videoId,
    required this.author,
    required this.avatar,
    required this.text,
    this.likes = 0,
    this.createdAt,
    required this.timeFormatted,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final created = json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString())
        : null;
    return CommentModel(
      id: json['id']?.toString() ?? '',
      videoId: json['video_id']?.toString() ?? '',
      author: json['user_name']?.toString() ?? 'Community Member',
      avatar: 'https://api.dicebear.com/7.x/bottts/svg?seed=${json['id'] ?? 'user'}',
      text: json['content']?.toString() ?? '',
      likes: (json['likes'] as num?)?.toInt() ?? (json['likes_count'] as num?)?.toInt() ?? 0,
      createdAt: created,
      timeFormatted: formatTimeAgo(created),
    );
  }
}

class ShortReelModel {
  final String id;
  final String title;
  final String videoUrl;
  final String creatorName;
  final String creatorHandle;
  final String creatorAvatar;
  final int likes;
  final int commentsCount;
  final String soundTitle;
  final bool isLiked;
  final bool isSaved;
  final bool isSubscribed;

  ShortReelModel({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.creatorName,
    required this.creatorHandle,
    required this.creatorAvatar,
    required this.likes,
    required this.commentsCount,
    required this.soundTitle,
    this.isLiked = false,
    this.isSaved = false,
    this.isSubscribed = false,
  });

  ShortReelModel copyWith({
    bool? isLiked,
    bool? isSaved,
    bool? isSubscribed,
    int? likes,
    int? commentsCount,
  }) {
    return ShortReelModel(
      id: id,
      title: title,
      videoUrl: videoUrl,
      creatorName: creatorName,
      creatorHandle: creatorHandle,
      creatorAvatar: creatorAvatar,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      soundTitle: soundTitle,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }

  factory ShortReelModel.fromVideoModel(VideoModel video) {
    return ShortReelModel(
      id: video.id,
      title: video.title,
      videoUrl: video.videoUrl,
      creatorName: video.creatorName,
      creatorHandle: '@${video.creatorHandle}',
      creatorAvatar: video.creatorAvatar,
      likes: video.likesCount,
      commentsCount: video.commentsCount,
      soundTitle: 'Original Audio • ${video.creatorName}',
      isLiked: video.isLiked,
      isSaved: video.isSaved,
      isSubscribed: video.isSubscribed,
    );
  }
}
