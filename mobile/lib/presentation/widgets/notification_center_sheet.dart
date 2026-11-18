import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/notification_store.dart';
import '../screens/earnings/earnings_screen.dart';
import '../screens/video_detail/video_detail_screen.dart';

class NotificationCenterSheet extends StatelessWidget {
  final void Function(int tabIndex)? onNavigateTab;

  const NotificationCenterSheet({super.key, this.onNavigateTab});

  static Future<void> show(BuildContext context, {void Function(int tabIndex)? onNavigateTab}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NotificationCenterSheet(onNavigateTab: onNavigateTab),
    );
  }

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM').format(dt);
  }

  void _handleNotificationTap(BuildContext context, AppNotification item) {
    NotificationStore.instance.markAsRead(item.id);
    Navigator.of(context).pop();

    final screen = item.data['screen']?.toString().toLowerCase();
    final id = item.data['id']?.toString() ?? item.data['video_id']?.toString();

    if (screen == 'earnings' || screen == 'wallet' || screen == 'payout' || screen == 'kyc') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const EarningsScreen()),
      );
    } else if (screen == 'video' && id != null && id.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VideoDetailScreen(videoId: id)),
      );
    } else if (screen == 'studio') {
      onNavigateTab?.call(4);
    }
  }

  Widget _buildTypeIcon(AppNotification item) {
    final title = item.title.toLowerCase();
    final body = item.body.toLowerCase();
    final screen = item.data['screen']?.toString().toLowerCase() ?? '';

    if (title.contains('milestone') || body.contains('milestone') || body.contains('reward')) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.military_tech_rounded, color: Colors.purple, size: 20),
      );
    }

    if (title.contains('kyc') || screen == 'kyc') {
      final isSuccess = title.contains('approved') || title.contains('verified') || body.contains('verified');
      final isReject = title.contains('reject') || body.contains('reject');
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: (isSuccess ? AppColors.successGreen : isReject ? AppColors.rose : AppColors.amber).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isSuccess ? Icons.verified_user_rounded : Icons.shield_outlined,
          color: isSuccess ? AppColors.successGreen : isReject ? AppColors.rose : AppColors.amber,
          size: 20,
        ),
      );
    }

    if (title.contains('payout') || title.contains('withdrawal') || screen == 'earnings' || screen == 'payout') {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.successGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.successGreen, size: 20),
      );
    }

    if (screen == 'video' || title.contains('video') || title.contains('premiere') || title.contains('release')) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.play_circle_outline_rounded, color: AppColors.primaryBlue, size: 20),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.notifications_active_outlined, color: AppColors.primaryBlue, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NotificationStore.instance,
      builder: (context, _) {
        final notifications = NotificationStore.instance.notifications;
        final unreadCount = NotificationStore.instance.unreadCount;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sheet Drag Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (unreadCount > 0)
                      TextButton(
                        onPressed: () => NotificationStore.instance.markAllAsRead(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                        ),
                      ),
                    if (notifications.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined, size: 20, color: AppColors.textSecondary),
                        tooltip: 'Clear All Notifications',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              title: const Text('Clear all notifications?'),
                              content: const Text('This will remove all push notification history from your device.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    NotificationStore.instance.clearAll();
                                    Navigator.pop(dialogCtx);
                                  },
                                  child: const Text('Clear All', style: TextStyle(color: AppColors.rose)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Content List or Empty State
              Expanded(
                child: notifications.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.canvasBackground,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_off_outlined,
                                  size: 28,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No Notifications Yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'When administrators approve your videos, verify your KYC, settle bank payouts, or dispatch channel announcements, you\'ll see them here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = notifications[index];
                          return Dismissible(
                            key: ValueKey(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppColors.rose.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete_outline, color: AppColors.rose),
                            ),
                            onDismissed: (_) {
                              NotificationStore.instance.delete(item.id);
                            },
                            child: InkWell(
                              onTap: () => _handleNotificationTap(context, item),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: item.isRead ? Colors.white : AppColors.primaryBlue.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: item.isRead ? AppColors.surfaceBorder : AppColors.primaryBlue.withValues(alpha: 0.25),
                                    width: item.isRead ? 1 : 1.2,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTypeIcon(item),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: TextStyle(
                                                    fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                                    fontSize: 13,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _formatRelativeTime(item.receivedAt),
                                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                          if (item.body.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              item.body,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: item.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                                                height: 1.35,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                          if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: AspectRatio(
                                                aspectRatio: 16 / 9,
                                                child: Image.network(
                                                  item.imageUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (!item.isRead) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(top: 4),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primaryBlue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
