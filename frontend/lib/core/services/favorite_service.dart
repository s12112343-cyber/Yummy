import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteService {
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

  /// LOAD
  static Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();

    _favoriteRecipes = prefs.getStringList('favoriteRecipes')?.toSet() ?? {};

    _favoriteChefs = prefs.getStringList('favoriteChefs')?.toSet() ?? {};

    favoriteRecipesNotifier.value = Set.from(_favoriteRecipes);

    favoriteChefsNotifier.value = Set.from(_favoriteChefs);
  }

  static bool isFavoriteRecipe(String id) {
    return _favoriteRecipes.contains(id);
  }

  static bool isFavoriteChef(String id) {
    return _favoriteChefs.contains(id);
  }

  /// TOGGLE RECIPE
  static Future<void> toggleRecipe(Map<String, dynamic> recipe) async {
    final id = (recipe['_id'] ?? recipe['id']).toString();

    if (_favoriteRecipes.contains(id)) {
      _favoriteRecipes.remove(id);

      favoriteRecipesDataNotifier.value = favoriteRecipesDataNotifier.value
          .where((r) => (r['_id'] ?? r['id']).toString() != id)
          .toList();
    } else {
      _favoriteRecipes.add(id);

      // منع تكرار الكرتين
      final Map<String, dynamic> normalized = Map<String, dynamic>.from(recipe);

      favoriteRecipesDataNotifier.value = [
        ...{
          for (final r in [...favoriteRecipesDataNotifier.value, normalized])
            (r['_id'] ?? r['id']).toString(): r,
        }.values,
      ];
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList('favoriteRecipes', _favoriteRecipes.toList());

    favoriteRecipesNotifier.value = Set.from(_favoriteRecipes);
  }

  /// TOGGLE CHEF
  static Future<void> toggleChef(String chefId) async {
    if (_favoriteChefs.contains(chefId)) {
      _favoriteChefs.remove(chefId);
    } else {
      _favoriteChefs.add(chefId);
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList('favoriteChefs', _favoriteChefs.toList());

    favoriteChefsNotifier.value = Set.from(_favoriteChefs);
  }

  static Set<String> get favoriteRecipes => _favoriteRecipes;

  static Set<String> get favoriteChefs => _favoriteChefs;
}
