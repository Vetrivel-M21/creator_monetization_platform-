import '../../core/constants/api_constants.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String mobile;
  final int age;
  final String channelName;
  final String channelLogo;
  final String channelDescription;
  final String role; // 'user' or 'admin'
  final String tier; // 'silver', 'gold', 'diamond'
  final bool isActive;
  final double walletAmount;
  final bool isKycVerified;
  final String? token;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.mobile = '',
    this.age = 0,
    this.channelName = '',
    this.channelLogo = '',
    this.channelDescription = '',
    this.role = 'user',
    this.tier = 'silver',
    this.isActive = true,
    this.walletAmount = 0.0,
    this.isKycVerified = false,
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      channelName: json['channel_name']?.toString() ?? '',
      channelLogo: json['channel_logo']?.toString() ?? '',
      channelDescription: json['channel_description']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      tier: json['tier']?.toString() ?? 'silver',
      isActive: json['is_active'] == true || json['is_active'] == 1,
      walletAmount: (json['wallet_amount'] as num?)?.toDouble() ?? 0.0,
      isKycVerified: json['is_kyc_verified'] == true || json['is_kyc_verified'] == 1,
      token: token ?? json['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'mobile': mobile,
      'age': age,
      'channel_name': channelName,
      'channel_logo': channelLogo,
      'channel_description': channelDescription,
      'role': role,
      'tier': tier,
      'is_active': isActive,
      'wallet_amount': walletAmount,
      'is_kyc_verified': isKycVerified,
      'token': token,
    };
  }

  UserModel copyWith({
    String? name,
    String? mobile,
    int? age,
    String? channelName,
    String? channelLogo,
    String? channelDescription,
    double? walletAmount,
    bool? isKycVerified,
    String? token,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      age: age ?? this.age,
      channelName: channelName ?? this.channelName,
      channelLogo: channelLogo ?? this.channelLogo,
      channelDescription: channelDescription ?? this.channelDescription,
      role: role,
      tier: tier,
      isActive: isActive,
      walletAmount: walletAmount ?? this.walletAmount,
      isKycVerified: isKycVerified ?? this.isKycVerified,
      token: token ?? this.token,
    );
  }

  String get displayName => channelName.isNotEmpty ? channelName : (name.isNotEmpty ? name : 'Creator');
  String get displayAvatar {
    if (channelLogo.isNotEmpty) {
      if (channelLogo.startsWith('http')) return channelLogo;
      final serverRoot = ApiConstants.baseUrl.replaceAll('/api', '');
      return '$serverRoot$channelLogo';
    }
    return 'https://api.dicebear.com/7.x/bottts/svg?seed=$id';
  }
}

