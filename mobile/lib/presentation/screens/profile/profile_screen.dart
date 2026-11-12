import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/auth_service.dart';
import '../library/library_screen.dart';
import '../studio/studio_screen.dart';
import '../support/support_screen.dart';
import '../legal/legal_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
        title: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: const Text(
          'Are you sure you want to sign out of your creator account?',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await AuthService.instance.logout();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _openEditProfileSheet(BuildContext context, UserModel user) {
    final nameController = TextEditingController(text: user.name);
    final mobileController = TextEditingController(text: user.mobile);
    final ageController = TextEditingController(
      text: user.age > 0 ? user.age.toString() : '24',
    );
    final channelNameController = TextEditingController(
      text: user.channelName.isNotEmpty ? user.channelName : user.name,
    );
    final channelDescController = TextEditingController(text: user.channelDescription);

    String? pickedLogoPath;
    bool isSaving = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickNewLogo() async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                  allowMultiple: false,
                );
                if (result != null && result.files.single.path != null) {
                  setModalState(() {
                    pickedLogoPath = result.files.single.path;
                    errorMessage = null;
                  });
                }
              } catch (e) {
                setModalState(() => errorMessage = 'Failed to pick image: $e');
              }
            }

            Future<void> saveProfileChanges() async {
              final auth = AuthService.instance;
              final token = auth.token;
              if (token == null || token.isEmpty) {
                setModalState(() => errorMessage = 'Authentication session expired.');
                return;
              }

              final name = nameController.text.trim();
              if (name.isEmpty) {
                setModalState(() => errorMessage = 'Full Name cannot be empty.');
                return;
              }

              final ageText = ageController.text.trim();
              final age = int.tryParse(ageText) ?? 0;
              if (age < 10 || age > 120) {
                setModalState(() => errorMessage = 'Please enter a valid age (10-120).');
                return;
              }

              final mobile = mobileController.text.trim();
              if (mobile.isNotEmpty) {
                final digitsOnly = mobile.replaceAll(RegExp(r'\D'), '');
                if (digitsOnly.length != 10) {
                  setModalState(() => errorMessage = 'Mobile number must be exactly 10 digits.');
                  return;
                }
              }

              final channelName = channelNameController.text.trim().isNotEmpty
                  ? channelNameController.text.trim()
                  : name;
              final channelDesc = channelDescController.text.trim();

              setModalState(() {
                isSaving = true;
                errorMessage = null;
              });

              final api = ApiService();

              // 1. Upload logo if a new one was picked
              String? newLogoUrl;
              if (pickedLogoPath != null) {
                newLogoUrl = await api.uploadChannelLogo(
                  token: token,
                  filePath: pickedLogoPath!,
                );
              }

              // 2. Update profile personal data & channel info
              final updatedUser = await api.updateProfile(
                token: token,
                name: name,
                age: age,
                mobile: mobile,
                channelName: channelName,
                channelDescription: channelDesc,
              );

              if (context.mounted) {
                if (updatedUser != null) {
                  final finalUser = (newLogoUrl != null && newLogoUrl.isNotEmpty)
                      ? updatedUser.copyWith(channelLogo: newLogoUrl)
                      : updatedUser;
                  auth.updateCurrentUser(finalUser);

                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Profile & channel data updated successfully!'),
                        ],
                      ),
                      backgroundColor: AppColors.emerald,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  setModalState(() {
                    isSaving = false;
                    errorMessage = 'Failed to update profile. Please verify your details.';
                  });
                }
              }
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sheet Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sheet Title & Close
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Profile & Channel',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Update personal data and channel branding',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (errorMessage != null) ...[
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: AppColors.rose, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Avatar / Channel Logo Picker
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary, width: 2),
                              color: AppColors.scaffoldBackground,
                            ),
                            child: ClipOval(
                              child: pickedLogoPath != null
                                  ? Image.file(
                                      File(pickedLogoPath!),
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      user.displayAvatar,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person_rounded,
                                        size: 40,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                            ),
                          ),
                          InkWell(
                            onTap: isSaving ? null : pickNewLogo,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: TextButton.icon(
                        onPressed: isSaving ? null : pickNewLogo,
                        icon: const Icon(Icons.image_outlined, size: 16),
                        label: Text(
                          pickedLogoPath != null ? 'Change Selected Logo' : 'Upload Channel Logo',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 1. Full Name
                    const Text(
                      'Full Name *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        hintText: 'e.g. John Doe',
                        prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Age & Mobile Number in 2 columns
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Age
                        SizedBox(
                          width: 100,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Age *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: ageController,
                                enabled: !isSaving,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '25',
                                  prefixIcon: const Icon(Icons.cake_outlined, size: 18),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.surfaceBorder),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Mobile Number
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mobile Number (10 Digits) *',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: mobileController,
                                enabled: !isSaving,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: '9876543210',
                                  prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.surfaceBorder),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 3. Channel Name
                    const Text(
                      'Channel Name',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: channelNameController,
                      enabled: !isSaving,
                      decoration: InputDecoration(
                        hintText: "e.g. John's Production Studio",
                        prefixIcon: const Icon(Icons.tv_rounded, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 4. Channel Description / Bio
                    const Text(
                      'Channel Description / Bio',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: channelDescController,
                      enabled: !isSaving,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Describe your content, upload schedule, and topics...',
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.surfaceBorder),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    FilledButton(
                      onPressed: isSaving ? null : saveProfileChanges,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final auth = AuthService.instance;
        final user = auth.currentUser;

        if (user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: const Center(child: Text('Not signed in')),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          appBar: AppBar(
            title: const Text('Creator Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppColors.rose),
                tooltip: 'Sign Out',
                onPressed: () => _confirmLogout(context),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                // User Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.surfaceBorder, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: AppColors.scaffoldBackground,
                            backgroundImage: NetworkImage(user.displayAvatar),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.emerald,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check, size: 14, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      if (user.channelDescription.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          user.channelDescription,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Personal Data Badges: Mobile, Age, Channel Tier
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildDataBadge(
                              icon: Icons.phone_android_rounded,
                              label: 'Mobile',
                              value: user.mobile.isNotEmpty ? user.mobile : 'Not set',
                            ),
                            Container(width: 1, height: 28, color: AppColors.surfaceBorder),
                            _buildDataBadge(
                              icon: Icons.cake_rounded,
                              label: 'Age',
                              value: '${user.age > 0 ? user.age : 24} yrs',
                            ),
                            Container(width: 1, height: 28, color: AppColors.surfaceBorder),
                            _buildDataBadge(
                              icon: Icons.military_tech_rounded,
                              label: 'Tier',
                              value: user.tier.toUpperCase(),
                              highlight: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Edit Profile & Channel Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openEditProfileSheet(context, user),
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: const Text(
                            'Edit Profile & Channel',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Navigation Sections
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.surfaceBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildListTile(
                        icon: Icons.video_library_rounded,
                        title: 'Creator Studio & Monetization',
                        subtitle: 'Manage uploads, earnings & analytics',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const StudioScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildListTile(
                        icon: Icons.bookmark_border_rounded,
                        title: 'Personal Library',
                        subtitle: 'Saved, liked videos & watch history',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LibraryScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildListTile(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Support & Help Desk',
                        subtitle: 'Direct creator support team chat',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SupportScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Legal & Policies
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.surfaceBorder, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildListTile(
                        icon: Icons.description_outlined,
                        title: 'Terms of Service',
                        subtitle: 'Platform monetization guidelines',
                        onTap: () => LegalScreen.show(context, initialTabIndex: 0),
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildListTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'Data usage & creator rights',
                        onTap: () => LegalScreen.show(context, initialTabIndex: 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Logout Button
                OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.rose),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.rose,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: AppColors.rose.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ARMSS Creator Platform v1.0.0',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataBadge({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: highlight ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: highlight ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.scaffoldBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
