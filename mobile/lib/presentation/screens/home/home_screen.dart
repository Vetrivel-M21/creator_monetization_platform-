import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/video_card.dart';
import '../../widgets/auth_sheet.dart';
import '../video_detail/video_detail_screen.dart';
import '../search/search_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenUpload;

  const HomeScreen({super.key, required this.onOpenUpload});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  List<CategoryModel> _categories = [];
  CategoryModel _selectedCategory = const CategoryModel(id: 'cat-all', name: 'All', slug: 'all');
  List<VideoModel> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final categories = await _api.fetchCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        if (!_categories.any((c) => c.slug == _selectedCategory.slug)) {
          _selectedCategory = _categories.isNotEmpty ? _categories.first : const CategoryModel(id: 'cat-all', name: 'All', slug: 'all');
        }
      });
    }
    await _loadVideos();
  }

  Future<void> _loadVideos() async {
    final list = await _api.fetchLandscapeVideos(
      category: _selectedCategory.slug == 'all' ? 'All' : _selectedCategory.slug,
    );
    if (mounted) {
      setState(() {
        _videos = list;
        _isLoading = false;
      });
    }
  }

  void _onCategorySelected(CategoryModel category) {
    if (_selectedCategory.slug == category.slug) return;
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
    });
    _loadVideos();
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.celebration_rounded, color: AppColors.primary, size: 20),
                ),
                title: const Text(
                  'Welcome to Creator Monetization Platform!',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Stream, upload, and monetize your content with CMAF adaptive bitrate delivery.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.monetization_on_rounded, color: AppColors.emerald, size: 20),
                ),
                title: const Text(
                  'Monetization Enabled',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Complete your KYC verification in Creator Studio to unlock fast withdrawals.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadInitialData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // 1. Premium App Bar
            SliverAppBar(
              floating: true,
              pinned: false,
              snap: true,
              elevation: 0,
              backgroundColor: AppColors.surface,
              title: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/images/aura_mobile_app_icon_dark_squircle.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AURA',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBadge,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ENTERTAINMENT',
                      style: TextStyle(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondaryBadgeText,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary, size: 22),
                  tooltip: 'Search Videos',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 22),
                      tooltip: 'Notifications',
                      onPressed: _showNotificationsSheet,
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                // Account Avatar Button (Reactive)
                Padding(
                  padding: const EdgeInsets.only(right: 14, left: 4),
                  child: ListenableBuilder(
                    listenable: auth,
                    builder: (context, _) {
                      return GestureDetector(
                        onTap: () async {
                          if (auth.isGuest) {
                            final loggedIn = await AuthSheet.show(context);
                            if (loggedIn == true && mounted) {
                              setState(() {});
                            }
                          } else {
                            ProfileScreen.push(context);
                          }
                        },
                        child: auth.isGuest
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.darkPill,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 15, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text('Sign In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                                  ],
                                ),
                              )
                            : CircleAvatar(
                                radius: 15,
                                backgroundColor: AppColors.primary,
                                backgroundImage: NetworkImage(auth.currentUser!.displayAvatar),
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // 2. Horizontal Scrolling Dynamic Category Chips
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 12),
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final cat = _categories[i];
                      final isSelected = cat.slug == _selectedCategory.slug;
                      return ChoiceChip(
                        label: Text(
                          cat.name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? AppColors.darkPillText : AppColors.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => _onCategorySelected(cat),
                        selectedColor: AppColors.darkPill,
                        backgroundColor: AppColors.scaffoldBackground,
                        side: BorderSide(
                          color: isSelected ? AppColors.darkPill : AppColors.surfaceBorder,
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        showCheckmark: false,
                      );
                    },
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // 3. Mobile Video Feed / Skeletons / Empty State
            if (_isLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildSkeletonVideoCard(),
                  childCount: 3,
                ),
              )
            else if (_videos.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final video = _videos[i];
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
                  childCount: _videos.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonVideoCard() {
    return Padding(
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
              child: Container(
                color: AppColors.shimmerBase,
              ),
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
    );
  }

  Widget _buildEmptyState() {
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
                Icons.video_camera_back_outlined,
                size: 30,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No videos in ${_selectedCategory.name}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try browsing another category or check back later for new creator uploads.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (_selectedCategory.slug != 'all') ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  final allCat = _categories.firstWhere(
                    (c) => c.slug == 'all',
                    orElse: () => const CategoryModel(id: 'cat-all', name: 'All', slug: 'all'),
                  );
                  _onCategorySelected(allCat);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkPill,
                  foregroundColor: AppColors.darkPillText,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: const Text('Browse All Videos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
