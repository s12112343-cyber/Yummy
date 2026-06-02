import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';

class GeminiChatService {
  static Future<String> sendMessage({
    required String userMessage,
    required List<Map<String, String>> history,
    String? userProfileContext,
  }) async {
    final authService = AuthService();
    final token = await authService.getToken();

    final uri = Uri.parse('${AppConfig.baseUrl}/ai/gemini');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'userMessage': userMessage,
        'history': history,
        'userProfileContext': userProfileContext,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200 || data['success'] != true) {
      throw Exception(data['message'] ?? 'AI request failed');
    }

    return (data['answer'] ?? '').toString();
  }
}