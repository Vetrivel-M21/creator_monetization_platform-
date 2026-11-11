import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/video_model.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/video_card.dart';
import '../video_detail/video_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<CategoryModel> _categories = [];
  String _selectedCategorySlug = 'all';
  String _selectedFormat = 'all'; // 'all', 'landscape', 'short'

  List<VideoModel> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await _api.fetchCategories();
    if (mounted) {
      setState(() => _categories = cats);
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _hasSearched = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _executeSearch(query.trim());
    });
  }

  Future<void> _executeSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final videos = await _api.fetchVideos(
      category: _selectedCategorySlug == 'all' ? 'All' : _selectedCategorySlug,
      videoType: _selectedFormat == 'all' ? null : _selectedFormat,
      search: query,
    );

    if (mounted) {
      setState(() {
        _results = videos;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: _onSearchChanged,
            onSubmitted: _executeSearch,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search videos, tutorials, creators...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Row (Format & Categories)
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Format filters
                  _buildFormatFilterChip('all', 'All Formats'),
                  const SizedBox(width: 6),
                  _buildFormatFilterChip('landscape', '16:9 Landscape'),
                  const SizedBox(width: 6),
                  _buildFormatFilterChip('short', '9:16 Shorts'),
                  const SizedBox(width: 12),
                  Container(height: 20, width: 1, color: AppColors.surfaceBorder),
                  const SizedBox(width: 12),

                  // Category filters
                  ..._categories.map((c) {
                    final isSelected = _selectedCategorySlug == c.slug;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(c.name, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.scaffoldBackground,
                        labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: isSelected ? AppColors.primary : AppColors.surfaceBorder),
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedCategorySlug = c.slug);
                            if (_searchController.text.isNotEmpty) {
                              _executeSearch(_searchController.text.trim());
                            }
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceBorder),

          // Content Area
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                  )
                : !_hasSearched
                    ? _buildInitialPlaceholder()
                    : _results.isEmpty
                        ? _buildEmptyResults()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            itemCount: _results.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (ctx, index) {
                              final video = _results[index];
                              return VideoCard(
                                video: video,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => VideoDetailScreen(video: video),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatFilterChip(String format, String label) {
    final isSelected = _selectedFormat == format;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.scaffoldBackground,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.surfaceBorder),
      ),
      onSelected: (val) {
        if (val) {
          setState(() => _selectedFormat = format);
          if (_searchController.text.isNotEmpty) {
            _executeSearch(_searchController.text.trim());
          }
        }
      },
    );
  }

  Widget _buildInitialPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
              child: const Icon(Icons.search_rounded, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Search Creator Releases',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Search across video titles, descriptions, categories, or human creator names.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(
              'No results for "${_searchController.text}"',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try checking for spelling errors, clearing category filters, or searching for broader topics.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

