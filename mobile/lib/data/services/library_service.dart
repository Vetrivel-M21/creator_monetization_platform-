import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_model.dart';

class LibraryService extends ChangeNotifier {
  static final LibraryService _instance = LibraryService._internal();
  factory LibraryService() => _instance;
  static LibraryService get instance => _instance;

  LibraryService._internal();

  static const String _prefSavedKey = 'aura_saved_videos';
  static const String _prefLikedKey = 'aura_liked_videos';
  static const String _prefHistoryKey = 'aura_watch_history';

  final List<VideoModel> _saved = [];
  final List<VideoModel> _liked = [];
  final List<VideoModel> _history = [];
  bool _initialized = false;

  List<VideoModel> get savedVideos => List.unmodifiable(_saved);
  List<VideoModel> get likedVideos => List.unmodifiable(_liked);
  List<VideoModel> get watchHistory => List.unmodifiable(_history);

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _loadList(prefs, _prefSavedKey, _saved);
      _loadList(prefs, _prefLikedKey, _liked);
      _loadList(prefs, _prefHistoryKey, _history);
    } catch (_) {}
    _initialized = true;
    notifyListeners();
  }

  void _loadList(SharedPreferences prefs, String key, List<VideoModel> target) {
    target.clear();
    final legacyKey = key.replaceFirst('aura_', 'armss_');
    final raw = prefs.getString(key) ?? prefs.getString(legacyKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List decoded = jsonDecode(raw);
        target.addAll(decoded.map((j) => VideoModel.fromJson(j)));
      } catch (_) {}
    }
  }

  Future<void> _persist(String key, List<VideoModel> source) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(source.map((v) => v.toJson()).toList());
      await prefs.setString(key, data);
    } catch (_) {}
  }

  bool isSaved(String videoId) {
    return _saved.any((v) => v.id == videoId);
  }

  Future<bool> toggleSave(VideoModel video) async {
    await init();
    final idx = _saved.indexWhere((v) => v.id == video.id);
    bool savedNow;
    if (idx >= 0) {
      _saved.removeAt(idx);
      savedNow = false;
    } else {
      _saved.insert(0, video.copyWith(isSaved: true));
      savedNow = true;
    }
    await _persist(_prefSavedKey, _saved);
    notifyListeners();
    return savedNow;
  }

  bool isLiked(String videoId) {
    return _liked.any((v) => v.id == videoId);
  }

  Future<bool> toggleLike(VideoModel video) async {
    await init();
    final idx = _liked.indexWhere((v) => v.id == video.id);
    bool likedNow;
    if (idx >= 0) {
      _liked.removeAt(idx);
      likedNow = false;
    } else {
      _liked.insert(0, video.copyWith(isLiked: true));
      likedNow = true;
    }
    await _persist(_prefLikedKey, _liked);
    notifyListeners();
    return likedNow;
  }

  Future<void> recordHistory(VideoModel video) async {
    await init();
    _history.removeWhere((v) => v.id == video.id);
    _history.insert(0, video);
    if (_history.length > 50) {
      _history.removeRange(50, _history.length);
    }
    await _persist(_prefHistoryKey, _history);
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _persist(_prefHistoryKey, _history);
    notifyListeners();
  }
}

