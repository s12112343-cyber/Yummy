import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SavedService {
  static final ValueNotifier<List<Map<String, dynamic>>> savedRecipesNotifier =
      ValueNotifier([]);

  // ✅ LOAD
  static Future<void> loadSavedRecipes() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getStringList('savedRecipes') ?? [];

    savedRecipesNotifier.value = data
        .map((e) => Map<String, dynamic>.from(jsonDecode(e)))
        .toList();
  }

  // ✅ SAVE / REMOVE
  static Future<void> toggleSavedRecipe(Map<String, dynamic> recipe) async {
    final prefs = await SharedPreferences.getInstance();

    final current = List<Map<String, dynamic>>.from(savedRecipesNotifier.value);

    final id = (recipe['id'] ?? recipe['_id']).toString();

    final exists = current.any((e) => (e['id'] ?? e['_id']).toString() == id);

    if (exists) {
      current.removeWhere((e) => (e['id'] ?? e['_id']).toString() == id);
    } else {
      current.add(recipe);
    }

    savedRecipesNotifier.value = current;

    await prefs.setStringList(
      'savedRecipes',

      current.map((e) => jsonEncode(e)).toList(),
    );
  }

  // ✅ CHECK
  static bool isSavedRecipe(String id) {
    return savedRecipesNotifier.value.any(
      (e) => (e['id'] ?? e['_id']).toString() == id,
    );
  }
}
