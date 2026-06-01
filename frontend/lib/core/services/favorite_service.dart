import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'auth_service.dart';

class FavoriteService {
  static const String _favoriteRecipesKey = 'favoriteRecipes';
  static const String _favoriteChefsKey = 'favoriteChefs';
  static const String _favoriteRecipeDataKey = 'favoriteRecipesData';

  static Set<String> _favoriteRecipes = {};
  static Set<String> _favoriteChefs = {};

  /// ids
  static final ValueNotifier<Set<String>> favoriteRecipesNotifier =
      ValueNotifier({});

  static final ValueNotifier<Set<String>> favoriteChefsNotifier = ValueNotifier(
    {},
  );

  /// full recipe objects
  static final ValueNotifier<List<Map<String, dynamic>>>
  favoriteRecipesDataNotifier = ValueNotifier([]);

  static String _recipeIdOf(Map<String, dynamic> recipe) {
    return (recipe['_id'] ?? recipe['id']).toString();
  }

  static Map<String, dynamic> _normalizeRecipe(Map<String, dynamic> recipe) {
    return Map<String, dynamic>.from(recipe)
      ..['_id'] = _recipeIdOf(recipe)
      ..['id'] = _recipeIdOf(recipe);
  }

  static Future<void> _persistLocalFavorites() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_favoriteRecipesKey, _favoriteRecipes.toList());

    await prefs.setStringList(_favoriteChefsKey, _favoriteChefs.toList());

    await prefs.setStringList(
      _favoriteRecipeDataKey,
      favoriteRecipesDataNotifier.value.map(jsonEncode).toList(),
    );
  }

  static Future<void> _loadLocalFavorites() async {
    final prefs = await SharedPreferences.getInstance();

    _favoriteRecipes = prefs.getStringList(_favoriteRecipesKey)?.toSet() ?? {};
    _favoriteChefs = prefs.getStringList(_favoriteChefsKey)?.toSet() ?? {};

    final storedRecipes = prefs.getStringList(_favoriteRecipeDataKey) ?? [];
    favoriteRecipesDataNotifier.value = storedRecipes
        .map((item) => Map<String, dynamic>.from(jsonDecode(item)))
        .toList();

    favoriteRecipesNotifier.value = Set.from(_favoriteRecipes);
    favoriteChefsNotifier.value = Set.from(_favoriteChefs);
  }

  /// LOAD
  static Future<void> loadFavorites() async {
    await _loadLocalFavorites();

    final token = await AuthService().getToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/favorites'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final favorites = (data['favorites'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      _favoriteRecipes = favorites
          .map(
            (favorite) => (favorite['recipeId'] ?? favorite['id']).toString(),
          )
          .toSet();

      favoriteRecipesDataNotifier.value = favorites.map((favorite) {
        final recipe = favorite['recipe'];
        final map = recipe is Map
            ? Map<String, dynamic>.from(recipe)
            : <String, dynamic>{};
        return _normalizeRecipe(map);
      }).toList();

      favoriteRecipesNotifier.value = Set.from(_favoriteRecipes);
      await _persistLocalFavorites();
    } catch (_) {
      // Keep local cache if remote sync fails.
    }
  }

  static bool isFavoriteRecipe(String id) {
    return _favoriteRecipes.contains(id);
  }

  static bool isFavoriteChef(String id) {
    return _favoriteChefs.contains(id);
  }

  static Future<void> _syncRecipeToBackend({
    required bool isFavorite,
    required Map<String, dynamic> recipe,
  }) async {
    final token = await AuthService().getToken();
    if (token == null || token.trim().isEmpty) {
      return;
    }

    final id = _recipeIdOf(recipe);

    try {
      if (isFavorite) {
        await http.post(
          Uri.parse('${AppConfig.baseUrl}/favorites'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'recipeId': id,
            'recipe': _normalizeRecipe(recipe),
          }),
        );
      } else {
        await http.delete(
          Uri.parse('${AppConfig.baseUrl}/favorites/$id'),
          headers: {'Authorization': 'Bearer $token'},
        );
      }
    } catch (_) {
      // Local state still remains available.
    }
  }

  /// TOGGLE RECIPE
  static Future<void> toggleRecipe(Map<String, dynamic> recipe) async {
    final normalized = _normalizeRecipe(recipe);
    final id = _recipeIdOf(normalized);
    final exists = _favoriteRecipes.contains(id);

    if (exists) {
      _favoriteRecipes.remove(id);
      favoriteRecipesDataNotifier.value = favoriteRecipesDataNotifier.value
          .where((r) => _recipeIdOf(r) != id)
          .toList();
    } else {
      _favoriteRecipes.add(id);

      final merged = [
        ...favoriteRecipesDataNotifier.value.where((r) => _recipeIdOf(r) != id),
        normalized,
      ];

      favoriteRecipesDataNotifier.value = merged;
    }

    favoriteRecipesNotifier.value = Set.from(_favoriteRecipes);
    await _persistLocalFavorites();
    await _syncRecipeToBackend(isFavorite: !exists, recipe: normalized);
  }

  /// TOGGLE CHEF
  static Future<void> toggleChef(String chefId) async {
    if (_favoriteChefs.contains(chefId)) {
      _favoriteChefs.remove(chefId);
    } else {
      _favoriteChefs.add(chefId);
    }

    await _persistLocalFavorites();

    favoriteChefsNotifier.value = Set.from(_favoriteChefs);
  }

  static Set<String> get favoriteRecipes => _favoriteRecipes;

  static Set<String> get favoriteChefs => _favoriteChefs;
}
