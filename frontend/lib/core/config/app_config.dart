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
  static const List<String> youtubeApiKeys = [
    'AIzaSyAoJe2O-UWp2Ya-tbZlx0psed7XwRyEluA',
    'AIzaSyAJIq4xal4uDJ1l70H_WhVSiTVzKAu98wo',
    'AIzaSyC19wwCEOCoQgIkPOpooDtDvPsFjQAIm04',
    'AIzaSyADEmWelIw6QpkOV7s6nbaPhWw8jfxqs8Q',
    'AIzaSyC6HIFCCPQiAJltbOVznWNyLTob9DXWxrg',
  ];

  static final String youtubeApiKey = youtubeApiKeys.first;

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
