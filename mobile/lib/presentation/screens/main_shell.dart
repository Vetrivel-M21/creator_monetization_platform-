import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../widgets/auth_required_dialog.dart';
import '../widgets/upload_sheet.dart';
import 'home/home_screen.dart';
import 'shorts/shorts_screen.dart';
import 'subscriptions/subscriptions_screen.dart';
import 'studio/studio_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  Future<void> _triggerUploadFlow() async {
    final auth = AuthService.instance;
    if (auth.isGuest) {
      final loggedIn = await AuthRequiredDialog.show(
        context,
        actionName: 'upload and monetize videos',
      );
      if (!loggedIn) return;
    }

    if (mounted) {
      UploadActionSheet.show(context);
    }
  }

  void _onTabSelected(int index) {
    if (index == 2) {
      _triggerUploadFlow();
      return;
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isShortsActive = _currentIndex == 1;

    final List<Widget> pages = [
      HomeScreen(onOpenUpload: _triggerUploadFlow),
      ShortsScreen(isActive: isShortsActive),
      const SizedBox.shrink(), // Placeholder for center '+'
      const SubscriptionsScreen(),
      const StudioScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.canvasBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isShortsActive
              ? Colors.black.withValues(alpha: 0.90)
              : AppColors.cardSurface,
          border: Border(
            top: BorderSide(
              color: isShortsActive ? Colors.white12 : AppColors.surfaceBorder,
              width: 1,
            ),
          ),
          boxShadow: isShortsActive
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  label: 'Home',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  isDark: isShortsActive,
                ),
                _buildNavItem(
                  index: 1,
                  label: 'Shorts',
                  icon: Icons.play_arrow_outlined,
                  activeIcon: Icons.play_arrow_rounded,
                  isDark: isShortsActive,
                ),
                _buildCenterCreateButton(isDark: isShortsActive),
                _buildNavItem(
                  index: 3,
                  label: 'Subscriptions',
                  icon: Icons.subscriptions_outlined,
                  activeIcon: Icons.subscriptions_rounded,
                  isDark: isShortsActive,
                ),
                _buildNavItem(
                  index: 4,
                  label: 'Studio',
                  icon: Icons.monetization_on_outlined,
                  activeIcon: Icons.monetization_on_rounded,
                  isDark: isShortsActive,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final color = isDark
        ? (isSelected ? Colors.white : Colors.white60)
        : (isSelected ? AppColors.textPrimary : AppColors.textSecondary);

    return Expanded(
      child: InkWell(
        onTap: () => _onTabSelected(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterCreateButton({required bool isDark}) {
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: () => _onTabSelected(2),
          child: Container(
            width: 44,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? Colors.white : AppColors.darkPill,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.add_rounded,
              color: isDark ? AppColors.textPrimary : Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
