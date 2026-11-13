import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/category_model.dart';
import '../models/studio_model.dart';
import '../models/user_model.dart';
import '../models/video_model.dart';

class ApiService {
  static String get baseUrl => ApiConstants.baseUrl;

  /// Global callback invoked on 401 Unauthorized responses
  static void Function()? onUnauthorized;

  static void _checkUnauthorized(int statusCode, String? token) {
    if (statusCode == 401 && token != null && token.isNotEmpty) {
      onUnauthorized?.call();
    }
  }

  static Map<String, String> _headers([String? token]) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Categories
  // ─────────────────────────────────────────────────────────────────────────────

  Future<List<CategoryModel>> fetchCategories() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/categories'))
          .timeout(ApiConstants.requestTimeout);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final categories = data.map((c) => CategoryModel.fromJson(c)).toList();
          if (!categories.any((c) => c.slug == 'all')) {
            categories.insert(
              0,
              const CategoryModel(
                id: 'cat-all',
                name: 'All',
                slug: 'all',
                description: 'All categories',
                icon: 'Sparkles',
              ),
            );
          }
          return categories;
        }
      }
    } catch (_) {}
    return CategoryModel.defaultCategories();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Videos & Shorts Feeds
  // ─────────────────────────────────────────────────────────────────────────────

  Future<List<VideoModel>> fetchVideos({
    String category = 'All',
    String? videoType,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (category.isNotEmpty && category.toLowerCase() != 'all') {
        queryParams['category'] = category.toLowerCase();
      }
      if (videoType != null && videoType.isNotEmpty && videoType.toLowerCase() != 'all') {
        queryParams['video_type'] = videoType;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final uri = Uri.parse('$baseUrl/videos').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final response = await http.get(uri).timeout(ApiConstants.requestTimeout);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        var list = data.map((json) => VideoModel.fromJson(json)).toList();

        if (videoType != null && videoType.isNotEmpty && videoType.toLowerCase() != 'all') {
          list = list.where((v) => v.videoType == videoType).toList();
        }
        if (category.isNotEmpty && category.toLowerCase() != 'all') {
          list = list.where((v) {
            final cat = v.category.toLowerCase();
            final target = category.toLowerCase();
            return cat.contains(target) || target.contains(cat);
          }).toList();
        }
        if (search != null && search.trim().isNotEmpty) {
          final query = search.trim().toLowerCase();
          list = list.where((v) {
            return v.title.toLowerCase().contains(query) ||
                v.creatorName.toLowerCase().contains(query) ||
                v.description.toLowerCase().contains(query);
          }).toList();
        }
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<List<VideoModel>> fetchLandscapeVideos({String category = 'All'}) {
    return fetchVideos(category: category, videoType: 'landscape');
  }

  Future<List<VideoModel>> fetchShorts() {
    return fetchVideos(videoType: 'short');
  }

  /// Obtains a short-lived signed playback ticket with absolute HLS stream URL bound to videoId
  Future<Map<String, dynamic>?> fetchPlaybackTicket(String videoId, {String? token}) async {
    try {
      final res = await http
          .get(
            Uri.parse('$baseUrl/videos/$videoId/playback'),
            headers: _headers(token),
          )
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Social Actions (Like, Share, View, Subscribe)
  // ─────────────────────────────────────────────────────────────────────────────

  Future<bool> toggleLike(String videoId, {bool unlike = false, String? token}) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/videos/$videoId/like'),
            headers: _headers(token),
            body: jsonEncode({'unlike': unlike}),
          )
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> shareVideo(String videoId, {String? token}) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/videos/$videoId/share'), headers: _headers(token))
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> recordView(String videoId) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/videos/$videoId/view'), headers: _headers())
          .timeout(ApiConstants.requestTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Comments
  // ─────────────────────────────────────────────────────────────────────────────

  Future<List<CommentModel>> fetchComments(String videoId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/videos/$videoId/comments'))
          .timeout(ApiConstants.requestTimeout);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((c) => CommentModel.fromJson(c)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<CommentModel?> postComment(
    String videoId, {
    required String content,
    required String userName,
    String? userId,
    String? token,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/videos/$videoId/comments'),
            headers: _headers(token),
            body: jsonEncode({
              'user_id': userId ?? 'guest',
              'user_name': userName,
              'content': content,
            }),
          )
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return CommentModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Authentication & OTP Engine
  // ─────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final cleanId = identifier.trim();
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: _headers(),
            body: jsonEncode({
              'identifier': cleanId,
              'email': cleanId,
              'password': password,
            }),
          )
          .timeout(ApiConstants.requestTimeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['token'] != null && data['user'] != null) {
          final user = UserModel.fromJson(data['user'], token: data['token']);
          return {'token': data['token'], 'user': user};
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> sendOtp(String email) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/send-otp'),
            headers: _headers(),
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(ApiConstants.requestTimeout);

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-otp'),
            headers: _headers(),
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'otp': otp.trim(),
            }),
          )
          .timeout(ApiConstants.requestTimeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['token'] != null && data['user'] != null) {
          final user = UserModel.fromJson(data['user'], token: data['token']);
          return {
            'is_new_user': false,
            'token': data['token'],
            'user': user,
            'message': data['message'],
          };
        } else if (data['is_new_user'] == true) {
          return {
            'is_new_user': true,
            'email': data['email'] ?? email,
            'message': data['message'],
          };
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> register({
    required String name,
    required String email,
    required String password,
    String? mobile,
    int age = 25,
    String? channelName,
    String? channelDescription,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: _headers(),
            body: jsonEncode({
              'name': name.trim(),
              'email': email.trim().toLowerCase(),
              'mobile': mobile?.trim() ?? '',
              'age': age,
              'password': password,
              'channel_name': channelName?.trim().isNotEmpty == true ? channelName!.trim() : name.trim(),
              'channel_description': channelDescription?.trim() ?? '',
            }),
          )
          .timeout(ApiConstants.requestTimeout);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data['token'] != null && data['user'] != null) {
          final user = UserModel.fromJson(data['user'], token: data['token']);
          return {'token': data['token'], 'user': user};
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> googleLogin({
    required String idToken,
    String? email,
    String? name,
  }) async {
    try {
      final payload = <String, dynamic>{'credential': idToken};
      if (email != null) payload['email'] = email;
      if (name != null) payload['name'] = name;

      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/google'),
            headers: _headers(),
            body: jsonEncode(payload),
          )
          .timeout(ApiConstants.requestTimeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['token'] != null && data['user'] != null) {
          final user = UserModel.fromJson(data['user'], token: data['token']);
          return {'token': data['token'], 'user': user};
        }
      }
    } catch (_) {}
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Upload Video (Multipart Form)
  // ─────────────────────────────────────────────────────────────────────────────

  Future<bool> uploadVideo({
    required String filePath,
    String? thumbnailPath,
    required String title,
    required String description,
    required String category,
    required String videoType,
    double? durationMinutes,
    String? durationBucket,
    String? token,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/videos/upload');
      final request = http.MultipartRequest('POST', uri);

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['category'] = category;
      request.fields['video_type'] = videoType;
      if (durationMinutes != null && durationMinutes > 0) {
        request.fields['duration_minutes'] = durationMinutes.toString();
      }
      if (durationBucket != null && durationBucket.isNotEmpty) {
        request.fields['duration_bucket'] = durationBucket;
      }

      final videoFile = File(filePath);
      if (!await videoFile.exists()) return false;
      request.files.add(await http.MultipartFile.fromPath('video', filePath));

      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        final thumbFile = File(thumbnailPath);
        if (await thumbFile.exists()) {
          request.files.add(await http.MultipartFile.fromPath('thumbnail', thumbnailPath));
        }
      }

      final streamedResponse = await request.send().timeout(ApiConstants.uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      _checkUnauthorized(response.statusCode, token);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Support, User Profile, Studio & Wallet
  // ─────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchSupportThread(String token) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/support/thread'), headers: _headers(token))
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> sendSupportMessage(String token, String message) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/support/message'),
            headers: _headers(token),
            body: jsonEncode({'message': message}),
          )
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String token) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/user/profile'), headers: _headers(token))
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> fetchEligibility(String token, [String? userId]) async {
    try {
      final uri = Uri.parse('$baseUrl/creator/eligibility');
      final res = await http
          .get(uri, headers: _headers(token))
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> fetchKyc(String token) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/kyc'), headers: _headers(token))
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> fetchWallet(String token, String userId) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/wallet/$userId'), headers: _headers(token))
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    required String token,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/wallet/withdraw'),
            headers: _headers(token),
            body: jsonEncode({'amount': amount}),
          )
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Payout request submitted successfully!',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Withdrawal failed. (Status ${res.statusCode})',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network connection error: $e'};
    }
  }

  Future<CreatorStudioModel> fetchCreatorStudio([String? token, UserModel? user]) async {
    if (token != null && token.isNotEmpty && user != null) {
      try {
        final results = await Future.wait([
          fetchEligibility(token, user.id),
          fetchKyc(token),
          fetchWallet(token, user.id),
        ]);

        final eligibility = results[0];
        final kycData = results[1];
        final walletData = results[2];

        return CreatorStudioModel.fromBackend(
          user: user,
          eligibility: eligibility,
          kycData: kycData,
          walletData: walletData,
        );
      } catch (_) {}
    }
    return CreatorStudioModel.empty(user);
  }

  Future<Map<String, dynamic>> submitKyc({
    required String token,
    required String pan,
    required String aadhaar,
    required String bankAccount,
    required String ifsc,
    required String bankName,
    required String holderName,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/kyc'),
            headers: _headers(token),
            body: jsonEncode({
              'pan_number': pan.trim().toUpperCase(),
              'aadhaar_number': aadhaar.trim().replaceAll(' ', ''),
              'bank_account': bankAccount.trim(),
              'ifsc_code': ifsc.trim().toUpperCase(),
              'bank_name': bankName.trim(),
              'account_holder': holderName.trim(),
              'agreement_agreed': true,
            }),
          )
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'KYC submitted successfully for review!',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'KYC submission failed.',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network connection error: $e'};
    }
  }

  Future<List<VideoModel>> fetchMyUploadedVideos(String token, String userId) async {
    try {
      final uri = Uri.parse('$baseUrl/videos?creator_id=$userId&status=all');
      final res = await http
          .get(uri, headers: _headers(token))
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((json) => VideoModel.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<UserModel?> updateProfile({
    required String token,
    required String name,
    int age = 25,
    String mobile = '',
    required String channelName,
    required String channelDescription,
  }) async {
    try {
      final res = await http
          .put(
            Uri.parse('$baseUrl/user/profile'),
            headers: _headers(token),
            body: jsonEncode({
              'name': name.trim(),
              'age': age,
              'mobile': mobile.trim(),
              'channel_name': channelName.trim(),
              'channel_description': channelDescription.trim(),
            }),
          )
          .timeout(ApiConstants.requestTimeout);
      _checkUnauthorized(res.statusCode, token);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['user'] != null) {
          return UserModel.fromJson(data['user'], token: token);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> uploadChannelLogo({
    required String token,
    required String filePath,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/user/channel-logo');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      final file = File(filePath);
      if (!await file.exists()) return null;
      request.files.add(await http.MultipartFile.fromPath('logo', filePath));

      final streamedResponse = await request.send().timeout(ApiConstants.uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      _checkUnauthorized(response.statusCode, token);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['logo_url']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<List<VideoModel>> fetchHomeVideos() => fetchLandscapeVideos();
  Future<CreatorStudioModel> fetchStudioData([String? token, UserModel? user]) =>
      fetchCreatorStudio(token, user);

  /// Minimal offline demo videos only used if an explicit demo is triggered
  static List<VideoModel> getOfflineDemoVideos() {
    return const [];
  }

  static List<VideoModel> getMockVideos() => const [];

  List<VideoModel> getHomeShortsFallback() => const [];
}
