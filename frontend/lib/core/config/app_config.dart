const String _defaultBaseUrl = 'http://192.168.1.50:5000/api';

import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  static List<String> youtubeApiKeys = _youtubeKeysFromEnv();

  static List<String> _youtubeKeysFromEnv() {
    final raw = (dotenv.env['YOUTUBE_API_KEYS'] ?? '').trim();
    if (raw.isEmpty) return const [];

    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

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
