const String _defaultBaseUrl = 'http://192.168.1.50:5000/api';

class AppConfig {
  // استخدم BASE_URL من environment variables، وإلا استخدم default URL
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  // التحقق من أن الـ URL صحيح
  static bool isProductionUrl() {
    return baseUrl.startsWith('https://');
  }

  // Configuration للـ timeouts
  static const Duration requestTimeout = Duration(seconds: 30);

  // Configuration للـ retry logic
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);
}
