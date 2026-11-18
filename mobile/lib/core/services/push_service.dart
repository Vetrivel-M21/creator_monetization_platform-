import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, HttpClient;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../data/services/notification_store.dart';

@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    await NotificationStore.saveBackgroundMessage(message);
  } catch (e) {
    debugPrint('[Push] Background handler init note: $e');
  }
}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const bool enabled = true;

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _started = false;

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final req = await HttpClient().getUrl(Uri.parse(url)).timeout(const Duration(seconds: 5));
      final res = await req.close().timeout(const Duration(seconds: 5));
      return Uint8List.fromList(await consolidateHttpClientResponseBytes(res));
    } catch (_) {
      return null;
    }
  }

  /// Initializes FCM and Local Notifications.
  /// Safe and failure-isolated: will never throw unhandled exceptions or crash app.
  Future<void> start({
    required Future<void> Function(String token, String platform) registerToken,
    void Function(Map<String, dynamic> data)? onTap,
  }) async {
    if (!enabled || _started) return;

    try {
      try {
        await Firebase.initializeApp();
      } catch (e) {
        debugPrint('[Push] Firebase.initializeApp note: $e');
      }

      final fm = FirebaseMessaging.instance;
      final settings = await fm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[Push] FCM permission status: ${settings.authorizationStatus}');

      // Foreground notification display settings
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );

      await _local.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final data = jsonDecode(response.payload!) as Map<String, dynamic>;
              onTap?.call(data);
            } catch (_) {}
          }
        },
      );

      // Explicitly request Android 13+ (API 33+) notification runtime permission
      if (Platform.isAndroid) {
        final androidImpl = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final androidGranted = await androidImpl?.requestNotificationsPermission();
        debugPrint('[Push] Android 13+ runtime notification permission: $androidGranted');

        // Create high-importance notification channel
        const channel = AndroidNotificationChannel(
          'armss_general',
          'General Notifications',
          description: 'Updates for video reviews, channel uploads, KYC verifications and releases',
          importance: Importance.max,
        );
        await androidImpl?.createNotificationChannel(channel);
      }

      final platform = Platform.isIOS ? 'ios' : 'android';
      final token = await fm.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[Push] FCM Token obtained: ${token.substring(0, token.length > 15 ? 15 : token.length)}...');
        await registerToken(token, platform);
      }

      fm.onTokenRefresh.listen((newToken) {
        registerToken(newToken, platform);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        // Save to in-app notification inbox
        await NotificationStore.instance.addFromRemoteMessage(message);

        final n = message.notification;
        if (n == null) return;

        final imgUrl = n.android?.imageUrl ?? n.apple?.imageUrl ?? message.data['image_url'];
        final bytes = (imgUrl != null && imgUrl.isNotEmpty) ? await _downloadImage(imgUrl) : null;

        _local.show(
          n.hashCode,
          n.title,
          n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'armss_general',
              'General Notifications',
              channelDescription: 'Updates for video reviews, channel uploads and platform announcements',
              importance: Importance.max,
              priority: Priority.high,
              styleInformation: bytes != null
                  ? BigPictureStyleInformation(ByteArrayAndroidBitmap(bytes))
                  : null,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          payload: jsonEncode(message.data),
        );
      });

      // App opened from background state
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (message.messageId != null) {
          NotificationStore.instance.markAsRead(message.messageId!);
        }
        onTap?.call(message.data);
      });

      // App launched from terminated state
      final initial = await fm.getInitialMessage();
      if (initial != null) {
        if (initial.messageId != null) {
          NotificationStore.instance.markAsRead(initial.messageId!);
        }
        onTap?.call(initial.data);
      }

      _started = true;
      debugPrint('[Push] ✓ PushService successfully initialized');
    } catch (e, st) {
      debugPrint('[Push] PushService initialization note (app continues): $e\n$st');
    }
  }

  /// Re-syncs the device FCM token with the backend upon authentication change
  Future<void> syncToken({
    required Future<void> Function(String token, String platform) registerToken,
  }) async {
    try {
      final fm = FirebaseMessaging.instance;
      final token = await fm.getToken();
      if (token != null && token.isNotEmpty) {
        final platform = Platform.isIOS ? 'ios' : 'android';
        await registerToken(token, platform);
        debugPrint('[Push] ✓ FCM Token synced for active session');
      }
    } catch (e) {
      debugPrint('[Push] syncToken note: $e');
    }
  }

  /// Deregisters token from backend and Firebase on user sign-out
  Future<void> stop(Future<void> Function(String token) unregisterToken) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await unregisterToken(token);
      }
      await FirebaseMessaging.instance.deleteToken();
      _started = false;
    } catch (e) {
      debugPrint('[Push] PushService stop note: $e');
    }
  }
}

