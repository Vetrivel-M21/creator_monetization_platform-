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

  /// Base root URL without trailing '/api'
  static String get serverRoot {
    final base = baseUrl.trim();
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }

  /// Converts relative path into absolute URL using the active environment
  static String toAbsoluteUrl(String path) {
    var clean = path.trim();
    if (clean.isEmpty) return clean;
    if (clean.startsWith('http://entertainment.aurapictures.online')) {
      clean = clean.replaceFirst('http://', 'https://');
    }
    if (clean.startsWith('http://') || clean.startsWith('https://') || clean.startsWith('blob:')) {
      return clean;
    }
    final root = serverRoot.replaceAll(RegExp(r'/+$'), '');
    final p = clean.startsWith('/') ? clean : '/$clean';
    return '$root$p';
  }

  // Reasonable timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration requestTimeout = Duration(seconds: 15);
  static const Duration uploadTimeout = Duration(minutes: 5);
}
