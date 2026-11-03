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
  String get formattedDate => '${date.day}/${date.month}/${date.year}';
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
  bool get quotaMet => buckets.every((b) => b.isCompleted);

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
          title: 'Pending Milestone Settlement (Silver)',
          amount: 2500.00,
          type: 'credit',
          date: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
    );
  }
}
