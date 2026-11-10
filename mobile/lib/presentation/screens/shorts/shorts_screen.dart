import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/comments_sheet.dart';
import '../../widgets/auth_required_dialog.dart';

class ShortsScreen extends StatefulWidget {
  final bool isActive;
  const ShortsScreen({super.key, this.isActive = true});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final ApiService _api = ApiService();
  final PageController _pageController = PageController();

  List<VideoModel> _shorts = [];
  bool _isLoading = true;
  int _currentIndex = 0;

  // Video Controllers cache (Sliding window of max 3 controllers)
  final Map<int, VideoPlayerController> _controllers = {};

  // Global sound state
  bool _isMuted = false;

  // Single-tap Play/Pause icon animation
  bool _showPlayPauseSplash = false;
  bool _isPausedSplash = false;

  // Double-tap heart popping animation
  bool _showHeartAnim = false;
  Offset _heartPos = Offset.zero;

  // Interactive scrubber state
  bool _isScrubbing = false;
  double _scrubProgress = 0.0; // 0.0 to 1.0

  // Spinning disc animation
  late AnimationController _discAnimController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _discAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _loadShorts();
  }

  @override
  void didUpdateWidget(ShortsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      final controller = _controllers[_currentIndex];
      if (widget.isActive) {
        if (controller != null && controller.value.isInitialized) {
          controller.play();
          _discAnimController.repeat();
        }
      } else {
        controller?.pause();
        _discAnimController.stop();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _controllers[_currentIndex]?.pause();
      _discAnimController.stop();
    } else if (state == AppLifecycleState.resumed && widget.isActive) {
      _controllers[_currentIndex]?.play();
      _discAnimController.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _discAnimController.dispose();
    _pageController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  Future<void> _loadShorts() async {
    setState(() => _isLoading = true);
    final shorts = await _api.fetchShorts();
    if (mounted) {
      setState(() {
        _shorts = shorts.isNotEmpty ? shorts : _api.getHomeShortsFallback();
        _isLoading = false;
      });
      if (_shorts.isNotEmpty) {
        _initControllerForIndex(0, autoPlay: true);
        if (_shorts.length > 1) {
          _initControllerForIndex(1, autoPlay: false);
        }
      }
    }
  }

  VideoPlayerController? _getOrCreateController(int index) {
    if (index < 0 || index >= _shorts.length) return null;
    if (_controllers.containsKey(index)) return _controllers[index];

    final video = _shorts[index];
    final streamUrl = video.videoUrl.isNotEmpty ? video.videoUrl : video.hlsUrl;
    if (streamUrl.isEmpty) return null;
    final uri = Uri.parse(streamUrl);
    final controller = VideoPlayerController.networkUrl(uri);

    controller.initialize().then((_) {
      if (mounted) {
        controller.setLooping(true);
        controller.setVolume(_isMuted ? 0.0 : 1.0);
        if (index == _currentIndex && widget.isActive) {
          controller.play();
        }
        setState(() {});
      }
    }).catchError((_) {
      // Graceful error handling for invalid stream URLs
    });

    controller.addListener(() {
      if (mounted && index == _currentIndex && !_isScrubbing) {
        setState(() {});
      }
    });

    _controllers[index] = controller;
    return controller;
  }

  void _initControllerForIndex(int index, {required bool autoPlay}) {
    final controller = _getOrCreateController(index);
    if (controller != null && controller.value.isInitialized) {
      controller.setVolume(_isMuted ? 0.0 : 1.0);
      if (autoPlay) {
        controller.play();
      } else {
        controller.pause();
      }
    }
  }

  void _onPageChanged(int newIndex) {
    // Pause old video
    final oldController = _controllers[_currentIndex];
    oldController?.pause();

    setState(() {
      _currentIndex = newIndex;
      _isScrubbing = false;
    });

    // Play new video
    final currentController = _controllers[newIndex];
    if (currentController != null && currentController.value.isInitialized) {
      currentController.seekTo(Duration.zero);
      currentController.setVolume(_isMuted ? 0.0 : 1.0);
      currentController.play();
    } else {
      _initControllerForIndex(newIndex, autoPlay: true);
    }

    // Preload next
    if (newIndex + 1 < _shorts.length) {
      _initControllerForIndex(newIndex + 1, autoPlay: false);
    }
    // Preload previous
    if (newIndex - 1 >= 0) {
      _initControllerForIndex(newIndex - 1, autoPlay: false);
    }

    // Dispose far away controllers (maintain sliding window)
    final keysToRemove = _controllers.keys
        .where((idx) => idx < newIndex - 1 || idx > newIndex + 1)
        .toList();
    for (final key in keysToRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
    }

    // Record public view
    if (newIndex < _shorts.length) {
      _api.recordView(_shorts[newIndex].id);
    }
  }

  void _togglePlayPause() {
    final controller = _controllers[_currentIndex];
    if (controller == null || !controller.value.isInitialized) return;

    final isPlaying = controller.value.isPlaying;
    if (isPlaying) {
      controller.pause();
      _discAnimController.stop();
    } else {
      controller.play();
      _discAnimController.repeat();
    }

    setState(() {
      _isPausedSplash = isPlaying; // If was playing, now paused
      _showPlayPauseSplash = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showPlayPauseSplash = false);
    });
  }

  void _toggleGlobalMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    for (final c in _controllers.values) {
      c.setVolume(_isMuted ? 0.0 : 1.0);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isMuted ? 'Sound muted' : 'Sound unmuted'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.black87,
      ),
    );
  }

  Future<void> _handleLikeAction(VideoModel video, int index) async {
    final auth = AuthService.instance;
    if (auth.isGuest) {
      final loggedIn = await AuthRequiredDialog.show(
        context,
        actionName: 'like this short',
      );
      if (!loggedIn) return;
    }

    final newLiked = !video.isLiked;
    setState(() {
      _shorts[index] = video.copyWith(
        isLiked: newLiked,
        likesCount: newLiked ? video.likesCount + 1 : (video.likesCount > 0 ? video.likesCount - 1 : 0),
      );
    });

    await _api.toggleLike(
      video.id,
      unlike: !newLiked,
      token: auth.token,
    );
  }

  Future<void> _handleSubscribeAction(VideoModel video, int index) async {
    final auth = AuthService.instance;
    if (auth.isGuest) {
      final loggedIn = await AuthRequiredDialog.show(
        context,
        actionName: 'subscribe to ${video.creatorName}',
      );
      if (!loggedIn) return;
    }

    final newSubscribed = !video.isSubscribed;
    setState(() {
      _shorts[index] = video.copyWith(isSubscribed: newSubscribed);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newSubscribed ? 'Subscribed to ${video.creatorName}' : 'Unsubscribed'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onDoubleTap(TapDownDetails details, int index) {
    setState(() {
      _showHeartAnim = true;
      _heartPos = details.localPosition;
    });

    final video = _shorts[index];
    if (!video.isLiked) {
      _handleLikeAction(video, index);
    }

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeartAnim = false);
    });
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Scrubber Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  void _onScrubStart(double dx, double width) {
    final controller = _controllers[_currentIndex];
    if (controller == null || !controller.value.isInitialized) return;

    final progress = (dx / width).clamp(0.0, 1.0);
    setState(() {
      _isScrubbing = true;
      _scrubProgress = progress;
    });
  }

  void _onScrubUpdate(double dx, double width) {
    final controller = _controllers[_currentIndex];
    if (controller == null || !controller.value.isInitialized) return;

    final progress = (dx / width).clamp(0.0, 1.0);
    setState(() {
      _scrubProgress = progress;
    });
  }

  void _onScrubEnd() {
    final controller = _controllers[_currentIndex];
    if (controller != null && controller.value.isInitialized) {
      final target = controller.value.duration * _scrubProgress;
      controller.seekTo(target);
    }
    setState(() {
      _isScrubbing = false;
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    if (_shorts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_creation_outlined, color: Colors.white54, size: 54),
              const SizedBox(height: 14),
              const Text('No shorts available right now', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _loadShorts,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Refresh Feed', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _shorts.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (ctx, index) {
          final video = _shorts[index];
          final controller = _controllers[index];
          final isInitialized = controller != null && controller.value.isInitialized;

          return GestureDetector(
            onTap: _togglePlayPause,
            onDoubleTapDown: (details) => _onDoubleTap(details, index),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Full-Screen Native Video Player or Fallback Thumbnail
                if (isInitialized)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.size.width > 0 ? controller.value.size.width : 720,
                        height: controller.value.size.height > 0 ? controller.value.size.height : 1280,
                        child: VideoPlayer(controller),
                      ),
                    ),
                  )
                else
                  Image.network(
                    video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.black87),
                  ),

                // Buffering Indicator
                if (isInitialized && controller.value.isBuffering)
                  const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),

                // Gradient Vignette for UI readability
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black45,
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black87,
                      ],
                      stops: [0.0, 0.22, 0.55, 1.0],
                    ),
                  ),
                ),

                // 2. Top Header Overlay (Title, Sound Toggle, Search)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.bolt_rounded, color: AppColors.primary, size: 22),
                              SizedBox(width: 6),
                              Text(
                                'Shorts',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Global Sound Mute/Unmute Toggle
                              GestureDetector(
                                onTap: _toggleGlobalMute,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 0.8),
                                  ),
                                  child: Icon(
                                    _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Icon(Icons.search, color: Colors.white, size: 22),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Center Animated Play/Pause Splash Indicator
                if (_showPlayPauseSplash)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPausedSplash ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),

                // 4. Right-Side Vertical Action Column
                Positioned(
                  right: 12,
                  bottom: 34,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Like Action
                      _buildFloatingAction(
                        icon: video.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        iconColor: video.isLiked ? AppColors.rose : Colors.white,
                        label: video.likesCount > 999
                            ? '${(video.likesCount / 1000).toStringAsFixed(1)}K'
                            : '${video.likesCount}',
                        onTap: () => _handleLikeAction(video, index),
                      ),
                      const SizedBox(height: 18),

                      // Comments Action
                      _buildFloatingAction(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '${video.commentsCount}',
                        onTap: () => CommentsSheet.show(context, video.id),
                      ),
                      const SizedBox(height: 18),

                      // Share Action
                      _buildFloatingAction(
                        icon: Icons.share_rounded,
                        label: 'Share',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: video.videoUrl));
                          _api.shareVideo(video.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Short link copied to clipboard!'),
                              backgroundColor: AppColors.primary,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),

                      // Bookmark Action
                      _buildFloatingAction(
                        icon: video.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        iconColor: video.isSaved ? AppColors.primaryLight : Colors.white,
                        label: 'Save',
                        onTap: () {
                          setState(() {
                            _shorts[index] = video.copyWith(isSaved: !video.isSaved);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _shorts[index].isSaved ? 'Saved to library' : 'Removed from library',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 22),

                      // Spinning Vinyl Music Disc
                      AnimatedBuilder(
                        animation: _discAnimController,
                        builder: (_, child) {
                          return Transform.rotate(
                            angle: _discAnimController.value * 2 * math.pi,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            gradient: const RadialGradient(
                              colors: [Colors.black, Color(0xFF334155), Colors.black],
                            ),
                          ),
                          child: const Icon(Icons.music_note, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. Bottom Channel Overlay, Creator Badge, and Caption
                Positioned(
                  left: 16,
                  right: 80,
                  bottom: 22,
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Creator Handle & Subscribe Button
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: AppColors.secondaryBadge,
                              backgroundImage: NetworkImage(video.creatorAvatar),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '@${video.creatorHandle}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => _handleSubscribeAction(video, index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: video.isSubscribed ? Colors.white24 : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  video.isSubscribed ? 'Subscribed' : 'Subscribe',
                                  style: TextStyle(
                                    color: video.isSubscribed ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Title / Caption
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Audio Track Pill
                        Row(
                          children: [
                            const Icon(Icons.music_note, color: Colors.white70, size: 13),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Original Audio • ${video.creatorName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 6. Interactive Bottom Hairline Scrubber with Live Timestamp Tooltip
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final pos = isInitialized ? controller.value.position : Duration.zero;
                      final dur = isInitialized && controller.value.duration.inMilliseconds > 0
                          ? controller.value.duration
                          : const Duration(seconds: 1);

                      final currentFraction = _isScrubbing
                          ? _scrubProgress
                          : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);

                      final currentTimeFormatted = _isScrubbing
                          ? _formatDuration(dur * _scrubProgress)
                          : _formatDuration(pos);
                      final totalTimeFormatted = _formatDuration(dur);

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (details) => _onScrubStart(details.localPosition.dx, width),
                        onHorizontalDragUpdate: (details) => _onScrubUpdate(details.localPosition.dx, width),
                        onHorizontalDragEnd: (_) => _onScrubEnd(),
                        onTapDown: (details) => _onScrubStart(details.localPosition.dx, width),
                        onTapUp: (_) => _onScrubEnd(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Scrubber Floating Time Tooltip
                            if (_isScrubbing)
                              Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24, width: 0.8),
                                ),
                                child: Text(
                                  '$currentTimeFormatted / $totalTimeFormatted',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                            // Hairline Progress Track (3px idle, 6px scrubbing)
                            SizedBox(
                              height: 12, // Hit area
                              child: Center(
                                child: Stack(
                                  children: [
                                    Container(
                                      height: _isScrubbing ? 5 : 2.5,
                                      width: width,
                                      color: Colors.white24,
                                    ),
                                    Container(
                                      height: _isScrubbing ? 5 : 2.5,
                                      width: width * currentFraction,
                                      color: _isScrubbing ? AppColors.primaryLight : Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 7. Double-Tap Animated Popping Heart
                if (_showHeartAnim)
                  Positioned(
                    left: _heartPos.dx - 40,
                    top: _heartPos.dy - 40,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.6, end: 1.3),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) => Transform.scale(
                        scale: scale,
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.rose,
                          size: 80,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingAction({
    required IconData icon,
    Color iconColor = Colors.white,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension ApiServiceShortsExtension on ApiService {
  List<VideoModel> getHomeShortsFallback() {
    return ApiService.getMockVideos().where((v) => v.videoType == 'short').toList();
  }
}
