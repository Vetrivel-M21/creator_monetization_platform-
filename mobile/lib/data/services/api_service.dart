import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/category_model.dart';
import '../models/video_model.dart';
import '../models/studio_model.dart';
import '../models/user_model.dart';
import '../../core/utils/date_formatter.dart';

class ApiService {
  // Workstation private Wi-Fi IP for seamless mobile device connectivity
  static const String serverHost = '10.10.100.251:2085';
  static const String baseUrl = 'http://$serverHost/api';

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
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final categories = data.map((c) => CategoryModel.fromJson(c)).toList();
          // Always ensure 'All' is at the top
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
    } catch (_) {
      // Graceful fallback to default categories
    }
    return CategoryModel.defaultCategories();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Videos & Shorts Feeds
  // ─────────────────────────────────────────────────────────────────────────────

  Future<List<VideoModel>> fetchVideos({
    String category = 'All',
    String? videoType,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (category.isNotEmpty && category.toLowerCase() != 'all') {
        queryParams['category'] = category.toLowerCase();
      }
      if (videoType != null && videoType.isNotEmpty) {
        queryParams['video_type'] = videoType;
      }

      final uri = Uri.parse('$baseUrl/videos').replace(
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        var list = data.map((json) => VideoModel.fromJson(json)).toList();

        // Client-side filtering ensures safety if server returns all
        if (videoType != null && videoType.isNotEmpty) {
          list = list.where((v) => v.videoType == videoType).toList();
        }
        if (category.isNotEmpty && category.toLowerCase() != 'all') {
          list = list.where((v) {
            final cat = v.category.toLowerCase();
            final target = category.toLowerCase();
            return cat.contains(target) || target.contains(cat);
          }).toList();
        }
        return list;
      }
    } catch (_) {
      // Graceful fallback to mock data
    }

    var mocks = getMockVideos();
    if (videoType != null && videoType.isNotEmpty) {
      mocks = mocks.where((v) => v.videoType == videoType).toList();
    }
    if (category.isNotEmpty && category.toLowerCase() != 'all') {
      mocks = mocks.where((v) => v.category.toLowerCase().contains(category.toLowerCase())).toList();
    }
    return mocks;
  }

  Future<List<VideoModel>> fetchLandscapeVideos({String category = 'All'}) {
    return fetchVideos(category: category, videoType: 'landscape');
  }

  Future<List<VideoModel>> fetchShorts() {
    return fetchVideos(videoType: 'short');
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
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> shareVideo(String videoId) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/videos/$videoId/share'), headers: _headers())
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> recordView(String videoId) async {
    try {
      final res = await http
          .post(Uri.parse('$baseUrl/videos/$videoId/view'), headers: _headers())
          .timeout(const Duration(seconds: 3));
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
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((c) => CommentModel.fromJson(c)).toList();
      }
    } catch (_) {}

    final now = DateTime.now();
    return [
      CommentModel(
        id: 'cmt-1',
        videoId: videoId,
        author: 'Anand Kumar',
        avatar: 'https://api.dicebear.com/7.x/bottts/svg?seed=anand',
        text: 'The explanation on duration buckets and adaptive CMAF streaming is top tier!',
        likes: 18,
        createdAt: now.subtract(const Duration(minutes: 15)),
        timeFormatted: formatTimeAgo(now.subtract(const Duration(minutes: 15))),
      ),
      CommentModel(
        id: 'cmt-2',
        videoId: videoId,
        author: 'Sara Jenkins',
        avatar: 'https://api.dicebear.com/7.x/bottts/svg?seed=sara',
        text: 'Glad to see a platform paying creators for authentic human-crafted tutorials.',
        likes: 9,
        createdAt: now.subtract(const Duration(hours: 1)),
        timeFormatted: formatTimeAgo(now.subtract(const Duration(hours: 1))),
      ),
      CommentModel(
        id: 'cmt-3',
        videoId: videoId,
        author: 'Karthik Raja',
        avatar: 'https://api.dicebear.com/7.x/bottts/svg?seed=karthik',
        text: 'Master Movie trailer breakdown when? Great video overall!',
        likes: 4,
        createdAt: now.subtract(const Duration(hours: 2)),
        timeFormatted: formatTimeAgo(now.subtract(const Duration(hours: 2))),
      ),
    ];
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
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 || res.statusCode == 201) {
        return CommentModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Authentication
  // ─────────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: _headers(),
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 6));
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

  Future<Map<String, dynamic>?> register({
    required String name,
    required String email,
    required String password,
    String? channelName,
    String? channelDescription,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: _headers(),
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'channel_name': channelName ?? name,
              'channel_description': channelDescription ?? '',
              'age': 25,
            }),
          )
          .timeout(const Duration(seconds: 6));
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
      final res = await http
          .post(
            Uri.parse('$baseUrl/auth/google'),
            headers: _headers(),
            body: jsonEncode({
              'credential': idToken,
              if (email != null) 'email': email,
              if (name != null) 'name': name,
            }),
          )
          .timeout(const Duration(seconds: 6));
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

      // Add video file
      final videoFile = File(filePath);
      if (!await videoFile.exists()) return false;
      request.files.add(await http.MultipartFile.fromPath('video', filePath));

      // Add thumbnail if present
      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        final thumbFile = File(thumbnailPath);
        if (await thumbFile.exists()) {
          request.files.add(await http.MultipartFile.fromPath('thumbnail', thumbnailPath));
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Creator Studio & Mock Fallbacks
  // ─────────────────────────────────────────────────────────────────────────────

  // Support Chat
  Future<Map<String, dynamic>?> fetchSupportThread(String token) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/support/thread'), headers: _headers(token))
          .timeout(const Duration(seconds: 5));
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
          .timeout(const Duration(seconds: 5));
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
          .timeout(const Duration(seconds: 5));
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
          .timeout(const Duration(seconds: 5));
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
          .timeout(const Duration(seconds: 5));
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
          .timeout(const Duration(seconds: 5));
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
          .timeout(const Duration(seconds: 8));

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
    return CreatorStudioModel.sample();
  }

  Future<List<VideoModel>> fetchHomeVideos() => fetchLandscapeVideos();
  Future<CreatorStudioModel> fetchStudioData([String? token, UserModel? user]) =>
      fetchCreatorStudio(token, user);

  static List<VideoModel> getMockVideos() {
    return const [];
  }

  static List<ShortReelModel> getMockReels() {
    return getMockVideos()
        .where((v) => v.videoType == 'short')
        .map((v) => ShortReelModel.fromVideoModel(v))
        .toList();
  }
}
