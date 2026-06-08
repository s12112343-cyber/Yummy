import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';

String _cleanForkifyIngredientLabel(String rawValue) {
  final value = rawValue.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (value.isEmpty) {
    return value;
  }

  final withoutLeadingAmount = value.replaceFirst(
    RegExp(
      r'^(?:\d+(?:/\d+)?(?:\.\d+)?(?:\s+\d+/\d+)?\s*)?(?:cup|cups|teaspoon|teaspoons|tablespoon|tablespoons|tbsp|tsp|pound|pounds|ounce|ounces|oz|gram|grams|kg|kilogram|kilograms|ml|milliliter|milliliters|liter|liters|pinch|pinches|clove|cloves|slice|slices|piece|pieces|small|medium|large|can|cans|bunch|handful|dash|dashs|pack|packs|package|packages)\b\s*',
      caseSensitive: false,
    ),
    '',
  );

  return withoutLeadingAmount.trim().isEmpty
      ? value
      : withoutLeadingAmount.trim();
}

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
    bool bypassRestrictions = false,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}/meals/batch'),
          headers: await _headers(),
          body: jsonEncode({
            'mealType': mealType,
            'dateKey': _toDateKey(date),
            'meals': meals,
            if (bypassRestrictions) 'bypassRestrictions': true,
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

  Future<Map<String, dynamic>> analyzePhotoAI({required File imageFile}) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.baseUrl}/meals/analyze-photo-ai'),
    );

    request.headers['Authorization'] = 'Bearer $token';
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
      final result = data['data'];
      if (result is Map<String, dynamic>) {
        return Map<String, dynamic>.from(result);
      }

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

  Future<Map<String, dynamic>> getMealReminders() async {
    final response = await http
        .get(
          Uri.parse('${AppConfig.baseUrl}/meals/reminders').replace(
            queryParameters: {
              'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes
                  .toString(),
            },
          ),
          headers: await _headers(),
        )
        .timeout(AppConfig.requestTimeout);

    final data = (jsonDecode(response.body) as Map<String, dynamic>);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ?? 'Failed to load meal reminders',
    );
  }

  Future<Map<String, dynamic>> updateMealReminders({
    required bool enabled,
    required List<Map<String, dynamic>> reminders,
  }) async {
    final response = await http
        .put(
          Uri.parse('${AppConfig.baseUrl}/meals/reminders'),
          headers: await _headers(),
          body: jsonEncode({
            'enabled': enabled,
            'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
            'reminders': reminders,
          }),
        )
        .timeout(AppConfig.requestTimeout);

    final data = (jsonDecode(response.body) as Map<String, dynamic>);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw Exception(
      data['message']?.toString() ?? 'Failed to update meal reminders',
    );
  }

  // ============================================================================
  // INGREDIENT FETCHING FROM INTERNET
  // ============================================================================

  /// Fetch ingredients for a recognized food/meal name from FoodData Central API
  Future<List<Map<String, dynamic>>> fetchIngredientsForMeal(
    String mealName,
  ) async {
    try {
      final searchResponse = await http
          .get(
            Uri.parse(
              'https://forkify-api.herokuapp.com/api/search',
            ).replace(queryParameters: {'q': mealName.trim()}),
          )
          .timeout(const Duration(seconds: 15));

      if (searchResponse.statusCode < 200 || searchResponse.statusCode >= 300) {
        return <Map<String, dynamic>>[];
      }

      final searchData =
          jsonDecode(searchResponse.body) as Map<String, dynamic>;
      final recipes =
          (searchData['recipes'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((recipe) => Map<String, dynamic>.from(recipe))
              .toList() ??
          <Map<String, dynamic>>[];

      if (recipes.isEmpty) {
        return <Map<String, dynamic>>[];
      }

      int scoreRecipe(Map<String, dynamic> recipe) {
        final title = (recipe['title'] ?? '').toString().toLowerCase().trim();
        final query = mealName.toLowerCase().trim();

        if (title == query) return 1000;
        var score = 0;
        for (final token in query.split(RegExp(r'\s+'))) {
          if (token.length >= 2 && title.contains(token)) {
            score += token.length * 10;
          }
        }
        if (title.contains(query) || query.contains(title)) {
          score += 200;
        }
        return score;
      }

      recipes.sort((a, b) {
        final scoreDiff = scoreRecipe(b).compareTo(scoreRecipe(a));
        if (scoreDiff != 0) return scoreDiff;
        final rankA = (a['social_rank'] is num)
            ? (a['social_rank'] as num).toDouble()
            : 0;
        final rankB = (b['social_rank'] is num)
            ? (b['social_rank'] as num).toDouble()
            : 0;
        return rankB.compareTo(rankA);
      });

      final selectedRecipe = recipes.first;
      final recipeId = selectedRecipe['recipe_id']?.toString();
      if (recipeId == null || recipeId.isEmpty) {
        return <Map<String, dynamic>>[];
      }

      final detailResponse = await http
          .get(
            Uri.parse(
              'https://forkify-api.herokuapp.com/api/get',
            ).replace(queryParameters: {'rId': recipeId}),
          )
          .timeout(const Duration(seconds: 15));

      if (detailResponse.statusCode < 200 || detailResponse.statusCode >= 300) {
        return <Map<String, dynamic>>[];
      }

      final detailData =
          jsonDecode(detailResponse.body) as Map<String, dynamic>;
      final recipe = detailData['recipe'] as Map<String, dynamic>?;
      final ingredients =
          (recipe?['ingredients'] as List<dynamic>?)?.map((entry) {
            final text = entry.toString().trim();
            final name = _cleanForkifyIngredientLabel(text);
            return {'name': name, 'quantity': '1', 'unit': 'unit'};
          }).toList() ??
          <Map<String, dynamic>>[];

      return ingredients;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
