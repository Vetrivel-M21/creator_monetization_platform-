import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/video_card.dart';
import '../../widgets/auth_sheet.dart';
import '../video_detail/video_detail_screen.dart';
import '../support/support_screen.dart';

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
          _selectedCategory = _categories.first;
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
            // 1. YouTube-style SliverAppBar
            SliverAppBar(
              floating: true,
              pinned: false,
              snap: true,
              elevation: 0,
              backgroundColor: AppColors.surface,
              title: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ARMSS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBadge,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'STUDIO',
                      style: TextStyle(
                        fontSize: 9,
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
                  icon: const Icon(Icons.cast_rounded, color: AppColors.textPrimary, size: 22),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Searching for Google Cast & AirPlay screens...')),
                    );
                  },
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 22),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Creator notifications loaded.')),
                        );
                      },
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.rose,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                // Account Avatar Button
                Padding(
                  padding: const EdgeInsets.only(right: 12, left: 4),
                  child: GestureDetector(
                    onTap: () async {
                      if (auth.isGuest) {
                        final loggedIn = await AuthSheet.show(context);
                        if (loggedIn == true && mounted) {
                          setState(() {});
                        }
                      } else {
                        // User Profile options
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: NetworkImage(auth.currentUser!.displayAvatar),
                                  ),
                                  title: Text(auth.currentUser!.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(auth.currentUser!.email),
                                ),
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.video_library_outlined),
                                  title: const Text('Creator Studio'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    widget.onOpenUpload();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.support_agent_rounded, color: AppColors.primary),
                                  title: const Text('Creator Support Desk'),
                                  subtitle: const Text('Chat with ARMSS Admins', style: TextStyle(fontSize: 11)),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const SupportScreen()),
                                    );
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.logout_rounded, color: AppColors.rose),
                                  title: const Text('Log Out', style: TextStyle(color: AppColors.rose)),
                                  onTap: () {
                                    auth.logout();
                                    Navigator.pop(ctx);
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.primary,
                      backgroundImage: auth.currentUser != null && auth.currentUser!.channelLogo.isNotEmpty
                          ? NetworkImage(auth.currentUser!.channelLogo)
                          : null,
                      child: auth.isGuest
                          ? const Icon(Icons.person_outline, size: 16, color: Colors.white)
                          : (auth.currentUser!.channelLogo.isEmpty
                              ? Text(
                                  auth.currentUser!.displayName.isNotEmpty ? auth.currentUser!.displayName[0].toUpperCase() : 'U',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                )
                              : null),
                    ),
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
                  height: 32,
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
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) => _onCategorySelected(cat),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.scaffoldBackground,
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        showCheckmark: false,
                      );
                    },
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // 3. Mobile Video Feed Cards (Landscape Format Only)
            _isLoading
                ? const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                    ),
                  )
                : _videos.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No landscape videos found in this category',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : SliverList(
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

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
