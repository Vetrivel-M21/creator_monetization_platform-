import 'package:flutter/material.dart';
import 'package:creator_monetization_app/core/theme/app_colors.dart';
import 'package:creator_monetization_app/data/models/video_model.dart';
import 'package:creator_monetization_app/data/services/api_service.dart';
import 'package:creator_monetization_app/presentation/widgets/video_card.dart';
import '../video_detail/video_detail_screen.dart';

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
    return Scaffold(
      backgroundColor: AppColors.canvasBackground,
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Searching for Cast screens...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new channel notifications.')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _loadVideos();
          });
        },
        child: FutureBuilder<List<VideoModel>>(
          future: _videosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryAccent),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.mutedText),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load subscriptions',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() => _loadVideos()),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            }

            final allVideos = snapshot.data ?? [];
            final channels = _extractChannels(allVideos);
            final filteredVideos = _selectedChannelId == 'all'
                ? allVideos
                : allVideos.where((v) => v.creatorName == _selectedChannelId).toList();

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Horizontal creator channel avatar strip
                if (channels.length > 1)
                  SliverToBoxAdapter(
                    child: Container(
                      color: AppColors.cardSurface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
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
                                final hasNew = channel['hasNew'] == true;
                                final isLive = channel['isLive'] == true;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedChannelId = channel['id'] as String;
                                    });
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 58,
                                            height: 58,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: isLive
                                                  ? const LinearGradient(
                                                      colors: [Color(0xFFE11D48), Color(0xFFF97316)],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    )
                                                  : hasNew && !isAll
                                                      ? const LinearGradient(
                                                          colors: [AppColors.primaryAccent, Color(0xFF60A5FA)],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        )
                                                      : null,
                                              border: !isLive && (!hasNew || isAll)
                                                  ? Border.all(
                                                      color: isSelected
                                                          ? AppColors.primaryAccent
                                                          : AppColors.surfaceBorder,
                                                      width: isSelected ? 2.5 : 1,
                                                    )
                                                  : null,
                                            ),
                                            padding: const EdgeInsets.all(2.5),
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                color: AppColors.cardSurface,
                                                shape: BoxShape.circle,
                                              ),
                                              padding: const EdgeInsets.all(2),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(26),
                                                child: isAll
                                                    ? Container(
                                                        color: AppColors.secondaryBadgeBg,
                                                        child: const Icon(
                                                          Icons.grid_view_rounded,
                                                          color: AppColors.primaryAccent,
                                                          size: 22,
                                                        ),
                                                      )
                                                    : Image.network(
                                                        channel['avatar'] as String,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) =>
                                                            Container(
                                                          color: AppColors.secondaryBadgeBg,
                                                          child: Center(
                                                            child: Text(
                                                              (channel['name'] as String).isNotEmpty
                                                                  ? (channel['name'] as String)[0].toUpperCase()
                                                                  : 'C',
                                                              style: const TextStyle(
                                                                color: AppColors.primaryAccent,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ],
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
                                            color: isSelected
                                                ? AppColors.primaryAccent
                                                : AppColors.primaryText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Feed Section Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedChannelId == 'all'
                              ? 'Latest Releases (${filteredVideos.length})'
                              : '$_selectedChannelId Videos (${filteredVideos.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                        if (_selectedChannelId != 'all')
                          TextButton(
                            onPressed: () => setState(() => _selectedChannelId = 'all'),
                            child: const Text('Show All', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ),

                // Video Feed
                if (filteredVideos.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No videos from this creator yet.',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final video = filteredVideos[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: VideoCard(
                            video: video,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => VideoDetailScreen(video: video),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      childCount: filteredVideos.length,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
