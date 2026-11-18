import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/services/push_service.dart';
import 'core/theme/app_theme.dart';
import 'data/services/auth_service.dart';
import 'data/services/library_service.dart';
import 'data/services/notification_store.dart';
import 'presentation/screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.init();
  await LibraryService.instance.init();
  await NotificationStore.instance.init();

  // Initialize Firebase Core & Background Messaging
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
  } catch (e) {
    debugPrint('[Push] Firebase init / Background messaging note: $e');
  }

  // Set system UI overlay style for Clean Sky Blue Light Theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const CreatorMonetizationApp());
}

class CreatorMonetizationApp extends StatelessWidget {
  const CreatorMonetizationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aura Entertainment',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainShellScreen(),
    );
  }
}
