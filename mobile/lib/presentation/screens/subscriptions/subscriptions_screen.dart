import 'package:flutter/material.dart';
import 'package:creator_monetization_app/core/theme/app_colors.dart';
import 'package:creator_monetization_app/data/models/video_model.dart';
import 'package:creator_monetization_app/data/services/api_service.dart';
import 'package:creator_monetization_app/presentation/widgets/video_card.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<VideoModel>> _videosFuture;

  // Subscribed creators with stories/activity indicators
  final List<Map<String, dynamic>> _subscribedChannels = [
    {
      'id': 'all',
      'name': 'All Channels',
      'avatar': '',
      'hasNew': false,
    },
    {
      'id': 'c1',
      'name': 'ARMSS Tech',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=120&auto=format&fit=crop&q=80',
      'hasNew': true,
      'isLive': true,
    },
    {
      'id': 'c2',
      'name': 'Tamil Vloggers',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&auto=format&fit=crop&q=80',
      'hasNew': true,
      'isLive': false,
    },
    {
      'id': 'c3',
      'name': 'Cinematic Waves',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=120&auto=format&fit=crop&q=80',
      'hasNew': true,
      'isLive': false,
    },
    {
      'id': 'c4',
      'name': 'Chennai Cooks',
      'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=120&auto=format&fit=crop&q=80',
      'hasNew': false,
      'isLive': false,
    },
    {
      'id': 'c5',
      'name': 'Soundscape India',
      'avatar': 'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=120&auto=format&fit=crop&q=80',
      'hasNew': false,
      'isLive': false,
    },
  ];

  String _selectedChannelId = 'all';

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  void _loadVideos() {
    _videosFuture = _apiService.fetchHomeVideos();
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
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _loadVideos();
          });
        },
        color: AppColors.primaryAccent,
        backgroundColor: AppColors.cardSurface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Horizontal creator stories / channel avatar strip
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
                        itemCount: _subscribedChannels.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final channel = _subscribedChannels[index];
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
                                    // Ring border for unread / live
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
                                            : hasNew
                                                ? const LinearGradient(
                                                    colors: [AppColors.primaryAccent, Color(0xFF60A5FA)],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  )
                                                : null,
                                        border: !isLive && !hasNew
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
                                                        (channel['name'] as String)[0],
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
                                    if (isLive)
                                      Positioned(
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE11D48),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                          child: const Text(
                                            'LIVE',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppColors.primaryAccent : AppColors.primaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.surfaceBorder),
                  ],
                ),
              ),
            ),

            // Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Latest from your subscriptions',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Manage',
                        style: TextStyle(
                          color: AppColors.primaryAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Video Feed from Subscriptions
            FutureBuilder<List<VideoModel>>(
              future: _videosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryAccent,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(
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
                            onPressed: () {
                              setState(() {
                                _loadVideos();
                              });
                            },
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final videos = snapshot.data ?? [];
                if (videos.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No videos from your subscriptions yet.',
                        style: TextStyle(color: AppColors.mutedText),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final video = videos[index];
                      return VideoCard(video: video);
                    },
                    childCount: videos.length,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
