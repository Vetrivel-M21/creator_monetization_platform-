import 'package:flutter/material.dart';
import 'package:creator_monetization_app/core/theme/app_colors.dart';
import 'package:creator_monetization_app/data/models/studio_model.dart';
import 'package:creator_monetization_app/data/models/video_model.dart';
import 'package:creator_monetization_app/data/services/api_service.dart';
import 'package:creator_monetization_app/data/services/auth_service.dart';
import '../support/support_screen.dart';
import '../legal/legal_screen.dart';
import '../upload/upload_video_screen.dart';
import '../../widgets/auth_sheet.dart';
import '../../widgets/auth_required_dialog.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  final ApiService _apiService = ApiService();
  late Future<CreatorStudioModel> _studioFuture;
  late Future<List<VideoModel>> _myVideosFuture;

  @override
  void initState() {
    super.initState();
    _loadStudio();
  }

  void _loadStudio() {
    final auth = AuthService.instance;
    _studioFuture = _apiService.fetchStudioData(auth.token, auth.currentUser);
    if (auth.isLoggedIn && auth.currentUser != null) {
      _myVideosFuture = _apiService.fetchMyUploadedVideos(auth.token!, auth.currentUser!.id);
    } else {
      _myVideosFuture = Future.value(<VideoModel>[]);
    }
  }

  Future<void> _navigateToUpload() async {
    final auth = AuthService.instance;
    if (auth.isGuest) {
      final loggedIn = await AuthRequiredDialog.show(
        context,
        actionName: 'upload and monetize videos',
      );
      if (!loggedIn) return;
    }
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const UploadVideoScreen()),
      ).then((_) => _loadStudio());
    }
  }

  void _showRequestPayoutDialog(BuildContext context, CreatorStudioModel studio) {
    final balance = studio.availableBalance;
    final bankInfo = studio.kycBank.isNotEmpty
        ? '${studio.kycBank} •••• ${studio.kycAccount.length > 4 ? studio.kycAccount.substring(studio.kycAccount.length - 4) : studio.kycAccount}'
        : 'Bank Account •••• 4021';
    final kycTag = studio.isKycVerified ? '(KYC Verified)' : '(KYC Pending Approval)';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.secondaryBadgeBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.primaryAccent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request Bank Payout',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                      Text(
                        'Silver Tier Certified Creators',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.canvasBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Available for Withdrawal:',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '₹${balance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.successGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Direct deposit to: $bankInfo $kycTag',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final auth = AuthService.instance;
                    if (auth.token == null || auth.token!.isEmpty) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please log in to submit a payout request.')),
                      );
                      return;
                    }
                    if (!studio.isKycVerified) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bank KYC must be verified before requesting bank payouts.'),
                          backgroundColor: AppColors.rose,
                        ),
                      );
                      return;
                    }
                    if (balance < 500) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Minimum withdrawal amount is ₹500.00'),
                          backgroundColor: AppColors.rose,
                        ),
                      );
                      return;
                    }

                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Submitting bank withdrawal request...')),
                    );

                    final result = await _apiService.requestWithdrawal(
                      amount: balance,
                      token: auth.token!,
                    );

                    if (mounted) {
                      if (result['success'] == true) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(result['message'] as String? ?? 'Payout request submitted successfully!'),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                        setState(() => _loadStudio());
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(result['error'] as String? ?? 'Payout request failed.'),
                            backgroundColor: AppColors.rose,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: const Text(
                    'Confirm Payout Request',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showKycDetailsDialog(BuildContext context, CreatorStudioModel studio) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: AppColors.successGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Creator KYC Verification',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                      ),
                      Text(
                        'Aadhaar & PAN Identity Status',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildKycRow('Legal Name', studio.kycHolderName.isNotEmpty ? studio.kycHolderName : studio.creatorName),
              _buildKycRow(
                'KYC Status',
                studio.isKycVerified ? 'Verified & Approved' : 'Pending Verification',
                isSuccess: studio.isKycVerified,
              ),
              _buildKycRow(
                'ID Verification',
                studio.kycAadhaar.isNotEmpty
                    ? (studio.kycAadhaar.length >= 4 ? 'Aadhaar •••• ${studio.kycAadhaar.substring(studio.kycAadhaar.length - 4)}' : studio.kycAadhaar)
                    : 'Aadhaar •••• 9812',
              ),
              _buildKycRow('Tax PAN', studio.kycPan.isNotEmpty ? studio.kycPan : 'ABCDE••••F'),
              _buildKycRow(
                'Bank Account',
                studio.kycBank.isNotEmpty
                    ? '${studio.kycBank} (IFSC: ${studio.kycIfsc})'
                    : 'HDFC Bank (IFSC: HDFC0001234)',
              ),
              const SizedBox(height: 18),
              if (!studio.isKycVerified) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showKycSubmissionDialog(context, studio);
                    },
                    icon: const Icon(Icons.assignment_turned_in_rounded, size: 18),
                    label: const Text('Submit / Update Bank KYC', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    LegalScreen.show(context, initialTabIndex: 0);
                  },
                  icon: const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
                  label: const Text(
                    'View Creator Terms & Privacy Policy',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close Details'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showKycSubmissionDialog(BuildContext context, CreatorStudioModel studio) {
    final auth = AuthService.instance;
    if (auth.isGuest || auth.token == null) {
      AuthSheet.show(context);
      return;
    }

    final nameController = TextEditingController(text: studio.kycHolderName.isNotEmpty ? studio.kycHolderName : studio.creatorName);
    final aadhaarController = TextEditingController(text: studio.kycAadhaar);
    final panController = TextEditingController(text: studio.kycPan);
    final bankNameController = TextEditingController(text: studio.kycBank.isNotEmpty ? studio.kycBank : 'HDFC Bank');
    final accountController = TextEditingController(text: studio.kycAccount);
    final ifscController = TextEditingController(text: studio.kycIfsc.isNotEmpty ? studio.kycIfsc : 'HDFC0001234');

    bool isLoading = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: bottomInset + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(Icons.assignment_turned_in_rounded, color: AppColors.primaryAccent, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Submit Creator KYC Details',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primaryText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Required for Indian banking compliance & creator monetization payouts.',
                      style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                    ),
                    const SizedBox(height: 14),

                    if (errorText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.rose.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(errorText!, style: const TextStyle(fontSize: 12, color: AppColors.rose)),
                      ),
                      const SizedBox(height: 10),
                    ],

                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Legal Account Holder Name',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: aadhaarController,
                      keyboardType: TextInputType.number,
                      maxLength: 12,
                      decoration: const InputDecoration(
                        labelText: 'Aadhaar Card Number (12 Digits)',
                        counterText: '',
                        prefixIcon: Icon(Icons.badge_outlined, size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: panController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'PAN Card Number (e.g. ABCDE1234F)',
                        counterText: '',
                        prefixIcon: Icon(Icons.credit_card, size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bankNameController,
                      decoration: const InputDecoration(
                        labelText: 'Bank Name (e.g. HDFC Bank, SBI)',
                        prefixIcon: Icon(Icons.account_balance, size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: accountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Bank Account Number',
                        prefixIcon: Icon(Icons.numbers, size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ifscController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 11,
                      decoration: const InputDecoration(
                        labelText: 'IFSC Code (e.g. HDFC0001234)',
                        counterText: '',
                        prefixIcon: Icon(Icons.tag, size: 18),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final aadhaar = aadhaarController.text.trim();
                                final pan = panController.text.trim();
                                final bankName = bankNameController.text.trim();
                                final account = accountController.text.trim();
                                final ifsc = ifscController.text.trim();

                                if (name.isEmpty || aadhaar.length != 12 || pan.length != 10 || bankName.isEmpty || account.isEmpty || ifsc.length != 11) {
                                  setModalState(() {
                                    errorText = 'Please complete all fields with valid 12-digit Aadhaar, 10-char PAN, and 11-char IFSC.';
                                  });
                                  return;
                                }

                                setModalState(() {
                                  isLoading = true;
                                  errorText = null;
                                });

                                final res = await _apiService.submitKyc(
                                  token: auth.token!,
                                  pan: pan,
                                  aadhaar: aadhaar,
                                  bankAccount: account,
                                  ifsc: ifsc,
                                  bankName: bankName,
                                  holderName: name,
                                );

                                if (res['success'] == true) {
                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('KYC Submitted Successfully! Your details are pending fast verification.'),
                                        backgroundColor: AppColors.successGreen,
                                      ),
                                    );
                                    setState(() => _loadStudio());
                                  }
                                } else {
                                  setModalState(() {
                                    isLoading = false;
                                    errorText = res['error'] as String? ?? 'KYC submission failed.';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Submit KYC Verification', style: TextStyle(fontWeight: FontWeight.w700)),
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

  void _showEditProfileDialog(BuildContext context, CreatorStudioModel studio) {
    final auth = AuthService.instance;
    if (auth.isGuest || auth.token == null) {
      AuthSheet.show(context);
      return;
    }

    final nameCtrl = TextEditingController(text: studio.creatorName);
    final channelCtrl = TextEditingController(text: studio.channelName);
    final bioCtrl = TextEditingController(text: studio.channelDescription);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(left: 20, right: 20, top: 18, bottom: bottomInset + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.surfaceBorder, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Edit Creator Channel Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Display Name', prefixIcon: Icon(Icons.person)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: channelCtrl,
                    decoration: const InputDecoration(labelText: 'Channel Name', prefixIcon: Icon(Icons.video_collection)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: bioCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Channel Bio / Description', prefixIcon: Icon(Icons.info_outline)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            final ok = await _apiService.updateProfile(
                              token: auth.token!,
                              name: nameCtrl.text.trim(),
                              channelName: channelCtrl.text.trim(),
                              channelDescription: bioCtrl.text.trim(),
                            );
                            if (ok && context.mounted) {
                              if (auth.currentUser != null) {
                                auth.updateCurrentUser(auth.currentUser!.copyWith(
                                  name: nameCtrl.text.trim(),
                                  channelName: channelCtrl.text.trim(),
                                  channelDescription: bioCtrl.text.trim(),
                                ));
                              }
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Channel profile updated successfully!')),
                              );
                              setState(() => _loadStudio());
                            } else {
                              setModalState(() => isSaving = false);
                            }
                          },
                    child: isSaving ? const CircularProgressIndicator() : const Text('Save Profile Changes'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKycRow(String label, String value, {bool isSuccess = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSuccess ? AppColors.successGreen : AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasBackground,
      appBar: AppBar(
        title: const Text('Creator Studio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Channel Settings',
            onPressed: () {
              final auth = AuthService.instance;
              if (auth.isGuest) {
                AuthSheet.show(context);
              } else {
                _studioFuture.then((s) {
                  if (context.mounted) _showEditProfileDialog(context, s);
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.support_agent_rounded),
            tooltip: 'Creator Support Desk',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SupportScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _loadStudio();
          });
        },
        color: AppColors.primaryAccent,
        backgroundColor: AppColors.cardSurface,
        child: FutureBuilder<CreatorStudioModel>(
          future: _studioFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryAccent,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.mutedText),
                    const SizedBox(height: 12),
                    const Text('Failed to load Creator Studio'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadStudio();
                        });
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final studio = snapshot.data!;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Channel Profile & Creator Details Card
                _buildCreatorProfileCard(studio),
                const SizedBox(height: 16),

                // 2. Withdrawable Balance Hero Card
                _buildBalanceCard(context, studio),
                const SizedBox(height: 16),

                // 3. Silver Tier Milestone & Pure Tier Rewards Banner
                _buildSilverMilestoneCard(context, studio),
                const SizedBox(height: 16),

                // 4. Duration Quotas Tracker
                _buildDurationQuotasCard(studio),
                const SizedBox(height: 16),

                // 5. Recent Ledger Transactions
                _buildLedgerTransactionsCard(studio),
                const SizedBox(height: 16),

                // 6. My Uploaded Content Manager
                _buildMyUploadedContentCard(studio),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMyUploadedContentCard(CreatorStudioModel studio) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.video_library_rounded, size: 20, color: AppColors.primaryAccent),
                  SizedBox(width: 8),
                  Text(
                    'My Uploaded Content',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryText),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _navigateToUpload,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Upload New', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<VideoModel>>(
            future: _myVideosFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primaryAccent)));
              }
              final videos = snapshot.data ?? [];
              if (videos.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.canvasBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_upload_outlined, size: 36, color: AppColors.mutedText),
                      const SizedBox(height: 8),
                      const Text(
                        'No videos uploaded yet',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Upload 16:9 Landscape masterclasses or 9:16 Shorts to start monetizing watch time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppColors.mutedText),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _navigateToUpload,
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('Upload First Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: videos.map((v) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.canvasBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            v.thumbnailUrl,
                            width: 70,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stackTrace) => Container(
                              width: 70,
                              height: 44,
                              color: Colors.black26,
                              child: const Icon(Icons.play_circle_outline, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: v.videoType == 'short' ? Colors.purple.withValues(alpha: 0.1) : AppColors.primaryAccent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      v.videoType == 'short' ? '9:16 Short' : '16:9 Landscape',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: v.videoType == 'short' ? Colors.purple : AppColors.primaryAccent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${v.viewsCount} views • ₹${v.totalEarned.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.mutedText),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            v.status.toUpperCase(),
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.successGreen),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // 1. Channel Profile & Creator Details Card
  Widget _buildCreatorProfileCard(CreatorStudioModel studio) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.secondaryBadgeBg,
                    backgroundImage: NetworkImage(studio.channelLogo),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            studio.channelName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          size: 17,
                          color: AppColors.primaryAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      studio.channelDescription,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.surfaceBorder),
          const SizedBox(height: 12),

          // Creator Personal Details (Age, Email, Mobile)
          Row(
            children: [
              Expanded(
                child: _buildDetailChip(
                  icon: Icons.calendar_today_rounded,
                  label: 'Age',
                  value: '${studio.creatorAge} yrs',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDetailChip(
                  icon: Icons.phone_android_rounded,
                  label: 'Mobile',
                  value: studio.creatorMobile,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildDetailChip(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: studio.creatorEmail,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.canvasBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryAccent),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Withdrawable Balance Card
  Widget _buildBalanceCard(BuildContext context, CreatorStudioModel studio) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Available Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Silver Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹${studio.availableBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFBBF24), size: 15),
              const SizedBox(width: 5),
              Text(
                'Includes ₹${studio.welcomeGrant.toStringAsFixed(0)} Welcome Creator Grant',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Payout and KYC Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRequestPayoutDialog(context, studio),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                  label: const Text(
                    'Request Payout',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showKycDetailsDialog(context, studio),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.verified_user_rounded, size: 16, color: Colors.white),
                  label: const Text(
                    'Bank KYC',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. Silver Tier Milestone Card
  Widget _buildSilverMilestoneCard(BuildContext context, CreatorStudioModel studio) {
    final progress = (studio.completedVideoCount / studio.requiredVideoCount).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                ),
                child: const Icon(
                  Icons.military_tech_rounded,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Silver Tier Reward',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.successGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'KYC Verified',
                            style: TextStyle(
                              color: AppColors.successGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Complete ${studio.requiredVideoCount} qualified videos to unlock ₹${studio.tierRewardAmount.toStringAsFixed(0)} milestone payout.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Linear Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Milestone Progress (${studio.completedVideoCount}/${studio.requiredVideoCount} Videos)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.secondaryBadgeBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 15, color: AppColors.primaryAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pure Tier Policy: Rewards unlock upon achieving target video counts and KYC approval.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryBadgeText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Duration Quotas Tracker
  Widget _buildDurationQuotasCard(CreatorStudioModel studio) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Video Duration Quotas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              Text(
                'Weekly Limits',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: studio.quotas.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final quota = studio.quotas[index];
              final double ratio = quota.maxCount > 0 ? (quota.usedCount / quota.maxCount).clamp(0.0, 1.0) : 0.0;
              final bool isFull = quota.usedCount >= quota.maxCount;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.canvasBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isFull
                                    ? const Color(0xFFFEE2E2)
                                    : AppColors.secondaryBadgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                quota.durationLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isFull
                                      ? const Color(0xFFDC2626)
                                      : AppColors.primaryAccent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Max ${quota.durationLabel} video',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${quota.usedCount} / ${quota.maxCount} Uploaded',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isFull ? const Color(0xFFDC2626) : AppColors.primaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isFull ? const Color(0xFFDC2626) : AppColors.primaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 5. Recent Ledger Transactions
  Widget _buildLedgerTransactionsCard(CreatorStudioModel studio) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ledger Transactions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              Text(
                'Real-time',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: studio.transactions.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              color: AppColors.surfaceBorder,
            ),
            itemBuilder: (context, index) {
              final tx = studio.transactions[index];
              final isCredit = tx.type.toLowerCase() == 'credit';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCredit
                            ? AppColors.successGreen.withValues(alpha: 0.12)
                            : const Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: isCredit ? AppColors.successGreen : const Color(0xFFDC2626),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.description,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tx.formattedDate,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isCredit ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isCredit ? AppColors.successGreen : const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tx.status,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
