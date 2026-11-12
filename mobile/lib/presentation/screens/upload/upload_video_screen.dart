import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/category_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../../widgets/auth_required_dialog.dart';

class UploadVideoScreen extends StatefulWidget {
  final String initialFormat;

  const UploadVideoScreen({super.key, this.initialFormat = 'landscape'});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final ApiService _api = ApiService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _videoPath;
  String? _videoFileName;
  int _videoSizeBytes = 0;

  String? _thumbnailPath;
  String? _thumbnailFileName;

  late String _selectedFormat; // 'landscape' or 'short'
  late String _selectedDurationBucket;
  late double _selectedDurationMinutes;

  static const List<Map<String, dynamic>> _durationBuckets = [
    {'value': '30m', 'label': '30+ Min', 'note': 'Long-form episode', 'minutes': 30.0},
    {'value': '20m', 'label': '20 - 29 Min', 'note': 'Deep-dive session', 'minutes': 20.0},
    {'value': '10m', 'label': '10 - 19 Min', 'note': 'Standard feature', 'minutes': 10.0},
    {'value': '5m', 'label': '5 - 9 Min', 'note': 'Mid-length release', 'minutes': 5.0},
    {'value': '2m', 'label': '2 - 4 Min', 'note': 'Short & quick watch', 'minutes': 2.0},
  ];

  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedFormat = widget.initialFormat;
    if (_selectedFormat == 'short') {
      _selectedDurationBucket = '2m';
      _selectedDurationMinutes = 2.0;
    } else {
      _selectedDurationBucket = '10m';
      _selectedDurationMinutes = 10.0;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final list = await _api.fetchCategories();
    if (mounted) {
      setState(() {
        _categories = list.where((c) => c.slug != 'all').toList();
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        setState(() {
          _videoPath = file.path;
          _videoFileName = file.name;
          _videoSizeBytes = file.size;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick video file: $e');
    }
  }

  Future<void> _pickThumbnail() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        setState(() {
          _thumbnailPath = file.path;
          _thumbnailFileName = file.name;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to pick thumbnail: $e');
    }
  }

  Future<void> _handleUpload() async {
    final auth = AuthService.instance;
    if (auth.isGuest) {
      final loggedIn = await AuthRequiredDialog.show(
        context,
        actionName: 'upload videos to Creator Studio',
      );
      if (!loggedIn) return;
    }

    if (_videoPath == null) {
      setState(() => _errorMessage = 'Please select a video file to upload');
      return;
    }

    final title = _titleController.text.trim();
    if (title.length < 3) {
      setState(() => _errorMessage = 'Please enter a video title (at least 3 characters)');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
      _errorMessage = null;
    });

    final success = await _api.uploadVideo(
      filePath: _videoPath!,
      thumbnailPath: _thumbnailPath,
      title: title,
      description: _descriptionController.text.trim(),
      category: _selectedCategory?.slug ?? 'promotion',
      videoType: _selectedFormat,
      durationMinutes: _selectedDurationMinutes,
      durationBucket: _selectedDurationBucket,
      token: auth.token,
      onProgress: (p) => setState(() => _uploadProgress = p),
    );

    if (mounted) {
      setState(() => _isUploading = false);
      if (success) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.emerald, size: 28),
                SizedBox(width: 10),
                Text('Upload Complete', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Text(
              'Your $_selectedFormat video has been submitted for moderation and CMAF ABR transcoding.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Back to Feed', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        setState(() => _errorMessage = 'Upload failed. Please check your network and try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Creator Studio Upload', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.roseLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.rose.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.rose, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.rose, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 1. Format Selector (Landscape 16:9 vs Short 9:16)
            const Text(
              'Select Video Format',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildFormatCard(
                    format: 'landscape',
                    title: 'Landscape',
                    aspect: '16:9 Wide',
                    description: 'Standard long-form tutorials & reviews',
                    icon: Icons.crop_16_9_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFormatCard(
                    format: 'short',
                    title: 'Vertical Short',
                    aspect: '9:16 Reel',
                    description: '60s quick tips & highlights',
                    icon: Icons.stay_current_portrait_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Target Duration Bucket (Tier Quotas)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Target Duration Bucket',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Selected: $_selectedDurationBucket',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _durationBuckets.map((bucket) {
                final isSelected = _selectedDurationBucket == bucket['value'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDurationBucket = bucket['value'] as String;
                      _selectedDurationMinutes = bucket['minutes'] as double;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 32 - 16) / 3,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              bucket['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bucket['note'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 3. Video Master File
            const Text(
              'Video Master File',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _isUploading ? null : _pickVideo,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _videoPath != null ? AppColors.primary : AppColors.surfaceBorder,
                    width: _videoPath != null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.video_file_outlined, color: AppColors.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _videoFileName ?? 'Tap to browse MP4/MOV video',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _videoPath != null ? FontWeight.w700 : FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _videoSizeBytes > 0
                                ? '${(_videoSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
                                : 'Supports up to 1GB with CMAF transcoding',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _videoPath != null ? Icons.check_circle_rounded : Icons.file_upload_outlined,
                      color: _videoPath != null ? AppColors.emerald : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Custom Thumbnail Picker
            const Text(
              'Custom Thumbnail (Optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _isUploading ? null : _pickThumbnail,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  children: [
                    if (_thumbnailPath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_thumbnailPath!),
                          width: 56,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 56,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _thumbnailFileName ?? 'Auto-generate from video or choose image',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                    const Icon(Icons.add_photo_alternate_outlined, size: 20, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 4. Video Details (Title & Description)
            const Text(
              'Video Details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Video Title (e.g. Master Flutter Architecture)',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tell viewers about your content...',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 5. Category Dropdown
            const Text(
              'Category',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<CategoryModel>(
                  value: _selectedCategory,
                  isExpanded: true,
                  hint: const Text('Select Category'),
                  items: _categories.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    );
                  }).toList(),
                  onChanged: (cat) => setState(() => _selectedCategory = cat),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 6. Upload Button & Progress
            if (_isUploading) ...[
              LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceBorder,
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Uploading master file to Creator Platform...',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _handleUpload,
                icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                label: Text(
                  _isUploading ? 'Uploading...' : 'Publish to Platform',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatCard({
    required String format,
    required String title,
    required String aspect,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedFormat == format;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFormat = format;
          if (format == 'short' && _selectedDurationBucket != '2m' && _selectedDurationBucket != '5m') {
            _selectedDurationBucket = '2m';
            _selectedDurationMinutes = 2.0;
          } else if (format == 'landscape' && _selectedDurationBucket == '2m') {
            _selectedDurationBucket = '10m';
            _selectedDurationMinutes = 10.0;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    aspect,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}

