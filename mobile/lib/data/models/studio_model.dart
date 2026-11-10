import 'user_model.dart';

class DurationQuotaItem {
  final String key;
  final String label;
  final int current;
  final int max;
  final double ratePerVideo;

  DurationQuotaItem({
    required this.key,
    required this.label,
    required this.current,
    this.max = 10,
    required this.ratePerVideo,
  });

  bool get isCompleted => current >= max;
  double get progress => max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;

  String get durationLabel => key;
  int get usedCount => current;
  int get maxCount => max;

  factory DurationQuotaItem.fromJson(Map<String, dynamic> json) {
    return DurationQuotaItem(
      key: json['key']?.toString() ?? '2m',
      label: json['label']?.toString() ?? 'Qualified Videos',
      current: (json['approved_count'] as num?)?.toInt() ?? 0,
      max: (json['target_count'] as num?)?.toInt() ?? 10,
      ratePerVideo: (json['rate_per_view'] as num?)?.toDouble() ?? 25.0,
    );
  }
}

class StudioTransaction {
  final String id;
  final String title;
  final double amount;
  final String type; // 'credit' or 'debit'
  final DateTime date;

  StudioTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
  });

  String get description => title;
  String get status => 'Settled';
  String get formattedDate =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  factory StudioTransaction.fromJson(Map<String, dynamic> json) {
    final rawDate = json['created_at']?.toString();
    return StudioTransaction(
      id: json['id']?.toString() ?? '',
      title: json['description']?.toString() ?? 'Wallet Transaction',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: (json['type']?.toString().toLowerCase().contains('credit') ?? true) ? 'credit' : 'debit',
      date: rawDate != null ? DateTime.tryParse(rawDate) ?? DateTime.now() : DateTime.now(),
    );
  }
}

class CreatorStudioModel {
  final String channelName;
  final String channelLogo;
  final String channelDescription;
  final String creatorName;
  final int age;
  final String email;
  final String mobile;
  final double walletBalance;
  final double welcomeCredit;
  final String tier;
  final bool isKycVerified;
  final String kycHolderName;
  final String kycAadhaar;
  final String kycPan;
  final String kycBank;
  final String kycAccount;
  final String kycIfsc;
  final bool silverRewardPaid;
  final int totalApprovedVideos;
  final List<DurationQuotaItem> buckets;
  final List<StudioTransaction> transactions;

  CreatorStudioModel({
    required this.channelName,
    required this.channelLogo,
    required this.channelDescription,
    required this.creatorName,
    required this.age,
    required this.email,
    required this.mobile,
    required this.walletBalance,
    required this.welcomeCredit,
    required this.tier,
    required this.isKycVerified,
    this.kycHolderName = '',
    this.kycAadhaar = '',
    this.kycPan = '',
    this.kycBank = '',
    this.kycAccount = '',
    this.kycIfsc = '',
    required this.silverRewardPaid,
    required this.totalApprovedVideos,
    required this.buckets,
    required this.transactions,
  });

  double get withdrawableBalance => walletBalance;
  double get availableBalance => walletBalance;
  double get welcomeGrant => welcomeCredit;
  int get creatorAge => age;
  String get creatorMobile => mobile;
  String get creatorEmail => email;
  int get completedVideoCount => totalApprovedVideos;
  int get requiredVideoCount => 10;
  double get tierRewardAmount => 2500.0;
  List<DurationQuotaItem> get quotas => buckets;
  bool get quotaMet => buckets.isNotEmpty && buckets.every((b) => b.isCompleted);

  String get milestoneStatus {
    if (silverRewardPaid) {
      return 'Paid (₹2,500.00)';
    } else if (quotaMet) {
      if (isKycVerified) {
        return 'Ready for Payout';
      } else {
        return 'Hold (Needs Bank KYC)';
      }
    } else {
      return 'In Progress ($totalApprovedVideos/50 videos)';
    }
  }

  factory CreatorStudioModel.fromBackend({
    required UserModel user,
    Map<String, dynamic>? eligibility,
    Map<String, dynamic>? kycData,
    Map<String, dynamic>? walletData,
  }) {
    // Parse duration buckets from eligibility
    List<DurationQuotaItem> parsedBuckets = [];
    if (eligibility != null && eligibility['buckets'] is List) {
      final list = eligibility['buckets'] as List;
      parsedBuckets = list.map((b) => DurationQuotaItem.fromJson(Map<String, dynamic>.from(b as Map))).toList();
    }
    if (parsedBuckets.isEmpty) {
      parsedBuckets = [
        DurationQuotaItem(key: '30m', label: '30+ Min Videos', current: 0, max: 10, ratePerVideo: 80.0),
        DurationQuotaItem(key: '20m', label: '20-29 Min Videos', current: 0, max: 10, ratePerVideo: 60.0),
        DurationQuotaItem(key: '10m', label: '10-19 Min Videos', current: 0, max: 10, ratePerVideo: 50.0),
        DurationQuotaItem(key: '5m', label: '5-9 Min Videos', current: 0, max: 10, ratePerVideo: 35.0),
        DurationQuotaItem(key: '2m', label: '2-4 Min Videos', current: 0, max: 10, ratePerVideo: 25.0),
      ];
    }

    // Parse transactions from walletData
    List<StudioTransaction> parsedTransactions = [];
    if (walletData != null && walletData['transactions'] is List) {
      final list = walletData['transactions'] as List;
      parsedTransactions = list.map((tx) => StudioTransaction.fromJson(Map<String, dynamic>.from(tx as Map))).toList();
    }

    // Parse KYC details
    final kycMap = kycData != null && kycData['kyc'] is Map ? kycData['kyc'] as Map : null;
    final isVerified = kycMap != null && (kycMap['is_verified'] == true || kycMap['is_verified'] == 1);
    final holderName = kycMap?['account_holder']?.toString() ?? user.name;
    final aadhaar = kycMap?['aadhaar_number']?.toString() ?? '';
    final pan = kycMap?['pan_number']?.toString() ?? '';
    final bank = kycMap?['bank_name']?.toString() ?? '';
    final account = kycMap?['bank_account']?.toString() ?? '';
    final ifsc = kycMap?['ifsc_code']?.toString() ?? '';

    final totalVideos = (eligibility?['total_videos'] as num?)?.toInt() ?? 0;
    final balance = (walletData?['balance'] as num?)?.toDouble() ?? user.walletAmount;

    return CreatorStudioModel(
      channelName: user.channelName.isNotEmpty ? user.channelName : user.name,
      channelLogo: user.displayAvatar,
      channelDescription: user.channelDescription.isNotEmpty ? user.channelDescription : 'Original human creator channel',
      creatorName: user.name,
      age: user.age > 0 ? user.age : 25,
      email: user.email,
      mobile: user.mobile.isNotEmpty ? user.mobile : '+91 98765 43210',
      walletBalance: balance,
      welcomeCredit: 250.00,
      tier: user.tier.isNotEmpty ? '${user.tier[0].toUpperCase()}${user.tier.substring(1)}' : 'Silver',
      isKycVerified: isVerified,
      kycHolderName: holderName,
      kycAadhaar: aadhaar,
      kycPan: pan,
      kycBank: bank,
      kycAccount: account,
      kycIfsc: ifsc,
      silverRewardPaid: (eligibility?['total_earned'] as num?)?.toDouble() != null &&
          (eligibility!['total_earned'] as num).toDouble() >= 2500,
      totalApprovedVideos: totalVideos,
      buckets: parsedBuckets,
      transactions: parsedTransactions,
    );
  }

  factory CreatorStudioModel.sample() {
    return CreatorStudioModel(
      channelName: 'Vetri Tech Studio',
      channelLogo: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=160&auto=format&fit=crop&q=80',
      channelDescription: 'Tech reviews, software engineering and developer productivity tips.',
      creatorName: 'Vetri Mahendran',
      age: 24,
      email: 'creator1@armss.com',
      mobile: '+91 98765 43210',
      walletBalance: 2750.00,
      welcomeCredit: 250.00,
      tier: 'Silver',
      isKycVerified: true,
      kycHolderName: 'Vetrivel M',
      kycAadhaar: 'XXXXXXXX9812',
      kycPan: 'ABCDE1234F',
      kycBank: 'HDFC Bank',
      kycAccount: 'XXXXXX4021',
      kycIfsc: 'HDFC0001234',
      silverRewardPaid: false,
      totalApprovedVideos: 7,
      buckets: [
        DurationQuotaItem(key: '30m', label: '30+ Min Videos', current: 3, max: 10, ratePerVideo: 80.0),
        DurationQuotaItem(key: '20m', label: '20-29 Min Videos', current: 4, max: 10, ratePerVideo: 60.0),
        DurationQuotaItem(key: '10m', label: '10-19 Min Videos', current: 2, max: 10, ratePerVideo: 50.0),
        DurationQuotaItem(key: '5m', label: '5-9 Min Videos', current: 3, max: 10, ratePerVideo: 35.0),
        DurationQuotaItem(key: '2m', label: '2-4 Min Videos', current: 2, max: 10, ratePerVideo: 25.0),
      ],
      transactions: [
        StudioTransaction(
          id: 'tx-01',
          title: 'Welcome Registration Grant',
          amount: 250.00,
          type: 'credit',
          date: DateTime.now().subtract(const Duration(days: 3)),
        ),
        StudioTransaction(
          id: 'tx-02',
          title: 'Milestone Settlement Grant (Silver)',
          amount: 2500.00,
          type: 'credit',
          date: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
    );
  }
}
