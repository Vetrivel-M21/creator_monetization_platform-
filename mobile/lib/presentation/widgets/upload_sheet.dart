import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../screens/upload/upload_video_screen.dart';

class UploadActionSheet extends StatelessWidget {
  final VoidCallback? onOpenUploadForm;

  const UploadActionSheet({super.key, this.onOpenUploadForm});

  static void show(BuildContext context, {VoidCallback? onOpenUploadForm}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UploadActionSheet(
        onOpenUploadForm: () {
          Navigator.pop(ctx);
          if (onOpenUploadForm != null) {
            onOpenUploadForm();
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadVideoScreen(initialFormat: 'landscape')),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
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
              const Text(
                'Creator Studio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 16),
              _buildOption(
                icon: Icons.video_call_outlined,
                title: 'Upload a Video (16:9 Landscape)',
                subtitle: 'Advance your duration quota toward Silver Milestone (₹2,500)',
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UploadVideoScreen(initialFormat: 'landscape'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildOption(
                icon: Icons.bolt_outlined,
                title: 'Create a Short (9:16 Reel)',
                subtitle: 'Vertical 60-second interactive reel for high audience retention',
                color: AppColors.rose,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UploadVideoScreen(initialFormat: 'short'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildOption(
                icon: Icons.sensors_outlined,
                title: 'Go Live',
                subtitle: 'Broadcast real-time stream to your channel subscribers',
                color: AppColors.amber,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Live streaming studio check passed. Ready to broadcast.'),
                      backgroundColor: AppColors.emerald,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
