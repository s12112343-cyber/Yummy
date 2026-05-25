import 'package:flutter/material.dart';
import 'package:frontend/core/config/app_config.dart';
import 'edit_recipe_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _kPrimaryDark = Color(0xFF0A1628);
const _kPrimaryLight = Color(0xFF3B82F6);
const _kAccent = Color(0xFF10B981);
const _kAccentOrange = Color(0xFFF59E0B);
const _kCard = Color(0xFFFFFFFF);
const _kBackground = Color(0xFFF8FAFC);
const _kText = Color(0xFF0F172A);
const _kTextSecondary = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);

class RecipeDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailsScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  String _selectedSize = 'Medium';
  List<dynamic> recipeReviews = [];

  bool loadingReviews = true;
  @override
  void initState() {
    super.initState();

    _loadRecipeReviews();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;

    final image = recipe['image'] ?? '';

    return Scaffold(
      backgroundColor: _kBackground,

      body: CustomScrollView(
        slivers: [
          // 🔥 APP BAR
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: _kPrimaryDark,

            actions: [
              // ✏️ EDIT
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),

                onPressed: () async {
                  final result = await Navigator.push(
                    context,

                    MaterialPageRoute(
                      builder: (_) => EditRecipeScreen(recipe: recipe),
                    ),
                  );

                  if (result == true && mounted) {
                    Navigator.pop(context, true);
                  }
                },
              ),

              const SizedBox(width: 8),
            ],

            flexibleSpace: FlexibleSpaceBar(
              background: image.toString().isNotEmpty
                  ? Image.network(
                      image.toString().startsWith('http')
                          ? image
                          : '${AppConfig.baseUrl.replaceAll('/api', '')}$image',

                      fit: BoxFit.cover,

                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: _kBackground,

                          child: const Center(
                            child: Icon(
                              Icons.restaurant,
                              size: 70,
                              color: _kPrimaryLight,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: _kBackground,

                      child: const Center(
                        child: Icon(
                          Icons.restaurant,
                          size: 70,
                          color: _kPrimaryLight,
                        ),
                      ),
                    ),
            ),
          ),

          // 🔥 BODY
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // 🔥 NAME
                  Text(
                    recipe['name'] ?? '',

                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _kText,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 🔥 DESCRIPTION
                  Text(
                    recipe['description'] ?? '',

                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: _kTextSecondary,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 🔥 PRICE
                  Container(
                    padding: const EdgeInsets.all(16),

                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(18),

                      border: Border.all(color: _kBorder),
                    ),

                    child: Row(
                      children: [
                        const Icon(Icons.attach_money_rounded, color: _kAccent),

                        const SizedBox(width: 10),

                        Text(
                          '${recipe['price'] ?? 0} \$',

                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _kAccent,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 🔥 NUTRITION
                  _buildNutritionSection(),

                  const SizedBox(height: 28),

                  // 🔥 INGREDIENTS
                  _buildIngredientsSection(),

                  const SizedBox(height: 28),

                  // 🔥 SIZE
                  _buildSizeSelection(),

                  const SizedBox(height: 30),
                  // 🔥 REVIEWS
                  _buildReviewsSection(),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadRecipeReviews() async {
    try {
      final recipeId = widget.recipe['_id'];

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/review-recipe/$recipeId'),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          recipeReviews = data['data'] ?? [];

          loadingReviews = false;
        });
      }
    } catch (e) {
      print(e);

      setState(() {
        loadingReviews = false;
      });
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/review-recipe/$reviewId'),

        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          recipeReviews.removeWhere((review) => review['_id'] == reviewId);
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Review deleted')));
      }
    } catch (e) {
      print(e);
    }
  }

  Widget _buildReviewsSection() {
    if (loadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (recipeReviews.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Recipe Reviews',

          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _kText,
          ),
        ),

        const SizedBox(height: 16),

        ...recipeReviews.map((review) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),

            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: _kCard,

              borderRadius: BorderRadius.circular(18),

              border: Border.all(color: _kBorder),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    const CircleAvatar(child: Icon(Icons.person)),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        review['userName'] ?? 'User',

                        style: const TextStyle(
                          fontWeight: FontWeight.bold,

                          color: _kText,
                        ),
                      ),
                    ),

                    IconButton(
                      onPressed: () {
                        _deleteReview(review['_id']);
                      },

                      icon: const Icon(Icons.delete_rounded, color: Colors.red),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: List.generate(
                    5,

                    (index) => Icon(
                      Icons.star_rounded,

                      size: 16,

                      color: index < review['rating']
                          ? Colors.amber
                          : Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Text(review['comment'] ?? ''),
              ],
            ),
          );
        }),
      ],
    );
  }

  // 🔥 NUTRITION SECTION
  Widget _buildNutritionSection() {
    final recipe = widget.recipe;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Nutrition',

          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _kText,
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            _buildNutritionCard(
              '${recipe['calories'] ?? 0}',
              'Calories',
              Colors.red,
            ),

            _buildNutritionCard(
              '${recipe['protein'] ?? 0}',
              'Protein',
              _kPrimaryLight,
            ),

            _buildNutritionCard('${recipe['fat'] ?? 0}', 'Fat', _kAccentOrange),

            _buildNutritionCard(
              '${recipe['carbs'] ?? recipe['potassium'] ?? 0}',
              'Carbs',
              _kAccent,
            ),
          ],
        ),
      ],
    );
  }

  // 🔥 NUTRITION CARD
  Widget _buildNutritionCard(String value, String title, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),

          border: Border.all(color: _kBorder),
        ),

        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.1),

              child: Text(
                value,

                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              title,

              style: const TextStyle(fontSize: 11, color: _kTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 INGREDIENTS
  Widget _buildIngredientsSection() {
    final recipe = widget.recipe;

    final ingredients = List<Map<String, dynamic>>.from(
      recipe['ingredients'] ?? [],
    );

    if (ingredients.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const Text(
          'Ingredients',

          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _kText,
          ),
        ),

        const SizedBox(height: 16),

        ...ingredients.map((ingredient) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),

            padding: const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),

              border: Border.all(color: _kBorder),
            ),

            child: Row(
              children: [
                const Icon(Icons.circle, size: 10, color: _kAccent),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    '${ingredient['quantity']} ${ingredient['unit']} ${ingredient['name']}',

                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _kText,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // 🔥 SIZE
  Widget _buildSizeSelection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start);
  }

  // 🔥 INFO CARD
  Widget _buildInfoCard(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(18),

          border: Border.all(color: _kBorder),
        ),

        child: Column(
          children: [
            Icon(icon, color: color),

            const SizedBox(height: 8),

            Text(
              value,

              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _kText,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              label,

              style: const TextStyle(fontSize: 12, color: _kTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
