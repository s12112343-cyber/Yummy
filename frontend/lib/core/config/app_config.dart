const String _defaultBaseUrl = 'http://192.168.1.50:5000/api';

class AppConfig {
  // ==============================
  // Backend Base URL
  // ==============================
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  // ==============================
  // YouTube API Key
  // ==============================
  static const String youtubeApiKey = "AIzaSyBHKVYKD7xAyIz7y0YFO7KBH3QGWrQp4UQ";

  // ==============================
  // Helpers
  // ==============================
  static bool isProductionUrl() {
    return baseUrl.startsWith('https://');
  }

  // ==============================
  // Request Timeout
  // ==============================
  static const Duration requestTimeout = Duration(seconds: 30);

  // ==============================
  // Retry Configuration
  // ==============================
  static const int maxRetries = 3;

  static const Duration retryDelay = Duration(seconds: 1);
}