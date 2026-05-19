import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';

class MealService {
  MealService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  String _toDateKey(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> addMealsBatch({
    required String mealType,
    required DateTime date,
    required List<Map<String, dynamic>> meals,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/meals/batch'),
          headers: await _headers(),
          body: jsonEncode({
            'mealType': mealType,
            'dateKey': _toDateKey(date),
            'meals': meals,
          }),
        )
        .timeout(AppConfig.requestTimeout);

    final data = (jsonDecode(response.body) as Map<String, dynamic>);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message']?.toString() ?? 'Failed to save meals');
  }

  Future<Map<String, dynamic>> getDailySummary(DateTime date) async {
    final dateKey = _toDateKey(date);
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/meals/summary',
    ).replace(queryParameters: {'dateKey': dateKey});

    final response = await http
        .get(uri, headers: await _headers())
        .timeout(AppConfig.requestTimeout);

    final data = (jsonDecode(response.body) as Map<String, dynamic>);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ?? 'Failed to load daily meals',
    );
  }

  Future<Map<String, dynamic>> getPeriodSummary({
    String period = 'week',
  }) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/meals/summary/period',
    ).replace(queryParameters: {'period': period});

    final response = await http
        .get(uri, headers: await _headers())
        .timeout(AppConfig.requestTimeout);

    final data = (jsonDecode(response.body) as Map<String, dynamic>);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ?? 'Failed to load meal period summary',
    );
  }

  Future<Map<String, dynamic>> getPreviousMeals({int limit = 50}) async {
    final uri = Uri.parse(
      '${AppConfig.baseUrl}/meals/saved-foods',
    ).replace(queryParameters: {'limit': limit.toString()});

    final response = await http
        .get(uri, headers: await _headers())
        .timeout(AppConfig.requestTimeout);

    final data = (jsonDecode(response.body) as Map<String, dynamic>);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ?? 'Failed to load previous meals',
    );
  }

  Future<Map<String, dynamic>> analyzeQuickAddText({
    required String text,
    String? mealType,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/meals/quick-add/analyze'),
          headers: await _headers(),
          body: jsonEncode({
            'text': text,
            if (mealType != null && mealType.trim().isNotEmpty)
              'mealType': mealType.trim(),
          }),
        )
        .timeout(AppConfig.requestTimeout);

    final data = (jsonDecode(response.body) as Map<String, dynamic>);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message']?.toString() ?? 'Failed to analyze text');
  }

  Future<Map<String, dynamic>> analyzeImageAI({
    required File imageFile,
    String? mealType,
    String? note,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/meals/analyze-image-ai'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    if (mealType != null && mealType.trim().isNotEmpty) {
      request.fields['mealType'] = mealType.trim();
    }

    if (note != null && note.trim().isNotEmpty) {
      request.fields['note'] = note.trim();
    }

    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    final streamedResponse = await request.send().timeout(
      AppConfig.requestTimeout,
    );
    final response = await http.Response.fromStream(streamedResponse);

    final decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'raw': decoded};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ?? 'Failed to analyze meal photo',
    );
  }

  Future<Map<String, dynamic>> updateDailyWater({
    required DateTime date,
    required int consumedWaterMl,
    required int dailyWaterGoalMl,
    DateTime? lastDrinkTime,
  }) async {
    final response = await http
        .patch(
          Uri.parse('${AppConfig.baseUrl}/meals/water'),
          headers: await _headers(),
          body: jsonEncode({
            'dateKey': _toDateKey(date),
            'consumedWaterMl': consumedWaterMl,
            'dailyWaterGoalMl': dailyWaterGoalMl,
            'lastDrinkTime': lastDrinkTime?.toIso8601String(),
          }),
        )
        .timeout(AppConfig.requestTimeout);

    final data = (jsonDecode(response.body) as Map<String, dynamic>);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(data['message']?.toString() ?? 'Failed to update water');
  }
}
