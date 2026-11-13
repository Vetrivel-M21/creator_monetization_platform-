import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  static AuthService get instance => _instance;

  AuthService._internal();

  static const String _prefTokenKey = 'aura_auth_token';
  static const String _prefUserKey = 'aura_auth_user';

  final ApiService _apiService = ApiService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  UserModel? _currentUser;
  String? _token;
  bool _isInitialized = false;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty && _currentUser != null;
  bool get isGuest => !isLoggedIn;
  bool get isInitialized => _isInitialized;

  /// Retrieves the authenticated JWT session token from memory or SharedPreferences
  Future<String?> getToken() async {
    if (_token != null && _token!.isNotEmpty) {
      return _token;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_prefTokenKey);
      return _token;
    } catch (_) {
      return null;
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;

    // Attach 401 Unauthorized handler to ApiService
    ApiService.onUnauthorized = handleUnauthorized;

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_prefTokenKey) ?? prefs.getString('armss_auth_token');
      final userJson = prefs.getString(_prefUserKey) ?? prefs.getString('armss_auth_user');
      if (userJson != null && userJson.isNotEmpty) {
        _currentUser = UserModel.fromJson(jsonDecode(userJson), token: _token);
      }
    } catch (_) {
      // Ignore cache restore errors
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Automatically clears session when token is rejected (401 Unauthorized)
  Future<void> handleUnauthorized() async {
    if (_token != null || _currentUser != null) {
      await logout();
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    final result = await _apiService.login(identifier: identifier, password: password);
    if (result != null && result['token'] != null && result['user'] != null) {
      _token = result['token'] as String;
      _currentUser = result['user'] as UserModel;
      await _persistSession();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> sendOtp(String email) async {
    return _apiService.sendOtp(email);
  }

  Future<Map<String, dynamic>?> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final result = await _apiService.verifyOtp(email: email, otp: otp);
    if (result != null && result['token'] != null && result['user'] != null) {
      _token = result['token'] as String;
      _currentUser = result['user'] as UserModel;
      await _persistSession();
      notifyListeners();
    }
    return result;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? mobile,
    int age = 25,
    String? channelName,
    String? channelDescription,
  }) async {
    final result = await _apiService.register(
      name: name,
      email: email,
      password: password,
      mobile: mobile,
      age: age,
      channelName: channelName,
      channelDescription: channelDescription,
    );
    if (result != null && result['token'] != null && result['user'] != null) {
      _token = result['token'] as String;
      _currentUser = result['user'] as UserModel;
      await _persistSession();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Real Google Sign-In via official google_sign_in package
  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // User aborted the Google login sheet
        return false;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final credential = auth.idToken ?? auth.accessToken;
      if (credential == null || credential.isEmpty) {
        return false;
      }

      final result = await _apiService.googleLogin(
        idToken: credential,
        email: account.email,
        name: account.displayName,
      );

      if (result != null && result['token'] != null && result['user'] != null) {
        _token = result['token'] as String;
        _currentUser = result['user'] as UserModel;
        await _persistSession();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('[AuthService] Google Sign-In error: $e');
    }
    return false;
  }

  /// Direct token exchange helper
  Future<bool> googleLogin({
    required String idToken,
    String? email,
    String? name,
  }) async {
    final result = await _apiService.googleLogin(
      idToken: idToken,
      email: email,
      name: name,
    );
    if (result != null && result['token'] != null && result['user'] != null) {
      _token = result['token'] as String;
      _currentUser = result['user'] as UserModel;
      await _persistSession();
      notifyListeners();
      return true;
    }
    return false;
  }

  void updateCurrentUser(UserModel updated) {
    _currentUser = updated;
    _persistSession();
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefTokenKey);
      await prefs.remove(_prefUserKey);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString(_prefTokenKey, _token!);
      }
      if (_currentUser != null) {
        await prefs.setString(_prefUserKey, jsonEncode(_currentUser!.toJson()));
      }
    } catch (_) {}
  }
}
