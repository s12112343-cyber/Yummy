import 'package:flutter/material.dart';

import '/../../models/recipe_details_model.dart';
import '/../../core/services/recipe_service.dart';

import 'recipe_details_page.dart';

class RecipeCardsSection extends StatefulWidget {
  final String searchText;

  final String selectedCuisine;

  final String selectedMealTime;

  final String selectedCookingTime;

  final String selectedNutritionFilter;

  final List<String> selectedDietTypes;

  final List<String> selectedIncludeIngredients;

  final List<String> selectedExcludeIngredients;

  final List<String> selectedMedicalDiets;

  final List<String> selectedFoodExceptions;

  const RecipeCardsSection({
    super.key,

    required this.searchText,

    required this.selectedCuisine,

    required this.selectedMealTime,

    required this.selectedCookingTime,

    required this.selectedNutritionFilter,

    required this.selectedDietTypes,

    required this.selectedIncludeIngredients,

    required this.selectedExcludeIngredients,

    required this.selectedMedicalDiets,

    required this.selectedFoodExceptions,
  });

  @override
  State<RecipeCardsSection> createState() => _RecipeCardsSectionState();
}

class _RecipeCardsSectionState extends State<RecipeCardsSection> {
  late Future<List<RecipeDetailsModel>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    _recipesFuture = _loadRecipes();
  }

  @override
  void didUpdateWidget(covariant RecipeCardsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.searchText != widget.searchText ||
        oldWidget.selectedCuisine != widget.selectedCuisine ||
        oldWidget.selectedDietTypes != widget.selectedDietTypes) {
      _recipesFuture = _loadRecipes();
    }
  }

  Future<List<RecipeDetailsModel>> _loadRecipes() {
    return RecipeService.getRecipes();
  }

  Future<void> _refreshRecipes() async {
    setState(() {
      _recipesFuture = _loadRecipes();
    });

    await _recipesFuture;
  }

  bool _matchesSearchText(String query, List<String> fields) {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) return true;

    final tokens = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    return tokens.any((token) {
      return fields.any((field) => field.toLowerCase().contains(token));
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RecipeDetailsModel>>(
      future: _recipesFuture,

      builder: (context, snapshot) {
        // =========================
        // LOADING
        // =========================

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // =========================
        // ERROR
        // =========================

        if (snapshot.hasError) {
          return const Center(
            child: Text(
              "Something went wrong 😭",
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        final recipes = snapshot.data ?? [];

        // =========================
        // FILTERING
        // =========================

        final filteredRecipes = recipes.where((recipe) {
          final title = recipe.title.toLowerCase();

          final cuisine = recipe.cuisine.toLowerCase();

          final dietType = recipe.dietType.toLowerCase();

          final ingredients = recipe.ingredients.join(" ").toLowerCase();

          final calories = recipe.calories;

          final protein = recipe.protein;

          final carbs = recipe.carbs;

          final fat = recipe.fat;

          // =====================
          // SEARCH
          // =====================

          final matchesSearch = _matchesSearchText(widget.searchText, [
            title,
            cuisine,
            dietType,
            ingredients,
            recipe.cookingTime,
            recipe.preparationTime,
          ]);

          // =====================
          // CUISINE
          // =====================

          final cleanCuisine = widget.selectedCuisine
              .replaceAll(RegExp(r'[^a-zA-Z ]'), '')
              .trim()
              .toLowerCase();

          final matchesCuisine =
              widget.selectedCuisine.isEmpty ||
              widget.selectedCuisine == 'All' ||
              cuisine.contains(cleanCuisine);

          // =====================
          // MEAL TIME
          // =====================

          bool matchesMealTime = true;

          final meal = widget.selectedMealTime.toLowerCase();

          if (meal.isNotEmpty) {
            if (meal.contains("breakfast")) {
              matchesMealTime =
                  title.contains("breakfast") ||
                  ingredients.contains("egg") ||
                  ingredients.contains("toast") ||
                  ingredients.contains("oats");
            } else if (meal.contains("lunch")) {
              matchesMealTime = calories >= 300;
            } else if (meal.contains("dinner")) {
              matchesMealTime = calories >= 500;
            } else if (meal.contains("snack")) {
              matchesMealTime = calories <= 250;
            } else if (meal.contains("dessert")) {
              matchesMealTime =
                  ingredients.contains("chocolate") ||
                  ingredients.contains("sugar") ||
                  title.contains("cake");
            } else if (meal.contains("drinks")) {
              matchesMealTime =
                  title.contains("drink") ||
                  title.contains("juice") ||
                  title.contains("smoothie");
            }
          }

          // =====================
          // INCLUDE INGREDIENTS
          // =====================

          final matchesIncludeIngredients =
              widget.selectedIncludeIngredients.isEmpty ||
              widget.selectedIncludeIngredients.any((ingredient) {
                final cleanIngredient = ingredient
                    .replaceAll(RegExp(r'[^a-zA-Z ]'), '')
                    .trim()
                    .toLowerCase();

                return ingredients.contains(cleanIngredient);
              });

          // =====================
          // EXCLUDE INGREDIENTS
          // =====================

          final matchesExcludeIngredients = !widget.selectedExcludeIngredients
              .any((ingredient) {
                final cleanIngredient = ingredient
                    .replaceAll(RegExp(r'[^a-zA-Z ]'), '')
                    .trim()
                    .toLowerCase();

                return ingredients.contains(cleanIngredient);
              });

          // =====================
          // DIETS
          // =====================

          bool matchesDiet = true;

          if (widget.selectedDietTypes.isNotEmpty) {
            matchesDiet = widget.selectedDietTypes.any((diet) {
              final cleanDiet = diet
                  .replaceAll(RegExp(r'[^a-zA-Z ]'), '')
                  .trim()
                  .toLowerCase();

              // VEGAN

              if (cleanDiet.contains("vegan")) {
                return !ingredients.contains("meat") &&
                    !ingredients.contains("chicken") &&
                    !ingredients.contains("egg") &&
                    !ingredients.contains("milk");
              }

              // VEGETARIAN

              if (cleanDiet.contains("vegetarian")) {
                return !ingredients.contains("chicken") &&
                    !ingredients.contains("beef") &&
                    !ingredients.contains("fish");
              }

              // KETO

              if (cleanDiet.contains("keto")) {
                return carbs <= 40;
              }

              // HIGH PROTEIN

              if (cleanDiet.contains("high protein")) {
                return protein >= 15;
              }

              // LOW CARB

              if (cleanDiet.contains("low carb")) {
                return carbs <= 40;
              }

              // HEALTHY

              if (cleanDiet.contains("healthy")) {
                return calories <= 600 && fat <= 25;
              }

              // BALANCED

              if (cleanDiet.contains("balanced")) {
                return protein >= 15 && carbs >= 20 && fat <= 25;
              }

              // WEIGHT LOSS

              if (cleanDiet.contains("weight loss")) {
                return calories <= 600;
              }

              // DETOX

              if (cleanDiet.contains("detox")) {
                return ingredients.contains("lemon") ||
                    ingredients.contains("avocado");
              }

              return title.contains(cleanDiet) ||
                  ingredients.contains(cleanDiet);
            });
          }

          // =====================
          // MEDICAL DIETS
          // =====================

          bool matchesMedical = true;

          if (widget.selectedMedicalDiets.isNotEmpty) {
            matchesMedical = widget.selectedMedicalDiets.every((diet) {
              final cleanDiet = diet
                  .replaceAll(RegExp(r'[^a-zA-Z ]'), '')
                  .trim()
                  .toLowerCase();

              if (cleanDiet.contains("diabetic")) {
                return carbs <= 45;
              }

              if (cleanDiet.contains("low sodium")) {
                return !ingredients.contains("salt");
              }

              if (cleanDiet.contains("gluten free")) {
                return !ingredients.contains("flour");
              }

              if (cleanDiet.contains("lactose free")) {
                return !ingredients.contains("milk");
              }

              return true;
            });
          }

          // =====================
          // FOOD EXCEPTIONS
          // =====================

          bool matchesFoodExceptions = true;

          if (widget.selectedFoodExceptions.isNotEmpty) {
            matchesFoodExceptions = widget.selectedFoodExceptions.every((food) {
              final cleanFood = food
                  .replaceAll(RegExp(r'[^a-zA-Z ]'), '')
                  .trim()
                  .toLowerCase();

              if (cleanFood.contains("nut free")) {
                return !ingredients.contains("nuts");
              }

              if (cleanFood.contains("dairy free")) {
                return !ingredients.contains("milk");
              }

              if (cleanFood.contains("egg free")) {
                return !ingredients.contains("egg");
              }

              if (cleanFood.contains("fish free")) {
                return !ingredients.contains("fish");
              }

              return true;
            });
          }

          // =====================
          // COOKING TIME
          // =====================

          final cookingMinutes =
              int.tryParse(
                recipe.cookingTime.replaceAll(RegExp(r'[^0-9]'), ''),
              ) ??
              0;

          bool matchesCookingTime = true;

          final cookingTime = widget.selectedCookingTime;

          if (cookingTime.isNotEmpty) {
            if (cookingTime.contains("15")) {
              matchesCookingTime = cookingMinutes <= 15;
            } else if (cookingTime.contains("30")) {
              matchesCookingTime = cookingMinutes <= 30;
            } else if (cookingTime.contains("60")) {
              matchesCookingTime = cookingMinutes <= 60;
            } else if (cookingTime.contains("1 hour")) {
              matchesCookingTime = cookingMinutes >= 60;
            }
          }

          // =====================
          // NUTRITION
          // =====================

          bool matchesNutrition = true;

          final nutrition = widget.selectedNutritionFilter;

          if (nutrition.isNotEmpty) {
            if (nutrition.contains("Low Calories")) {
              matchesNutrition = calories <= 600;
            } else if (nutrition.contains("High Calories")) {
              matchesNutrition = calories >= 700;
            } else if (nutrition.contains("High Protein")) {
              matchesNutrition = protein >= 15;
            } else if (nutrition.contains("Low Protein")) {
              matchesNutrition = protein <= 15;
            } else if (nutrition.contains("Low Carb")) {
              matchesNutrition = carbs <= 40;
            } else if (nutrition.contains("High Carb")) {
              matchesNutrition = carbs >= 50;
            } else if (nutrition.contains("Low Fat")) {
              matchesNutrition = fat <= 15;
            } else if (nutrition.contains("High Fat")) {
              matchesNutrition = fat >= 20;
            }
          }

          // =====================
          // FINAL
          // =====================

          return matchesSearch &&
              matchesCuisine &&
              matchesMealTime &&
              matchesDiet &&
              matchesMedical &&
              matchesFoodExceptions &&
              matchesIncludeIngredients &&
              matchesExcludeIngredients &&
              matchesCookingTime &&
              matchesNutrition;
        }).toList();

        // =========================
        // LIST
        // =========================

        return RefreshIndicator(
          onRefresh: _refreshRecipes,
          color: const Color(0xff1B3C73),
          child: filteredRecipes.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  children: const [
                    SizedBox(height: 140),
                    Center(
                      child: Text(
                        "No recipes found 😭",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: filteredRecipes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 20),
                  itemBuilder: (context, index) {
                    final recipe = filteredRecipes[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,

                          MaterialPageRoute(
                            builder: (context) =>
                                RecipeDetailsPage(recipe: recipe),
                          ),
                        );
                      },

                      child: Container(
                        height: 340,

                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),

                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xff1B3C73).withOpacity(0.14),

                              blurRadius: 22,

                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),

                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),

                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.network(
                                  recipe.image,
                                  fit: BoxFit.cover,
                                ),
                              ),

                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,

                                      end: Alignment.bottomCenter,

                                      colors: [
                                        Colors.black.withOpacity(0.10),

                                        Colors.black.withOpacity(0.25),

                                        Colors.black.withOpacity(0.70),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              Positioned(
                                left: 20,

                                right: 20,

                                bottom: 20,

                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,

                                  children: [
                                    Text(
                                      recipe.title,

                                      maxLines: 2,

                                      overflow: TextOverflow.ellipsis,

                                      style: const TextStyle(
                                        color: Colors.white,

                                        fontSize: 24,

                                        fontWeight: FontWeight.w900,

                                        height: 1.2,
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    Wrap(
                                      spacing: 10,

                                      runSpacing: 10,

                                      children: [
                                        _buildChip(recipe.cuisine),

                                        _buildChip(recipe.dietType),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),

        borderRadius: BorderRadius.circular(999),

        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),

      child: Text(
        text,

        style: const TextStyle(
          color: Colors.white,

          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
