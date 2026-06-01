import 'package:flutter/material.dart';

import '/../../models/recipe_details_model.dart';
import '/../../core/services/favorite_service.dart';

import 'recipe_details_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() {
    super.initState();
    FavoriteService.loadFavorites();
  }

  RecipeDetailsModel _toRecipeModel(Map<String, dynamic> recipe) {
    return RecipeDetailsModel.fromJson(recipe);
  }

  Map<String, dynamic> _normalizeRecipe(Map<String, dynamic> recipe) {
    final id = (recipe['_id'] ?? recipe['id']).toString();
    return Map<String, dynamic>.from(recipe)
      ..['_id'] = id
      ..['id'] = id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F8FD),
      appBar: AppBar(
        title: const Text(
          'Favorites',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff1B3C73),
        elevation: 0,
      ),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: FavoriteService.favoriteRecipesDataNotifier,
        builder: (context, favorites, _) {
          if (favorites.isEmpty) {
            return const Center(
              child: Text(
                'No favorites yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: FavoriteService.loadFavorites,
            color: const Color(0xff1B3C73),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final recipe = _normalizeRecipe(favorites[index]);
                final model = _toRecipeModel(recipe);
                final isFavorite = FavoriteService.isFavoriteRecipe(model.id);

                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  elevation: 2,
                  shadowColor: const Color(0xff1B3C73).withOpacity(0.12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecipeDetailsPage(recipe: model),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(26),
                          ),
                          child: Stack(
                            children: [
                              Image.network(
                                model.image,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              Container(
                                height: 220,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.55),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 14,
                                right: 14,
                                child: _FavoriteChip(
                                  isFavorite: isFavorite,
                                  onTap: () async {
                                    await FavoriteService.toggleRecipe(recipe);
                                  },
                                ),
                              ),
                              Positioned(
                                left: 18,
                                right: 18,
                                bottom: 18,
                                child: Text(
                                  model.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _buildChip(model.cuisine),
                              _buildChip('${model.calories} kcal'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xffEEF4FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xff1B3C73),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FavoriteChip extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onTap;

  const _FavoriteChip({required this.isFavorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.96),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              key: ValueKey(isFavorite),
              color: isFavorite
                  ? const Color(0xffE53935)
                  : const Color(0xff1B3C73),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
