import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class LegalScreen extends StatefulWidget {
  final int initialTabIndex; // 0: Terms & Conditions, 1: Privacy Policy

  const LegalScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  static Future<void> show(BuildContext context, {int initialTabIndex = 0}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalScreen(initialTabIndex: initialTabIndex),
      ),
    );
  }

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Legal & Compliance',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Terms of Service'),
                Tab(text: 'Privacy Policy'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTermsTab(),
          _buildPrivacyTab(),
        ],
      ),
    );
  }

  Widget _buildTermsTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Notice banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.secondaryBadge,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.gavel_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ARMSS Entertainment Creator Agreement. All creators uploading content agree to 100% human-authored videos and statutory anti-AI compliance.',
                  style: TextStyle(fontSize: 12, color: AppColors.primaryDark, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        _buildSectionCard(
          title: '1. Human-Authored Content Mandate',
          body:
              'ARMSS is committed exclusively to human craftsmanship. All uploaded content—both Landscape (16:9) long-form and Vertical Shorts (9:16)—must be 100% created, authored, and voice-recorded by human creators.\n\nAutomated AI scrapers, voice synthesizers, or generative video models are strictly banned. Accounts violating this policy are permanently suspended and royalties forfeited.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          title: '2. Monetization & Duration Bucket Quotas',
          body:
              'Monetization is calculated dynamically according to duration buckets (30m, 20m, 10m, 5m, 2m) and administrator review audit.\n\nMilestone payouts (Silver ₹2,500, Gold ₹10,000, Diamond ₹25,000) are unlocked upon completing designated video quotas and clearing manual review.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          title: '3. Bank KYC & Payout Settlement',
          body:
              'To receive direct bank deposits, creators must verify identity via Aadhaar and PAN numbers and supply valid bank account details with IFSC code. Payouts are settled through Cashfree / IMPS / NEFT within 24-48 business hours.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          title: '4. Copyright & Streaming Rights',
          body:
              'Creators maintain copyright over their uploaded media while granting ARMSS a worldwide, non-exclusive license to transcode, store, and stream adaptive CMAF HLS bitrate feeds to viewers.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          title: '5. Community Standards',
          body:
              'Any abusive behavior, hate speech, copyrighted music piracy, or spam comments are prohibited and will result in moderation action.',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPrivacyTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Security Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.emeraldLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.emerald.withValues(alpha: 0.2)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: AppColors.emerald, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your privacy is our priority. Financial KYC information and watch history are encrypted with industry-standard protocols.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF065F46), height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        _buildSectionCard(
          title: '1. Information We Collect',
          body:
              '• Profile Data: Full name, email address, channel name, bio, and profile avatar.\n• Google Authentication: Name, verified email address, and OAuth tokens.\n• KYC Identity Data: Aadhaar number, PAN card number, bank account details, and IFSC code for statutory tax and payout verification.\n• Watch Analytics: Video view count, watch minutes, likes, and comment activity.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          title: '2. How Information is Used',
          body:
              '• Operating streaming services and CMAF adaptive bitrate delivery.\n• Calculating creator monetization royalties and processing payouts.\n• Enforcing anti-bot fraud protection and human-only creator compliance.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          title: '3. Data Security & Encryption',
          body:
              'All data in transit is encrypted using TLS/HTTPS. Passwords are salted and hashed using bcrypt. Sensitive KYC documents are strictly restricted to staff compliance officers.',
        ),
        const SizedBox(height: 14),

        _buildSectionCard(
          title: '4. Data Retention & Deletion Rights',
          body:
              'Users have the right to inspect, correct, or request deletion of their account records by contacting ARMSS Support Desk or emailing legal@armss.com.',
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

