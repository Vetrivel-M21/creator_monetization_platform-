import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../search/search_screen.dart';
import '../video_detail/video_detail_screen.dart';
import '../../widgets/video_card.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<VideoModel>> _videosFuture;

  String _selectedChannelId = 'all';

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  void _loadVideos() {
    _videosFuture = _apiService.fetchHomeVideos();
  }

  List<Map<String, dynamic>> _extractChannels(List<VideoModel> videos) {
    final Map<String, Map<String, dynamic>> map = {};
    for (final v in videos) {
      if (v.creatorName.isNotEmpty && !map.containsKey(v.creatorName)) {
        map[v.creatorName] = {
          'id': v.creatorName,
          'name': v.creatorName,
          'avatar': v.creatorAvatar,
          'hasNew': true,
          'isLive': false,
        };
      }
    }
    return [
      {
        'id': 'all',
        'name': 'All Channels',
        'avatar': '',
        'hasNew': false,
        'isLive': false,
      },
      ...map.values,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;

    return Scaffold(
      backgroundColor: AppColors.canvasBackground,
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary, size: 22),
            tooltip: 'Search Subscriptions',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(() {
            _loadVideos();
          });
        },
        child: FutureBuilder<List<VideoModel>>(
          future: _videosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeletonList();
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 14),
                      const Text(
                        'Failed to load subscriptions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Please verify your connection and try again.',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => setState(() => _loadVideos()),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.darkPill,
                          foregroundColor: AppColors.darkPillText,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final allVideos = snapshot.data ?? [];
            final channels = _extractChannels(allVideos);
            final filteredVideos = _selectedChannelId == 'all'
                ? allVideos
                : allVideos.where((v) => v.creatorName == _selectedChannelId).toList();

            if (allVideos.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surfaceBorder, width: 1),
                        ),
                        child: const Icon(
                          Icons.subscriptions_outlined,
                          size: 30,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'No Subscriptions Yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        auth.isGuest
                            ? 'Sign in and subscribe to your favorite creators to see their latest videos here.'
                            : 'Subscribe to channels from Home and their new uploads will appear right here.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Horizontal creator channel avatar strip
                if (channels.length > 1)
                  SliverToBoxAdapter(
                    child: Container(
                      color: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(
                        height: 94,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: channels.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final channel = channels[index];
                            final isAll = channel['id'] == 'all';
                            final isSelected = _selectedChannelId == channel['id'];

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedChannelId = channel['id'] as String;
                                });
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? AppColors.darkPill : AppColors.surfaceBorder,
                                        width: isSelected ? 2.5 : 1,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(2.5),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(26),
                                      child: isAll
                                          ? Container(
                                              color: AppColors.secondaryBadge,
                                              child: const Icon(
                                                Icons.grid_view_rounded,
                                                color: AppColors.primary,
                                                size: 22,
                                              ),
                                            )
                                          : Image.network(
                                              channel['avatar'] as String,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: AppColors.secondaryBadge,
                                                child: Center(
                                                  child: Text(
                                                    (channel['name'] as String).isNotEmpty
                                                        ? (channel['name'] as String)[0].toUpperCase()
                                                        : 'C',
                                                    style: const TextStyle(
                                                      color: AppColors.primary,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: 66,
                                    child: Text(
                                      channel['name'] as String,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 8)),

                // Videos Feed
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final video = filteredVideos[index];
                      return VideoCard(
                        video: video,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoDetailScreen(video: video),
                            ),
                          );
                        },
                      );
                    },
                    childCount: filteredVideos.length,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 3,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.surfaceBorder, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(color: AppColors.shimmerBase),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.shimmerBase,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.shimmerBase,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 140,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.shimmerBase,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
