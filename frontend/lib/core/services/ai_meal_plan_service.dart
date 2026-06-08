import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';

class AiMealPlanService {
  AiMealPlanService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  Future<Map<String, dynamic>> generateMealPlan({
    required String planType,
    required Map<String, dynamic> profile,
    required Map<String, dynamic> targets,
    required List<Map<String, dynamic>> mealTargets,
  }) async {
    try {
      final token = await _authService.getToken();

      final response = await http
          .post(
            Uri.parse('${AppConfig.baseUrl}/ai/meal-plan'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'planType': planType,
              'profile': profile,
              'targets': targets,
              'mealTargets': mealTargets,
            }),
          )
          .timeout(const Duration(seconds: 120));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200 || data['success'] != true) {
        final message = data['message']?.toString();
        throw Exception(
          message == null || message.isEmpty
              ? 'Failed to generate meal plan'
              : message,
        );
      }

      final plan = data['plan'];
      if (plan is! Map) {
        throw Exception('Invalid meal plan response');
      }

      return Map<String, dynamic>.from(plan);
    } on TimeoutException {
      throw Exception('AI meal plan took too long. Please try Daily first.');
    } on FormatException {
      throw Exception('Backend returned an invalid response.');
    }
  }
}
