/// Single source of truth for API configuration across environments.
class ApiConstants {
  ApiConstants._();

  // Environment selector: 'dev', 'staging', 'prod'
  // Pass via: flutter run --dart-define=ENV=dev or --dart-define=API_BASE_URL=https://...
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'prod',
  );

  static const String _customBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // static const String _devBaseUrl = 'http://10.0.2.2:2085/api'; // Android emulator localhost
  static const String _stagingBaseUrl =
      'https://entertainment.aurapictures.online/api';
  static const String _prodBaseUrl =
      'https://entertainment.aurapictures.online/api';

  static String get baseUrl {
    if (_customBaseUrl.isNotEmpty) {
      return _customBaseUrl;
    }
    switch (environment.toLowerCase()) { 
      case 'prod':
      case 'production':
      default:
        return _prodBaseUrl;
    }
  }

  // Reasonable timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration requestTimeout = Duration(seconds: 15);
  static const Duration uploadTimeout = Duration(minutes: 5);
}
