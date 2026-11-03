import 'package:flutter/material.dart';
import 'package:creator_monetization_app/core/theme/app_colors.dart';
import 'package:creator_monetization_app/presentation/widgets/upload_sheet.dart';
import 'package:creator_monetization_app/presentation/screens/home/home_screen.dart';
import 'package:creator_monetization_app/presentation/screens/shorts/shorts_screen.dart';
import 'package:creator_monetization_app/presentation/screens/subscriptions/subscriptions_screen.dart';
import 'package:creator_monetization_app/presentation/screens/studio/studio_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  void _triggerUploadFlow() {
    UploadActionSheet.show(context);
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
      const ShortsScreen(),
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
              ? Colors.black.withValues(alpha: 0.85)
              : AppColors.cardSurface,
          border: Border(
            top: BorderSide(
              color: isShortsActive ? Colors.white12 : AppColors.surfaceBorder,
              width: 1,
            ),
          ),
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
        : (isSelected ? AppColors.primaryAccent : AppColors.mutedText);

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
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), AppColors.primaryAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryAccent.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
