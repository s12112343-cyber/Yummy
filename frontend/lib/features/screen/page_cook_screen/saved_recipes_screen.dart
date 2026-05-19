import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/cart_service.dart';
import '../../../core/services/saved_service.dart';

import 'recipe_detail_screen.dart';
import 'chef_profile_screen.dart';

class SavedRecipesScreen extends StatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F8FA),

      appBar: AppBar(
        title: const Text(
          'Saved Recipes',

          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        backgroundColor: Colors.white,

        foregroundColor: Colors.black,

        elevation: 0,
      ),

      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: SavedService.savedRecipesNotifier,

        builder: (context, savedRecipes, _) {
          if (savedRecipes.isEmpty) {
            return const Center(child: Text('No saved recipes yet 😢'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),

            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,

              crossAxisSpacing: 12,

              mainAxisSpacing: 12,

              childAspectRatio: .70,
            ),

            itemCount: savedRecipes.length,

            itemBuilder: (context, index) {
              final recipe = savedRecipes[index];

              // ✅ FIX IMAGE
              recipe['image'] = recipe['image'] ?? recipe['dishImage'] ?? '';

              // ✅ FIX ID
              recipe['id'] = recipe['id'] ?? recipe['_id'];

              return PerfectRecipeCard(
                recipe: recipe,

                isFavorite: false,

                isSaved: true,

                onFavorite: () {},

                // ✅ REMOVE SAVED
                onSave: () async {
                  await SavedService.toggleSavedRecipe(recipe);

                  HapticFeedback.lightImpact();
                },

                // ✅ OPEN DETAILS
                onTap: () {
                  Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(recipe: recipe),
                    ),
                  );
                },

                // ✅ ADD TO CART
                onAddToCart: () async {
                  await CartService.addItem({...recipe, 'quantity': 1});

                  HapticFeedback.mediumImpact();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Added to cart 🛒'),

                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
