import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/library_service.dart';
import '../../widgets/video_card.dart';
import '../video_detail/video_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  final int initialTabIndex;
  const LibraryScreen({super.key, this.initialTabIndex = 0});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LibraryService _library = LibraryService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _library.init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onVideoTap(VideoModel video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoDetailScreen(video: video),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _library,
      builder: (context, _) {
        final saved = _library.savedVideos;
        final liked = _library.likedVideos;
        final history = _library.watchHistory;

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            elevation: 0,
            title: const Row(
              children: [
                Icon(Icons.video_library_rounded, color: AppColors.primary, size: 22),
                SizedBox(width: 8),
                Text(
                  'Your Personal Library',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [
                Tab(text: 'Saved (${saved.length})'),
                Tab(text: 'Liked (${liked.length})'),
                Tab(text: 'History (${history.length})'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Saved Bookmarks
              _buildVideoList(
                videos: saved,
                icon: Icons.bookmark_border_rounded,
                title: 'No saved bookmarks yet',
                subtitle: 'Tap the bookmark icon on any tutorial or technical talk to save it to your library.',
              ),

              // Tab 2: Liked Videos
              _buildVideoList(
                videos: liked,
                icon: Icons.favorite_border_rounded,
                title: 'No liked videos yet',
                subtitle: 'Videos you like while browsing feeds or watching will be collected here.',
              ),

              // Tab 3: Watch History
              _buildHistoryTab(history),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoList({
    required List<VideoModel> videos,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    if (videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: videos.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, index) {
        return VideoCard(
          video: videos[index],
          onTap: () => _onVideoTap(videos[index]),
        );
      },
    );
  }

  Widget _buildHistoryTab(List<VideoModel> history) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history_rounded, size: 30, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text(
                'No watch history recorded',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Videos you watch on ARMSS Entertainment will automatically be recorded here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${history.length} Recently Watched',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear Watch History?'),
                      content: const Text('This will remove all videos from your watch history.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            _library.clearHistory();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Clear', style: TextStyle(color: AppColors.rose)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.textSecondary),
                label: const Text('Clear History', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.surfaceBorder),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: history.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (ctx, index) {
              return VideoCard(
                video: history[index],
                onTap: () => _onVideoTap(history[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

