import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '/../../models/recipe_details_model.dart';

class RecipeService {
  static Future<List<RecipeDetailsModel>> getRecipes({
    String searchText = "",
    String cuisine = "All",
    String dietType = "All",
  }) async {
    final uri = Uri.parse("${AppConfig.baseUrl}/external-recipes").replace(
      queryParameters: {
        if (searchText.trim().isNotEmpty) "search": searchText.trim(),
        if (cuisine != "All") "cuisine": cuisine,
        if (dietType != "All") "dietType": dietType,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("Failed to load recipes");
    }

    final data = jsonDecode(response.body);

    final List recipes = data["recipes"] ?? [];

    return recipes.map((e) => RecipeDetailsModel.fromJson(e)).toList();
  }

  static Future<RecipeDetailsModel> getRecipeById(String id) async {
    final response = await http.get(
      Uri.parse("${AppConfig.baseUrl}/external-recipes/$id"),
    );

    if (response.statusCode != 200) {
      throw Exception("Failed to load recipe details");
    }

    final data = jsonDecode(response.body);

    return RecipeDetailsModel.fromJson(data["recipe"]);
  }
}
