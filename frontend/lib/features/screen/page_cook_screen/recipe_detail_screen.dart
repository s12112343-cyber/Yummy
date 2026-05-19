// 📁 lib/features/screen/page_cook_screen/recipe_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/services/cart_service.dart';
import '../../../core/services/favorite_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

String fullImageUrl(dynamic image) {
  if (image == null) return '';

  String img = image.toString().trim();

  if (img.isEmpty) return '';

  // ✅ لو الرابط كامل
  if (img.startsWith('http://') || img.startsWith('https://')) {
    return img;
  }

  // ✅ حذف localhost
  img = img.replaceAll('http://localhost:5000', '');

  img = img.replaceAll('http://127.0.0.1:5000', '');

  // ✅ تصليح uploads
  if (!img.startsWith('/uploads/')) {
    if (img.startsWith('uploads/')) {
      img = '/$img';
    } else {
      img = '/uploads/$img';
    }
  }

  final base = AppConfig.baseUrl.replaceAll('/api', '');

  return '$base$img';
}

class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  double _rating = 0;
  int _reviewsCount = 0;
  int _quantity = 1;
  bool _isFavorite = false;
  List<dynamic> liveReviews = [];

  bool loadingReviews = false;
  String get _recipeId =>
      (widget.recipe['_id'] ?? widget.recipe['id']).toString();
  @override
  void initState() {
    super.initState();

    _isFavorite = (widget.recipe['isFavorite'] ?? false);

    _rating = _readDouble(widget.recipe['rating'], fallback: 0);

    _loadRecipeReviews();
  }

  Future<void> _loadRecipeReviews() async {
    try {
      setState(() {
        loadingReviews = true;
      });

      final recipeId = _recipeId;
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/review-recipe/$recipeId'),
      );

      print('REVIEWS STATUS => ${response.statusCode}');

      print('REVIEWS BODY => ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          liveReviews = data['data'] ?? [];
          _reviewsCount = liveReviews.length;

          if (liveReviews.isNotEmpty) {
            _rating =
                liveReviews
                    .map((e) => _readDouble(e['rating'], fallback: 0))
                    .reduce((a, b) => a + b) /
                liveReviews.length;
          }
          loadingReviews = false;
        });
      } else {
        setState(() {
          loadingReviews = false;
        });
      }
    } catch (e) {
      print('LOAD REVIEWS ERROR => $e');

      setState(() {
        loadingReviews = false;
      });
    }
  }

  // ─── Size Selection ────────────────────────────────────────────────────────
  String _selectedSize = 'Medium';
  final Map<String, double> _sizePrices = {
    'Small': -2.00,
    'Medium': 0.00,
    'Large': 3.00,
  };

  // ─── Getters ───────────────────────────────────────────────────────────────
  String get _name => widget.recipe['name'] ?? 'Recipe';

  String get _imageUrl =>
      fullImageUrl(widget.recipe['image'] ?? widget.recipe['dishImage'] ?? '');
  int get _fat => _readInt(widget.recipe['fat'], fallback: 0);

  int get _calories => _readInt(widget.recipe['calories'], fallback: 0);

  int get _protein => _readInt(widget.recipe['protein'], fallback: 0);

  int get _potassium => _readInt(widget.recipe['potassium'], fallback: 0);
  double get _basePrice => _readDouble(widget.recipe['price'], fallback: 25.00);

  double get _sizeAdjustment => _sizePrices[_selectedSize] ?? 0.00;

  double get _adjustedPrice => _basePrice + _sizeAdjustment;

  double get _totalPrice => _adjustedPrice * _quantity;

  // ✅ Ingredients - من ـ API (List<String> من _extractIngredients)
  List<Map<String, String>> get _mainIngredients {
    List<Map<String, String>> ingredientsList = [];

    // جلب المكونات من الـ API (تكون في 'ingredients' key)
    final ingredientsData = widget.recipe['ingredients'];

    print('🔍 Ingredients from API: $ingredientsData');

    if (ingredientsData != null && ingredientsData is List) {
      for (var item in ingredientsData) {
        if (item is String) {
          // محاولة استخراج الكمية والاسم من النص (مثال: "200g Spaghetti")
          final parts = _parseIngredientString(item);
          ingredientsList.add({
            'name': parts['name'] ?? item,
            'quantity': parts['quantity'] ?? '',
          });
        } else if (item is Map) {
          ingredientsList.add({
            'name': item['name']?.toString() ?? 'Unknown',
            'quantity': item['quantity']?.toString() ?? '',
          });
        }
      }
    }

    // إذا لسا مافي مكونات، استخدم بيانات افتراضية
    if (ingredientsList.isEmpty) {
      print('⚠️ No ingredients found, using fallback data');
      return [
        {'name': 'Fresh ingredients', 'quantity': ''},
        {'name': 'Seasonings', 'quantity': ''},
        {'name': 'Herbs and spices', 'quantity': ''},
      ];
    }

    return ingredientsList;
  }

  // دالة مساعدة لاستخراج الكمية والاسم من نص مثل "200g Spaghetti"
  Map<String, String> _parseIngredientString(String text) {
    final RegExp regex = RegExp(
      r'^(\d+(?:\.\d+)?\s*(?:g|kg|ml|cup|cups|tbsp|tsp|oz|lb|slices|cloves|pieces)?)\s*(.+)$',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text.trim());

    if (match != null) {
      return {
        'quantity': match.group(1)?.trim() ?? '',
        'name': match.group(2)?.trim() ?? text,
      };
    }

    return {'quantity': '', 'name': text};
  }

  List<String> get _instructions {
    final instructions = widget.recipe['instructions'];
    if (instructions == null) return [];
    if (instructions is List<String>) return instructions;
    if (instructions is List<dynamic>) {
      return instructions.map((e) => e.toString()).toList();
    }
    if (instructions is String) {
      return instructions
          .split(RegExp(r'\.\s+|\n'))
          .where((step) => step.trim().isNotEmpty)
          .map((step) => step.trim())
          .toList();
    }
    return [];
  }

  List<Map<String, dynamic>> get _relatedRecipes {
    final related = widget.recipe['relatedRecipes'];
    if (related == null) return [];
    try {
      return (related as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  List<Map<String, dynamic>> get _reviews {
    final reviews = widget.recipe['reviews'];
    if (reviews == null) return [];
    try {
      return (reviews as List)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  void _toggleFavorite() async {
    await FavoriteService.toggleRecipe(widget.recipe);

    final id = (_recipeId).toString();

    setState(() {
      _isFavorite = FavoriteService.isFavoriteRecipe(id);
    });

    widget.recipe['favoriteChanged'] = true;
    widget.recipe['isFavorite'] = _isFavorite;

    HapticFeedback.lightImpact();
  }

  Future<void> _refreshRecipe() async {
    final response = await http.get(
      Uri.parse("${AppConfig.baseUrl}/recipes/$_recipeId"),
    );

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      setState(() {
        widget.recipe.addAll(data['data']);
      });
    }
  }

  Future<void> _addIngredientToSystem(
    String name,
    String cal,
    String fat,
    String protein,
    String pot,
  ) async {
    await http.post(
      Uri.parse("${AppConfig.baseUrl}/ingredients/add"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "calories": double.parse(cal.isEmpty ? "0" : cal),
        "fat": double.parse(fat.isEmpty ? "0" : fat),
        "protein": double.parse(protein.isEmpty ? "0" : protein),
        "potassium": double.parse(pot.isEmpty ? "0" : pot),
      }),
    );

    await _refreshRecipe();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ingredient added & updated 🔥")),
    );
  }

  void _addToCart() async {
    HapticFeedback.mediumImpact();
    final item = {
      ...widget.recipe,

      '_id': _recipeId,

      'id': _recipeId,

      'price': _adjustedPrice,

      'quantity': _quantity,

      'chefId': widget.recipe['chefId'],

      'chefName':
          widget.recipe['chef']?['name'] ?? widget.recipe['chefName'] ?? '',
    };

    await CartService.addItem(item);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to cart 🛒'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTopImageSection(),
                    Transform.translate(
                      offset: const Offset(0, -22),
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTitleAndRating(),
                              const SizedBox(height: 20),
                              _buildNutritionSection(),
                              const SizedBox(height: 24),
                              _buildIngredientsSection(), // 🔥 أضف هذا
                              // 🔥🔥 هذا المهم
                              const SizedBox(height: 24),

                              _buildSizeSelection(),
                              const SizedBox(height: 24),
                              _buildReviewsSection(),
                              const SizedBox(height: 32),

                              if (_relatedRecipes.isNotEmpty) ...[
                                _buildRelatedRecipesSection(),
                                const SizedBox(height: 32),
                              ],
                              const SizedBox(height: 22),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopImageSection() {
    return SizedBox(
      height: 330,
      width: double.infinity,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(34),
            ),
            child: SizedBox.expand(
              child: _imageUrl.isNotEmpty
                  ? Image.network(
                      _imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _imageFallback(),
                    )
                  : _imageFallback(),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: _circleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () {
                Navigator.pop(context, {
                  'favoriteChanged': widget.recipe['favoriteChanged'] ?? false,

                  'recipeId': _recipeId,

                  'isFavorite': _isFavorite,
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: onTap,
          child: Center(
            child: Icon(icon, size: 20, color: AppColors.royalBlue),
          ),
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.babyBlueLight, AppColors.lightBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 82,
          color: AppColors.royalBlue,
        ),
      ),
    );
  }

  void _showRatingDialog() {
    double selectedRating = 5;

    final TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),

          title: const Center(
            child: Text(
              "Write Review ⭐",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    // ⭐ STARS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedRating = index + 1.0;
                            });
                          },

                          child: Icon(
                            Icons.star_rounded,

                            size: 34,

                            color: index < selectedRating
                                ? Colors.amber
                                : Colors.grey.shade300,
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      "${selectedRating.toInt()} Stars",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: reviewController,

                      maxLines: 4,

                      decoration: InputDecoration(
                        hintText: "Write your review here...",

                        filled: true,

                        fillColor: Colors.grey.shade100,

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),

                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C4D8D),

                  foregroundColor: Colors.white,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),

                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,

                    vertical: 12,
                  ),
                ),

                onPressed: () async {
                  try {
                    final prefs = await SharedPreferences.getInstance();

                    final token = prefs.getString('token');

                    final response = await http.post(
                      Uri.parse("${AppConfig.baseUrl}/review-recipe"),
                      headers: {
                        "Content-Type": "application/json",

                        "Authorization": "Bearer $token",
                      },

                      body: jsonEncode({
                        "recipeId": _recipeId,
                        "rating": selectedRating,

                        "comment": reviewController.text,
                      }),
                    );

                    print("REVIEW STATUS => ${response.statusCode}");

                    print("REVIEW BODY => ${response.body}");

                    final data = jsonDecode(response.body);

                    if (response.statusCode == 200 ||
                        response.statusCode == 201) {
                      final newReview = {
                        "userName": "You",

                        "comment": reviewController.text,

                        "rating": selectedRating.toInt(),

                        "userImage": prefs.getString('profileImage') ?? "",
                      };

                      setState(() {
                        liveReviews.insert(0, newReview);

                        _reviewsCount = liveReviews.length;

                        _rating =
                            liveReviews
                                .map(
                                  (e) => _readDouble(e['rating'], fallback: 0),
                                )
                                .reduce((a, b) => a + b) /
                            liveReviews.length;
                      });
                      print(liveReviews);
                      Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Review submitted ⭐")),
                      );
                    }
                  } catch (e) {
                    print("REVIEW ERROR => $e");
                  }
                },

                child: const Text("Submit"),
              ),
            ),

            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget _buildTitleAndRating() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepBlue,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                  const SizedBox(width: 4),

                  Text(
                    _rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(width: 4),

                  Text(
                    '($_reviewsCount)',
                    style: TextStyle(fontSize: 12, color: AppColors.blueGray),
                  ),
                ],
              ),
            ],
          ),
        ),

        GestureDetector(
          onTap: _showRatingDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C4D8D),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: Colors.amber, size: 16),

                SizedBox(width: 5),

                Text(
                  "Write Review",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nutrition Quantity',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.deepBlue,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNutritionCircle(_fat, 'Fat', 'g'),
            _buildNutritionCircle(_calories, 'Calories', ''),
            _buildNutritionCircle(_potassium, 'Potassium', 'mg'),
            _buildNutritionCircle(_protein, 'Protein', 'g'),
          ],
        ),
      ],
    );
  }

  Widget _buildNutritionCircle(int value, String label, String unit) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0xFF1C4D8D).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C4D8D),
                  ),
                ),
                if (unit.isNotEmpty)
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1C4D8D).withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.blueGray,
          ),
        ),
      ],
    );
  }

  Widget _buildSizeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Size',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.deepBlue,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _sizePrices.keys.map((size) {
            final isSelected = _selectedSize == size;
            return GestureDetector(
              onTap: () => setState(() => _selectedSize = size),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1C4D8D) : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1C4D8D)
                        : AppColors.labelGray.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  size,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.deepBlue,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    if (loadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reviews',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.deepBlue,
          ),
        ),

        const SizedBox(height: 12),

        if (liveReviews.isEmpty)
          const Text(
            'No reviews yet',
            style: TextStyle(color: AppColors.blueGray, fontSize: 13),
          )
        else
          ...liveReviews.map((review) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,

                        backgroundImage:
                            review['userImage'] != null &&
                                review['userImage'].toString().isNotEmpty
                            ? NetworkImage(fullImageUrl(review['userImage']))
                            : null,

                        child:
                            review['userImage'] == null ||
                                review['userImage'].toString().isEmpty
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          review['userName'] ??
                              review['userId']?['name'] ??
                              'Anonymous',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepBlue,
                          ),
                        ),
                      ),

                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            Icons.star_rounded,
                            size: 14,
                            color:
                                index < _readInt(review['rating'], fallback: 0)
                                ? Colors.amber
                                : AppColors.labelGray,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    review['comment'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.blueGray,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildRelatedRecipesSection() {
    if (_relatedRecipes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'You May Also Like',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.deepBlue,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'See All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C4D8D),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _relatedRecipes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final recipe = _relatedRecipes[index];
              return GestureDetector(
                onTap: () {},
                child: Container(
                  width: 160,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: Container(
                          height: 90,
                          width: double.infinity,
                          color: AppColors.babyBlueLight,
                          child:
                              recipe['image'] != null &&
                                  recipe['image'].toString().isNotEmpty
                              ? Image.network(
                                  fullImageUrl(
                                    recipe['image'] ??
                                        recipe['dishImage'] ??
                                        '',
                                  ),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.restaurant,
                                    color: const Color(0xFF1C4D8D),
                                    size: 40,
                                  ),
                                )
                              : Icon(
                                  Icons.restaurant,
                                  color: const Color(0xFF1C4D8D),
                                  size: 40,
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe['name'] ?? 'Recipe',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.deepBlue,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${_readDouble(recipe['price'], fallback: 0).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1C4D8D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddIngredientDialog(String name) {
    final nameController = TextEditingController(text: name);
    final calController = TextEditingController();
    final fatController = TextEditingController();
    final proteinController = TextEditingController();
    final potController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Add Ingredient"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                // 🔥 AUTOCOMPLETE FIELD
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: name),
                  optionsBuilder: (TextEditingValue textEditingValue) async {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }

                    try {
                      final response = await http.get(
                        Uri.parse(
                          "${AppConfig.baseUrl}/ingredients/search?q=${textEditingValue.text}",
                        ),
                      );

                      final data = jsonDecode(response.body);

                      return data
                          .map<String>((e) => e['name'].toString())
                          .toList();
                    } catch (e) {
                      return const Iterable<String>.empty();
                    }
                  },
                  onSelected: (selection) async {
                    nameController.text = selection;

                    try {
                      final response = await http.get(
                        Uri.parse(
                          "${AppConfig.baseUrl}/ingredients/by-name?name=$selection",
                        ),
                      );

                      final data = jsonDecode(response.body);

                      if (data != null && data.isNotEmpty) {
                        calController.text = data['calories']?.toString() ?? '';
                        fatController.text = data['fat']?.toString() ?? '';
                        proteinController.text =
                            data['protein']?.toString() ?? '';
                        potController.text =
                            data['potassium']?.toString() ?? '';
                      }
                    } catch (e) {
                      print("❌ Error loading nutrition");
                    }
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onEditingComplete) {
                        controller.text = nameController.text;

                        return TextField(
                          controller: controller,
                          readOnly: true, // 🔥 هون

                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: "Ingredient Name",
                          ),
                        );
                      },
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: calController,
                  readOnly: true, // 🔥 هون

                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Calories"),
                ),

                TextField(
                  controller: fatController,
                  readOnly: true, // 🔥 هون

                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Fat"),
                ),

                TextField(
                  controller: proteinController,
                  readOnly: true, // 🔥 هون

                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Protein"),
                ),

                TextField(
                  controller: potController,
                  readOnly: true, // 🔥 هون

                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Potassium"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _addIngredientToSystem(
                  nameController.text,
                  calController.text,
                  fatController.text,
                  proteinController.text,
                  potController.text,
                );

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIngredientsSection() {
    final ingredients = _mainIngredients;

    if (ingredients.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingredients',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.deepBlue,
          ),
        ),
        const SizedBox(height: 12),

        ...ingredients.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: Colors.grey),
                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    item['name'] ?? '',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),

                if ((item['quantity'] ?? '').isNotEmpty)
                  Text(
                    item['quantity']!,
                    style: TextStyle(fontSize: 12, color: AppColors.blueGray),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Price',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blueGray,
                    ),
                  ),
                  Text(
                    '\$${_totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.deepBlue,
                    ),
                  ),
                ],
              ),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.labelGray.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _quantity > 1
                          ? () {
                              HapticFeedback.lightImpact();
                              setState(() => _quantity--);
                            }
                          : null,
                      icon: const Icon(Icons.remove, size: 18),
                      color: AppColors.blueGray,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                    ),
                    Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepBlue,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _quantity++);
                      },
                      icon: const Icon(Icons.add, size: 18),
                      color: AppColors.blueGray,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _addToCart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C4D8D),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'ADD TO CART',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _toggleFavorite,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.babyBlueLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.labelGray.withOpacity(0.2),
                    ),
                  ),
                  child: Icon(
                    _isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border_rounded,
                    color: _isFavorite ? Colors.red : AppColors.blueGray,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  int _readMinutes(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  int _readInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return double.tryParse(value.toString())?.toInt() ?? fallback;
  }

  double _readDouble(dynamic value, {required double fallback}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }
}
