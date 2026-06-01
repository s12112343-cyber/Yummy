import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiChatService {
  // Default primary and fallback models
  static const String _geminiPrimaryModel = 'gemini-2.5-flash';
  static const String _geminiFallbackModel = 'gemini-2.5-flash-lite';

  static String _env(String key) => (dotenv.env[key] ?? '').trim();

  static List<String> _geminiKeys() {
    final keys = <String>[
      _env('GEMINI_API_KEY_PRIMARY'),
      _env('GEMINI_API_KEY_FALLBACK'),
    ].where((k) => k.isNotEmpty).toList(growable: false);

    return keys;
  }

  static List<String> _geminiModels() {
    final primary = _env('GEMINI_MODEL_PRIMARY');
    final fallback = _env('GEMINI_MODEL_FALLBACK');

    return <String>[
      primary.isNotEmpty ? primary : _geminiPrimaryModel,
      fallback.isNotEmpty ? fallback : _geminiFallbackModel,
    ];
  }

  static Uri _endpointForKeyAndModel(String key, String model) {
    return Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key',
    );
  }

  static Future<String> sendMessage({
    required String userMessage,
    required List<Map<String, String>> history,
    String? userProfileContext,
  }) async {
    final contents = <Map<String, dynamic>>[];

    for (final item in history) {
      final role = item['role'] ?? 'user';
      final text = item['text'] ?? '';
      if (text.trim().isEmpty) continue;
      contents.add({
        'role': role == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': text},
        ],
      });
    }

    Uri uriFor(String key, String model) => _endpointForKeyAndModel(key, model);
    // Helper to build a display string without the key
    String displayUriFor(Uri u) => u
        .replace(queryParameters: Map.from(u.queryParameters)..remove('key'))
        .toString();

    final profileContextText = (userProfileContext ?? '').trim();

    final payload = {
      'systemInstruction': {
        'parts': [
          {
            'text':
                'You are Yummy AI, a friendly cooking and nutrition assistant. Answer in concise, helpful language. If the user asks for recipes, suggest practical cooking ideas. If the user asks about ingredients or nutrition, keep answers simple and actionable.\n\nUse the following user profile context when relevant:\n${profileContextText.isEmpty ? 'No profile data available.' : profileContextText}\n\nWhen the user asks whether a meal fits their goals or health, answer directly based on this profile. If information is missing, say what is missing and give a best-effort answer.',
          },
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'topP': 0.9,
        'maxOutputTokens': 512,
      },
    };

    http.Response? response;
    final keys = _geminiKeys();
    if (keys.isEmpty) {
      throw Exception(
        'Missing Gemini API keys. Set GEMINI_API_KEY_PRIMARY (and optionally GEMINI_API_KEY_FALLBACK) in .env',
      );
    }

    final models = _geminiModels();

    const int maxAttemptsPerKey = 3;
    // Try models in order (primary -> fallback), and for each model try keys (primary -> fallback)
    for (var m = 0; m < models.length; m++) {
      final model = models[m];
      for (var k = 0; k < keys.length; k++) {
        final key = keys[k];
        final uri = uriFor(key, model);
        final display = displayUriFor(uri);
        final masked = key.length > 6
            ? '***${key.substring(key.length - 6)}'
            : '***';

        for (var attempt = 0; attempt < maxAttemptsPerKey; attempt++) {
          try {
            print(
              'Gemini request -> URL: $display (model=$model, using key $masked, ${k == 0 ? 'primary' : 'fallback'}, attempt=${attempt + 1})',
            );
            print('Gemini request -> payload: ${jsonEncode(payload)}');
            response = await http.post(
              uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            );
          } catch (e, st) {
            print(
              'Gemini request network error (model=$model, key=${k == 0 ? 'primary' : 'fallback'}, attempt=${attempt + 1}): $e',
            );
            print(st);
            if (attempt < maxAttemptsPerKey - 1) {
              final delaySec = 1 << attempt; // 1,2,4
              print('Retrying after ${delaySec}s...');
              await Future.delayed(Duration(seconds: delaySec));
              continue;
            } else {
              // last attempt for this key, move to next key
              break;
            }
          }

          // If we got a response
          if (response != null && response.statusCode == 200) {
            // success
            break;
          }

          // On 429 or 503, retry with exponential backoff if attempts remain
          if (response != null &&
              (response.statusCode == 429 || response.statusCode == 503)) {
            print(
              'Gemini returned ${response.statusCode} (model=$model, key=${k == 0 ? 'primary' : 'fallback'}, attempt=${attempt + 1})',
            );
            if (attempt < maxAttemptsPerKey - 1) {
              final delaySec = 1 << attempt;
              print('Retrying after ${delaySec}s...');
              await Future.delayed(Duration(seconds: delaySec));
              continue;
            } else {
              // exhausted attempts for this key, try next key
              break;
            }
          }

          // For other non-200 statuses, do not retry on this key
          break;
        }

        if (response != null && response.statusCode == 200) break;
        // otherwise try next key
      }

      if (response != null && response.statusCode == 200) break;
      // otherwise try next model
    }

    if (response == null) {
      throw Exception('No response from Gemini (network error)');
    }

    if (response.statusCode != 200) {
      final body = response.body.trim();
      print('Gemini response error -> status: ${response.statusCode}');
      print(
        'Gemini response error -> body: ${body.isEmpty ? '<empty>' : body}',
      );
      if (response.statusCode == 429) {
        // Friendly fallback for quota issues
        const fallback =
            'خدمة الذكاء الاصطناعي غير متاحة حالياً بسبب حصة الاستخدام. جرّب تفعيل الفوترة أو استخدم مفتاحًا آخر.';
        print('Gemini fallback -> $fallback');
        return fallback;
      }
      if (response.statusCode == 503) {
        const fallback =
            'خدمة الذكاء الاصطناعي مشغولة الآن. الرجاء المحاولة بعد قليل أو استخدام مفتاح/نموذج آخر.';
        print('Gemini fallback -> $fallback');
        return fallback;
      }
      throw Exception(
        'Gemini request failed (${response.statusCode}): ${body.isEmpty ? 'No response body' : body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      const fallback =
          'الرد غير متوفر حالياً من خدمة الذكاء الاصطناعي. هل تريد اقتراح وصفات بديلة؟';
      print('Gemini fallback -> no candidates, returning fallback');
      return fallback;
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    final buffer = StringBuffer();

    for (final part in parts) {
      final text = (part as Map)['text']?.toString() ?? '';
      if (text.isNotEmpty) buffer.write(text);
    }

    final answer = buffer.toString().trim();
    if (answer.isEmpty) {
      const fallback =
          'الرد غير متوفر حالياً من خدمة الذكاء الاصطناعي. هل تريد اقتراح وصفات بديلة؟';
      print('Gemini fallback -> empty parts, returning fallback');
      return fallback;
    }

    return answer;
  }
}
