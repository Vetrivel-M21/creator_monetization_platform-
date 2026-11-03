import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  static AuthService get instance => _instance;

  AuthService._internal();

  static const String _prefTokenKey = 'armss_auth_token';
  static const String _prefUserKey = 'armss_auth_user';

  final ApiService _apiService = ApiService();

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
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_prefTokenKey);
      final userJson = prefs.getString(_prefUserKey);
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

  Future<bool> login({required String email, required String password}) async {
    final result = await _apiService.login(email: email, password: password);
    if (result != null && result['token'] != null && result['user'] != null) {
      _token = result['token'] as String;
      _currentUser = result['user'] as UserModel;
      await _persistSession();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String? channelName,
    String? channelDescription,
  }) async {
    final result = await _apiService.register(
      name: name,
      email: email,
      password: password,
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

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
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

