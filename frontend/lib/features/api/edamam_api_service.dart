// This service integrates with Edamam Recipe Search API to fetch food/recipe
// results by query, handle credentials and rate-limit states, and provide
// normalized success/error responses for the Add Meal flow.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class EdamamFetchResult {
  final List<Map<String, dynamic>> hits;
  final String? errorMessage;

  const EdamamFetchResult({required this.hits, this.errorMessage});

  bool get isSuccess => errorMessage == null;
}

class EdamamApiService {
  static const String _appId = String.fromEnvironment(
    'EDAMAM_APP_ID',
    defaultValue: '540734dd',
  );
  static const String _appKey = String.fromEnvironment(
    'EDAMAM_APP_KEY',
    defaultValue: '13fae687fe6ebe46fae686540dcf277c',
  );

  DateTime? _rateLimitedUntil;

  bool get hasCredentials => _appId.isNotEmpty && _appKey.isNotEmpty;

  Duration remainingRateLimitDuration() {
    final until = _rateLimitedUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<EdamamFetchResult> searchRecipes(String query) async {
    final remainingLimit = remainingRateLimitDuration();
    if (remainingLimit > Duration.zero) {
      return EdamamFetchResult(
        hits: const [],
        errorMessage:
            'Rate limit reached. Please wait ${remainingLimit.inSeconds}s and try again.',
      );
    }

    if (!hasCredentials) {
      return const EdamamFetchResult(
        hits: [],
        errorMessage:
            'Edamam credentials are missing. Run with --dart-define=EDAMAM_APP_ID=... --dart-define=EDAMAM_APP_KEY=...',
      );
    }

    try {
      final uri = Uri.https('api.edamam.com', '/api/recipes/v2', {
        'type': 'public',
        'q': query,
        'app_id': _appId,
        'app_key': _appKey,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 20));

      if (response.statusCode == 429) {
        final retrySeconds = _retryAfterSeconds(response) ?? 60;
        _rateLimitedUntil = DateTime.now().add(Duration(seconds: retrySeconds));
        return EdamamFetchResult(
          hits: const [],
          errorMessage:
              'Too many requests. Please wait ${retrySeconds}s before searching again.',
        );
      }

      if (response.statusCode != 200) {
        return EdamamFetchResult(
          hits: const [],
          errorMessage: 'Search failed (${response.statusCode}). Try again.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final hits = (decoded['hits'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      return EdamamFetchResult(hits: hits);
    } on TimeoutException {
      return const EdamamFetchResult(
        hits: [],
        errorMessage: 'Request timeout. Please check your internet connection.',
      );
    } catch (_) {
      return const EdamamFetchResult(
        hits: [],
        errorMessage: 'Could not fetch foods right now. Please try again.',
      );
    }
  }

  int? _retryAfterSeconds(http.Response response) {
    final raw = response.headers['retry-after'];
    if (raw == null) return null;
    return int.tryParse(raw.trim());
  }
}
