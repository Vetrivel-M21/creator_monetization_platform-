import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/comments_sheet.dart';
import '../../widgets/auth_required_dialog.dart';

class VideoDetailScreen extends StatefulWidget {
  final VideoModel video;

  const VideoDetailScreen({super.key, required this.video});

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  final ApiService _api = ApiService();
  late VideoModel _currentVideo;
  VideoPlayerController? _playerController;

  bool _isPlayerInitialized = false;
  bool _showControls = true;
  bool _isMuted = false;
  bool _isExpandedDescription = false;
  List<VideoModel> _relatedVideos = [];
  bool _isLoadingRelated = true;

  @override
  void initState() {
    super.initState();
    _currentVideo = widget.video;
    _initializePlayer();
    _loadRelatedVideos();
    _api.recordView(_currentVideo.id);
  }

  @override
  void dispose() {
    _playerController?.dispose();
    super.dispose();
  }

  void _initializePlayer() {
    final uri = Uri.parse(_currentVideo.videoUrl);
    _playerController = VideoPlayerController.networkUrl(uri)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isPlayerInitialized = true;
          });
          _playerController?.play();
        }
      }).catchError((_) {
        // Fallback gracefully if stream fails to load
      });

    _playerController?.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadRelatedVideos() async {
    final list = await _api.fetchLandscapeVideos();
    if (mounted) {
      setState(() {
        _relatedVideos = list.where((v) => v.id != _currentVideo.id).toList();
        _isLoadingRelated = false;
      });
    }
  }

  void _togglePlayPause() {
    if (_playerController == null || !_isPlayerInitialized) return;
    setState(() {
      if (_playerController!.value.isPlaying) {
        _playerController!.pause();
      } else {
        _playerController!.play();
      }
      _showControls = true;
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _playerController?.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  Future<void> _handleLike() async {
    final auth = AuthService.instance;
    if (auth.isGuest) {
      final loggedIn = await AuthRequiredDialog.show(
        context,
        actionName: 'like this video',
      );
      if (!loggedIn) return;
    }

    final newLiked = !_currentVideo.isLiked;
    setState(() {
      _currentVideo = _currentVideo.copyWith(
        isLiked: newLiked,
        likesCount: newLiked
            ? _currentVideo.likesCount + 1
            : (_currentVideo.likesCount > 0 ? _currentVideo.likesCount - 1 : 0),
      );
    });

    await _api.toggleLike(
      _currentVideo.id,
      unlike: !newLiked,
      token: auth.token,
    );
  }

  Future<void> _handleSubscribe() async {
    final auth = AuthService.instance;
    if (auth.isGuest) {
      final loggedIn = await AuthRequiredDialog.show(
        context,
        actionName: 'subscribe to ${_currentVideo.creatorName}',
      );
      if (!loggedIn) return;
    }

    final newSubscribed = !_currentVideo.isSubscribed;
    setState(() {
      _currentVideo = _currentVideo.copyWith(isSubscribed: newSubscribed);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newSubscribed
              ? 'Subscribed to ${_currentVideo.creatorName}'
              : 'Unsubscribed from ${_currentVideo.creatorName}',
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final pos = _isPlayerInitialized && _playerController != null
        ? _playerController!.value.position
        : Duration.zero;
    final dur = _isPlayerInitialized && _playerController != null && _playerController!.value.duration.inMilliseconds > 0
        ? _playerController!.value.duration
        : const Duration(seconds: 1);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          _currentVideo.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _currentVideo.videoUrl));
              _api.shareVideo(_currentVideo.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video link copied to clipboard!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Theater Player (16:9 Aspect Ratio)
          SliverToBoxAdapter(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isPlayerInitialized && _playerController != null)
                      VideoPlayer(_playerController!)
                    else
                      Image.network(
                        _currentVideo.thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.play_circle_fill, color: Colors.white38, size: 48),
                        ),
                      ),

                    // Tap Detector for Controls
                    GestureDetector(
                      onTap: () => setState(() => _showControls = !_showControls),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        color: _showControls ? Colors.black45 : Colors.transparent,
                      ),
                    ),

                    // Controls Overlay
                    if (_showControls) ...[
                      // Center Play/Pause Button
                      Center(
                        child: GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _playerController != null && _playerController!.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),

                      // Sound Mute Toggle (Top Right)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: _toggleMute,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),

                      // Bottom Progress Slider & Timestamp
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 6,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_formatDuration(pos)} / ${_formatDuration(dur)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _currentVideo.durationBucket.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                activeTrackColor: AppColors.primaryLight,
                                inactiveTrackColor: Colors.white30,
                                thumbColor: AppColors.primary,
                              ),
                              child: Slider(
                                value: (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0),
                                onChanged: (value) {
                                  final target = dur * value;
                                  _playerController?.seekTo(target);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 2. Video Title & Metadata
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentVideo.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_currentVideo.viewsCount > 1000 ? "${(_currentVideo.viewsCount / 1000).toStringAsFixed(1)}K" : _currentVideo.viewsCount} views • Clean duration: ${_currentVideo.durationFormatted} • Category: ${_currentVideo.category}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),

                  const SizedBox(height: 14),

                  // Action Buttons Row (Like, Share, Save)
                  Row(
                    children: [
                      // Like Pill
                      InkWell(
                        onTap: _handleLike,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _currentVideo.isLiked
                                ? AppColors.rose.withOpacity(0.1)
                                : AppColors.scaffoldBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _currentVideo.isLiked
                                  ? AppColors.rose.withOpacity(0.4)
                                  : AppColors.surfaceBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _currentVideo.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 16,
                                color: _currentVideo.isLiked ? AppColors.rose : AppColors.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_currentVideo.likesCount}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _currentVideo.isLiked ? AppColors.rose : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Comments Pill
                      InkWell(
                        onTap: () => CommentsSheet.show(context, _currentVideo.id),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.scaffoldBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.textPrimary),
                              const SizedBox(width: 6),
                              Text(
                                '${_currentVideo.commentsCount}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Save Pill
                      InkWell(
                        onTap: () {
                          setState(() {
                            _currentVideo = _currentVideo.copyWith(isSaved: !_currentVideo.isSaved);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_currentVideo.isSaved ? 'Saved to library' : 'Removed from library'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.scaffoldBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _currentVideo.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                size: 16,
                                color: _currentVideo.isSaved ? AppColors.primary : AppColors.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Creator Channel Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.secondaryBadge,
                        backgroundImage: NetworkImage(_currentVideo.creatorAvatar),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _currentVideo.creatorName,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryBadge,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _currentVideo.creatorTier.toUpperCase(),
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '@${_currentVideo.creatorHandle} • Verified Creator',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _handleSubscribe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentVideo.isSubscribed ? AppColors.scaffoldBackground : AppColors.primary,
                          foregroundColor: _currentVideo.isSubscribed ? AppColors.textPrimary : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: _currentVideo.isSubscribed ? const BorderSide(color: AppColors.surfaceBorder) : BorderSide.none,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          _currentVideo.isSubscribed ? 'Subscribed' : 'Subscribe',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),

                  if (_currentVideo.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => setState(() => _isExpandedDescription = !_isExpandedDescription),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentVideo.description,
                              maxLines: _isExpandedDescription ? null : 2,
                              overflow: _isExpandedDescription ? TextOverflow.visible : TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isExpandedDescription ? 'Show less' : '...more',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 12),
          ),

          // 3. Comments Preview Box
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () => CommentsSheet.show(context, _currentVideo.id),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.comment_outlined, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Comments (${_currentVideo.commentsCount})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Up Next & Recommendations',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
          ),

          // 4. Up Next Recommended Videos
          if (_isLoadingRelated)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final related = _relatedVideos[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: InkWell(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => VideoDetailScreen(video: related),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 120,
                              height: 68,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(related.thumbnailUrl, fit: BoxFit.cover),
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        related.durationFormatted,
                                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  related.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  related.creatorName,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                Text(
                                  '${related.viewsCount} views',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _relatedVideos.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 30),
          ),
        ],
      ),
    );
  }
}

