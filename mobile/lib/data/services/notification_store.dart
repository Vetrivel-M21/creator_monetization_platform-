import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.data = const {},
    required this.receivedAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'image_url': imageUrl,
      'data': data,
      'received_at': receivedAt.toIso8601String(),
      'is_read': isRead,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : {},
      receivedAt: json['received_at'] != null
          ? DateTime.tryParse(json['received_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isRead: json['is_read'] == true,
    );
  }
}

class NotificationStore extends ChangeNotifier {
  NotificationStore._();
  static final NotificationStore instance = NotificationStore._();

  static const String _storageKey = 'aura_notification_inbox_v1';
  static const int _maxStoredNotifications = 50;

  final List<AppNotification> _notifications = [];
  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  bool _isLoaded = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => unreadCountNotifier.value;

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _notifications.clear();
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _notifications.add(AppNotification.fromJson(item));
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationStore] Init error: $e');
    } finally {
      _isLoaded = true;
      _updateUnreadCount();
      notifyListeners();
    }
  }

  /// Appends a notification from FCM RemoteMessage
  Future<void> addFromRemoteMessage(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final imageUrl = message.notification?.android?.imageUrl ??
        message.notification?.apple?.imageUrl ??
        message.data['image_url'];

    final id = message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Prevent duplicate entries for the same messageId
    if (_notifications.any((n) => n.id == id)) return;

    final notification = AppNotification(
      id: id,
      title: title,
      body: body,
      imageUrl: imageUrl?.toString(),
      data: Map<String, dynamic>.from(message.data),
      receivedAt: DateTime.now(),
      isRead: false,
    );

    await add(notification);
  }

  /// Static helper for background message handler
  static Future<void> saveBackgroundMessage(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      List<dynamic> list = [];
      if (raw != null && raw.isNotEmpty) {
        list = jsonDecode(raw) as List<dynamic>;
      }

      final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      final imageUrl = message.notification?.android?.imageUrl ??
          message.notification?.apple?.imageUrl ??
          message.data['image_url'];
      final id = message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

      // Check duplicate
      final exists = list.any((item) => item is Map && item['id'] == id);
      if (!exists) {
        final newEntry = {
          'id': id,
          'title': title,
          'body': body,
          'image_url': imageUrl?.toString(),
          'data': message.data,
          'received_at': DateTime.now().toIso8601String(),
          'is_read': false,
        };
        list.insert(0, newEntry);
        if (list.length > _maxStoredNotifications) {
          list = list.sublist(0, _maxStoredNotifications);
        }
        await prefs.setString(_storageKey, jsonEncode(list));
      }
    } catch (e) {
      debugPrint('[NotificationStore] Background save note: $e');
    }
  }

  Future<void> add(AppNotification notification) async {
    _notifications.insert(0, notification);
    if (_notifications.length > _maxStoredNotifications) {
      _notifications.removeRange(_maxStoredNotifications, _notifications.length);
    }
    _updateUnreadCount();
    notifyListeners();
    await _persist();
  }

  Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx].isRead = true;
      _updateUnreadCount();
      notifyListeners();
      await _persist();
    }
  }

  Future<void> markAllAsRead() async {
    bool changed = false;
    for (final n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      _updateUnreadCount();
      notifyListeners();
      await _persist();
    }
  }

  Future<void> clearAll() async {
    if (_notifications.isNotEmpty) {
      _notifications.clear();
      _updateUnreadCount();
      notifyListeners();
      await _persist();
    }
  }

  Future<void> delete(String id) async {
    _notifications.removeWhere((n) => n.id == id);
    _updateUnreadCount();
    notifyListeners();
    await _persist();
  }

  void _updateUnreadCount() {
    final count = _notifications.where((n) => !n.isRead).length;
    unreadCountNotifier.value = count;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_notifications.map((n) => n.toJson()).toList());
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('[NotificationStore] Persist error: $e');
    }
  }
}
