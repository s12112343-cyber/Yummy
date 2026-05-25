import 'package:flutter/material.dart';
import '/../../models/recipe_details_model.dart';

class RecipeDetailsPage extends StatelessWidget {
  final RecipeDetailsModel recipe;

  const RecipeDetailsPage({super.key, required this.recipe});

  String cleanStepText(String text) {
    return text
        .replaceAll(RegExp(r'^step\s*\d+[:.-]?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\d+[:.-]?\s*'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F8FD),

      body: CustomScrollView(
        slivers: [
          // =====================
          // APP BAR
          // =====================
          SliverAppBar(
            expandedHeight: 320,

            pinned: true,

            backgroundColor: const Color(0xff1B3C73),

            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(recipe.image, fit: BoxFit.cover),
            ),
          ),

          // =====================
          // CONTENT
          // =====================
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // =====================
                  // TITLE
                  // =====================
                  Text(
                    recipe.title,

                    style: const TextStyle(
                      fontSize: 26,

                      fontWeight: FontWeight.w900,

                      color: Color(0xff1B3C73),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // =====================
                  // CHIPS
                  // =====================
                  Row(
                    children: [
                      _buildInfoChip(Icons.restaurant, recipe.cuisine),

                      const SizedBox(width: 10),

                      _buildInfoChip(
                        Icons.local_fire_department,

                        "${recipe.calories} kcal",
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // =====================
                  // COOKING INFO
                  // =====================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      _buildCookingInfo("Prep", recipe.preparationTime),

                      _buildCookingInfo("Cook", recipe.cookingTime),

                      _buildCookingInfo("Servings", recipe.servings.toString()),
                    ],
                  ),

                  const SizedBox(height: 35),

                  // =====================
                  // INGREDIENTS TITLE
                  // =====================
                  const Text(
                    "Ingredients",

                    style: TextStyle(
                      fontSize: 22,

                      fontWeight: FontWeight.w900,

                      color: Color(0xff1B3C73),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =====================
                  // INGREDIENTS LIST
                  // =====================
                  ...recipe.ingredients.map((ingredient) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),

                      padding: const EdgeInsets.all(14),

                      decoration: BoxDecoration(
                        color: Colors.white,

                        borderRadius: BorderRadius.circular(18),

                        border: Border.all(color: const Color(0xffE5EEF9)),
                      ),

                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Container(
                            width: 10,
                            height: 10,

                            margin: const EdgeInsets.only(top: 6),

                            decoration: const BoxDecoration(
                              color: Color(0xff1B3C73),

                              shape: BoxShape.circle,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              ingredient.toString(),

                              style: const TextStyle(
                                fontSize: 15,

                                height: 1.5,

                                fontWeight: FontWeight.w500,

                                color: Color(0xff2D3748),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 35),

                  // =====================
                  // COOKING STEPS TITLE
                  // =====================
                  const Text(
                    "Cooking Steps",

                    style: TextStyle(
                      fontSize: 22,

                      fontWeight: FontWeight.w900,

                      color: Color(0xff1B3C73),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =====================
                  // COOKING STEPS LIST
                  // =====================
                  ...recipe.cookingSteps
                      .asMap()
                      .entries
                      .where((step) {
                        final cleanedText = cleanStepText(
                          step.value.toString(),
                        );

                        return cleanedText.isNotEmpty;
                      })
                      .map((step) {
                        final cleanedText = cleanStepText(
                          step.value.toString(),
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),

                          padding: const EdgeInsets.all(16),

                          decoration: BoxDecoration(
                            color: Colors.white,

                            borderRadius: BorderRadius.circular(18),
                          ),

                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xff1B3C73),

                                child: Text(
                                  "${step.key + 1}",

                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),

                              const SizedBox(width: 14),

                              Expanded(
                                child: Text(
                                  cleanedText,

                                  style: const TextStyle(
                                    fontSize: 15,

                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                  const SizedBox(height: 35),

                  // =====================
                  // NUTRITION TITLE
                  // =====================
                  const Text(
                    "Nutrition",

                    style: TextStyle(
                      fontSize: 22,

                      fontWeight: FontWeight.w900,

                      color: Color(0xff1B3C73),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =====================
                  // NUTRITION GRID
                  // =====================
                  GridView(
                    shrinkWrap: true,

                    physics: const NeverScrollableScrollPhysics(),

                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,

                          crossAxisSpacing: 14,

                          mainAxisSpacing: 14,

                          childAspectRatio: 1.2,
                        ),

                    children: [
                      _buildNutritionCard("Calories", "${recipe.calories}"),

                      _buildNutritionCard("Protein", "${recipe.protein}g"),

                      _buildNutritionCard("Carbs", "${recipe.carbs}g"),

                      _buildNutritionCard("Fat", "${recipe.fat}g"),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xffEAF1FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xff1B3C73)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xff1B3C73),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCookingInfo(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xff1B3C73),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xff6B7A90),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionCard(String title, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xff1B3C73),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xff6B7A90),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
