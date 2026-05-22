import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../api/edamam_api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/glass_text_field.dart';
import 'food_product_details_screen.dart';

final EdamamApiService _edamamApiService = EdamamApiService();

final Map<String, List<UsdaFoodItem>> _edamamQueryCache =
    <String, List<UsdaFoodItem>>{};

String _cacheKeyForQuery(String query) {
  return query.trim().toLowerCase();
}

// ============================================================================
// FOOD CATEGORY CLASSIFICATION SYSTEM
// ============================================================================

enum FoodCategory {
  liquids, // juice, milk, coffee, tea, soup, water, soda, etc.
  countable, // apple, banana, egg, orange, dates, etc.
  sliced, // pizza, cake, bread, toast, cheese, etc.
  dessert, // brownie, chocolate, kunafa, cookies, etc.
  bowl, // rice, oats, cereal, salad, pasta, etc.
  spoons, // oil, honey, jam, sauce, butter, etc.
  packaged, // chips, biscuit, yogurt, soda, snacks, etc.
  sandwich, // burger, sandwich, wrap, shawarma, etc.
  meat, // chicken, meat, steak, wing, breast, etc.
  general, // fallback/default category
}

class FoodCategoryClassifier {
  /// Keyword-to-category mapping for large dataset classification
  static const Map<FoodCategory, Set<String>> categoryKeywords = {
    FoodCategory.liquids: {
      'juice',
      'milk',
      'coffee',
      'tea',
      'soup',
      'water',
      'soda',
      'drink',
      'beverage',
      'smoothie',
      'shake',
      'latte',
      'cappuccino',
      'beer',
      'wine',
      'alcohol',
      'vodka',
      'rum',
      'whiskey',
      'cola',
      'carbonated',
      'seltzer',
      'coconut water',
      'almond milk',
      'oat milk',
      'broth',
      'stock',
      'sauce liquid',
    },
    FoodCategory.countable: {
      'apple',
      'banana',
      'orange',
      'egg',
      'dates',
      'blueberry',
      'strawberry',
      'kiwi',
      'pear',
      'peach',
      'plum',
      'grape',
      'tangerine',
      'lemon',
      'lime',
      'mango',
      'pineapple',
      'watermelon',
      'cantaloupe',
      'papaya',
      'avocado',
      'walnut',
      'almond',
      'cashew',
      'peanut',
      'hazelnut',
      'pistachio',
      'truffle',
      'meatball',
      'dumpling',
      'olive',
      'date',
      'fig',
    },
    FoodCategory.sliced: {
      'pizza',
      'cake',
      'bread',
      'toast',
      'cheese',
      'salami',
      'prosciutto',
      'ham',
      'bacon',
      'turkey',
      'salmon',
      'steak',
      'fish',
      'pork',
      'beef',
      'pancake',
      'waffle',
      'pie',
      'tart',
      'melon',
      'loaf',
      'baguette',
      'croissant',
      'cheddar',
      'mozzarella',
      'feta',
      'gouda',
    },
    FoodCategory.dessert: {
      'brownie',
      'chocolate',
      'kunafa',
      'baklava',
      'cookie',
      'biscuit',
      'donut',
      'doughnut',
      'cake',
      'pastry',
      'tart',
      'pudding',
      'mousse',
      'candy',
      'caramel',
      'fudge',
      'truffle',
      'macaron',
      'tiramisu',
      'cheesecake',
      'ice cream',
      'gelato',
      'popsicle',
      'candy bar',
      'chocolate bar',
      'granola bar',
      'protein bar',
    },
    FoodCategory.bowl: {
      'rice',
      'oats',
      'cereal',
      'salad',
      'pasta',
      'quinoa',
      'couscous',
      'barley',
      'millet',
      'lentil',
      'bean',
      'chickpea',
      'pea',
      'corn',
      'noodle',
      'ramen',
      'spaghetti',
      'lasagna',
      'risotto',
      'porridge',
      'oatmeal',
      'granola',
      'muesli',
      'gazpacho',
    },
    FoodCategory.spoons: {
      'oil',
      'honey',
      'jam',
      'sauce',
      'butter',
      'peanut butter',
      'almond butter',
      'tahini',
      'ghee',
      'lard',
      'mayo',
      'mayonnaise',
      'ketchup',
      'mustard',
      'vinegar',
      'soy sauce',
      'fish sauce',
      'sesame oil',
      'coconut oil',
      'olive oil',
      'yogurt',
      'sour cream',
      'cream cheese',
      'ricotta',
      'cottage cheese',
      'pesto',
    },
    FoodCategory.packaged: {
      'chips',
      'biscuit',
      'cookie',
      'cracker',
      'snack',
      'popcorn',
      'pretzel',
      'cereal',
      'granola',
      'trail mix',
      'nuts',
      'seeds',
      'yogurt',
      'pudding',
      'mousse',
      'soda',
      'energy drink',
      'protein shake',
      'candy',
      'chocolate',
      'bar',
      'packet',
      'box',
      'takeout',
      'instant',
    },
    FoodCategory.sandwich: {
      'burger',
      'sandwich',
      'wrap',
      'shawarma',
      'kebab',
      'taco',
      'burrito',
      'enchilada',
      'falafel',
      'sub',
      'panini',
      'hoagie',
      'pastrami',
      'deli',
      'club',
      'reuben',
    },
    FoodCategory.meat: {
      'chicken',
      'meat',
      'steak',
      'wing',
      'breast',
      'thigh',
      'leg',
      'drumstick',
      'beef',
      'pork',
      'lamb',
      'veal',
      'goat',
      'fish',
      'salmon',
      'tuna',
      'cod',
      'halibut',
      'trout',
      'shrimp',
      'prawn',
      'lobster',
      'crab',
      'scallop',
      'oyster',
      'mussel',
      'clam',
      'squid',
      'octopus',
      'duck',
      'turkey',
      'pheasant',
      'rabbit',
      'venison',
      'bison',
      'elk',
      'boar',
    },
  };

  /// Unit options by category
  static const Map<FoodCategory, List<String>> unitsByCategory = {
    FoodCategory.liquids: [
      'ml',
      'l',
      'cup',
      'glass',
      'bottle',
      'can',
      'tbsp',
      'tsp',
      'g',
    ],
    FoodCategory.countable: ['piece', 'small', 'medium', 'large', 'g'],
    FoodCategory.sliced: ['slice', 'thin_slice', 'piece', 'whole', 'g'],
    FoodCategory.dessert: ['piece', 'small_piece', 'large_piece', 'bar', 'g'],
    FoodCategory.bowl: ['cup', 'bowl', 'tbsp', 'tsp', 'g'],
    FoodCategory.spoons: ['tsp', 'tbsp', 'g'],
    FoodCategory.packaged: [
      'packet',
      'box',
      'bar',
      'bottle',
      'can',
      'container',
      'piece',
      'g',
    ],
    FoodCategory.sandwich: ['sandwich', 'wrap', 'loaf', 'piece', 'g'],
    FoodCategory.meat: [
      'piece',
      'breast',
      'thigh',
      'wing',
      'drumstick',
      'filet',
      'g',
    ],
    FoodCategory.general: ['serving', 'piece', 'g'],
  };

  /// Unit display labels
  static const Map<String, String> unitLabels = {
    // Liquids
    'ml': 'ml',
    'l': 'liter',
    'glass': 'glass',
    'bottle': 'bottle',
    'can': 'can',
    // Common
    'piece': 'piece',
    'cup': 'cup',
    'tbsp': 'tbsp',
    'tsp': 'tsp',
    'g': 'g',
    // Countable
    'small': 'small',
    'medium': 'medium',
    'large': 'large',
    // Sliced
    'slice': 'slice',
    'thin_slice': 'thin slice',
    'whole': 'whole',
    // Dessert
    'small_piece': 'small piece',
    'large_piece': 'large piece',
    'bar': 'bar',
    // Bowl
    'bowl': 'bowl',
    // Packaged
    'packet': 'packet',
    'box': 'box',
    'container': 'container',
    // Sandwich
    'sandwich': 'sandwich',
    'wrap': 'wrap',
    'loaf': 'loaf',
    // Meat
    'breast': 'breast',
    'thigh': 'thigh',
    'wing': 'wing',
    'drumstick': 'drumstick',
    'filet': 'filet',
    // Serving
    'serving': 'serving',
  };

  /// Unit gram value mappings
  static const Map<String, double> unitGramValues = {
    // Liquids (approximate ml -> grams for water-based)
    'ml': 1.0,
    'l': 1000.0,
    'glass': 250.0,
    'bottle': 500.0,
    'can': 330.0,
    // Common
    'piece': 120.0,
    'cup': 240.0,
    'tbsp': 15.0,
    'tsp': 5.0,
    'g': 1.0,
    // Countable
    'small': 80.0,
    'medium': 120.0,
    'large': 180.0,
    // Sliced
    'slice': 70.0,
    'thin_slice': 35.0,
    'whole': 200.0,
    // Dessert
    'small_piece': 50.0,
    'large_piece': 100.0,
    'bar': 40.0,
    // Bowl
    'bowl': 250.0,
    // Packaged
    'packet': 30.0,
    'box': 300.0,
    'container': 150.0,
    // Sandwich
    'sandwich': 200.0,
    'wrap': 180.0,
    'loaf': 50.0,
    // Meat
    'breast': 150.0,
    'thigh': 120.0,
    'wing': 80.0,
    'drumstick': 100.0,
    'filet': 140.0,
    // Serving
    'serving': 100.0,
  };

  /// Classify a food based on name, dataType, brand, and ingredients
  static FoodCategory classify(
    String name, {
    String? dataType,
    String? brand,
    String? ingredients,
  }) {
    final searchText =
        '$name ${dataType ?? ''} ${brand ?? ''} ${ingredients ?? ''}'
            .toLowerCase();

    // Check each category's keywords
    for (final entry in categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;

      // Count keyword matches
      int matchCount = 0;
      for (final keyword in keywords) {
        if (searchText.contains(keyword)) {
          matchCount++;
        }
      }

      // If we have strong signal (2+ matches), classify immediately
      if (matchCount >= 2) {
        return category;
      }

      // If we have a single strong match on a core word
      if (matchCount == 1) {
        // For category-defining keywords, trust the single match
        final primaryKeywords = _primaryKeywordsFor(category);
        for (final keyword in primaryKeywords) {
          if (searchText.contains(keyword)) {
            return category;
          }
        }
      }
    }

    // If no category matched, use general fallback
    return FoodCategory.general;
  }

  /// Get primary keywords for a category (strongest signals)
  static Set<String> _primaryKeywordsFor(FoodCategory category) {
    switch (category) {
      case FoodCategory.liquids:
        return {'juice', 'milk', 'coffee', 'tea', 'soup', 'water', 'soda'};
      case FoodCategory.countable:
        return {'apple', 'banana', 'egg', 'orange', 'dates'};
      case FoodCategory.sliced:
        return {'pizza', 'bread', 'cheese', 'steak'};
      case FoodCategory.dessert:
        return {'chocolate', 'cookie', 'brownie', 'cake'};
      case FoodCategory.bowl:
        return {'rice', 'oats', 'salad', 'pasta', 'cereal'};
      case FoodCategory.spoons:
        return {'oil', 'honey', 'butter', 'sauce', 'jam'};
      case FoodCategory.packaged:
        return {'chips', 'biscuit', 'yogurt', 'snack'};
      case FoodCategory.sandwich:
        return {'burger', 'sandwich', 'wrap', 'shawarma'};
      case FoodCategory.meat:
        return {'chicken', 'beef', 'steak', 'fish', 'meat'};
      case FoodCategory.general:
        return {};
    }
  }

  /// Get units for a given food
  static List<String> getUnitsForFood(
    String name, {
    String? dataType,
    String? brand,
    String? ingredients,
  }) {
    final category = classify(
      name,
      dataType: dataType,
      brand: brand,
      ingredients: ingredients,
    );
    return unitsByCategory[category] ?? unitsByCategory[FoodCategory.general]!;
  }

  /// Get unit label
  static String getUnitLabel(String unit) {
    return unitLabels[unit] ?? unit.replaceAll('_', ' ').toLowerCase();
  }

  /// Get gram value for a unit
  static double getUnitGramValue(String unit) {
    return unitGramValues[unit] ?? 100.0;
  }
}

class UsdaNutrient {
  final String name;
  final double value;
  final String unit;

  const UsdaNutrient({
    required this.name,
    required this.value,
    required this.unit,
  });
}

class RecipeIngredientItem {
  final String name;
  final double? weight;
  final String weightUnit;

  const RecipeIngredientItem({
    required this.name,
    this.weight,
    this.weightUnit = 'g',
  });
}

class UsdaFoodItem {
  final String? id;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String? ingredients;
  final String? dataType;
  final double calories;
  final double fat;
  final double protein;
  final double carbs;
  final double? weight;
  final String? weightUnit;
  final List<UsdaNutrient> nutrients;
  final List<RecipeIngredientItem> ingredientItems;

  const UsdaFoodItem({
    this.id,
    required this.name,
    this.brand,
    this.imageUrl,
    this.ingredients,
    this.dataType,
    required this.calories,
    required this.fat,
    required this.protein,
    required this.carbs,
    this.weight,
    this.weightUnit,
    this.nutrients = const [],
    this.ingredientItems = const [],
  });

  factory UsdaFoodItem.fromApi(Map<String, dynamic> hit) {
    final recipe = (hit['recipe'] as Map<String, dynamic>? ?? const {});
    final totalNutrients =
        (recipe['totalNutrients'] as Map<String, dynamic>? ?? const {});

    double nutrientByCode(String code) {
      final nutrient = totalNutrients[code];
      if (nutrient is! Map<String, dynamic>) return 0;
      final value = nutrient['quantity'];
      return value is num ? value.toDouble() : 0;
    }

    // قراءة القيم الغذائية: Edamam يرجع هذه القيم للوصفة كاملة (الوزن الكلي)
    double calories = nutrientByCode('ENERC_KCAL');
    double fat = nutrientByCode('FAT');
    double protein = nutrientByCode('PROCNT');
    double carbs = nutrientByCode('CHOCDF');

    // التحقق والتحويل: إذا كانت القيم كبيرة جداً، قد تكون بوحدة مختلفة
    // عادة Edamam يرجع الكالوري بـ kcal، لكن إذا كانت > 10000 قد تكون Joules
    if (calories > 10000) {
      calories = calories / 1000; // تحويل من Joules إلى kcal تقريباً
    }

    // الدهون والبروتين والكربوهيدرات عادة بـ g، لكن التحقق من المعقولية
    // إذا كانت > 1000 قد تكون بـ mg
    if (fat > 1000) fat = fat / 1000;
    if (protein > 1000) protein = protein / 1000;
    if (carbs > 1000) carbs = carbs / 1000;

    final nutrientList = totalNutrients.values
        .whereType<Map<String, dynamic>>()
        .map((nutrient) {
          final name = (nutrient['label'] ?? '').toString().trim();
          final value = nutrient['quantity'];
          final unit = (nutrient['unit'] ?? '').toString().trim();

          if (name.isEmpty || value is! num) return null;

          return UsdaNutrient(name: name, value: value.toDouble(), unit: unit);
        })
        .whereType<UsdaNutrient>()
        .toList(growable: false);

    final ingredients = (recipe['ingredients'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((ingredient) {
          // الاسم من 'food' (يمثل طبيعة المكون)
          final foodName = (ingredient['food'] ?? '').toString().trim();

          // الوزن الفعلي من 'weight' - يجب أن يكون بالجرام عادة
          final rawWeight = ingredient['weight'];
          double? parsedWeight;

          if (rawWeight is num && rawWeight > 0) {
            double weightValue = rawWeight.toDouble();

            // التحقق: إذا كان الوزن > 1000، غالباً يكون بالملج وليس جرام
            // لكن في Edamam عادة weight يكون بالجرام مباشرة
            // لا نحول إلا إذا كانت القيمة غير معقولة
            parsedWeight = weightValue;
          }

          // تخطي إذا لم يكن هناك اسم أو وزن
          if (foodName.isEmpty || parsedWeight == null) return null;

          return RecipeIngredientItem(
            name: foodName,
            weight: parsedWeight,
            weightUnit: 'g', // weight من Edamam دائماً بالجرام
          );
        })
        .whereType<RecipeIngredientItem>()
        .toList(growable: false);

    final ingredientLines = ingredients
        .map((item) => item.name)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final cuisineType = (recipe['cuisineType'] as List<dynamic>? ?? const [])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    // الوزن الكلي للوصفة - يجب أن يكون بالجرام
    final recipeWeight = recipe['totalWeight'];
    double? parsedRecipeWeight;

    if (recipeWeight is num && recipeWeight > 0) {
      double weightValue = recipeWeight.toDouble();
      // التحقق: إذا كان > 1000000، قد يكون بالملج
      if (weightValue > 1000000) {
        weightValue = weightValue / 1000; // تحويل من ملج إلى جرام
      }
      parsedRecipeWeight = weightValue;
    }

    return UsdaFoodItem(
      id: (recipe['uri'] ?? '').toString().trim().isEmpty
          ? null
          : (recipe['uri']).toString().trim(),
      name: (recipe['label'] ?? 'Unknown recipe').toString().trim(),
      brand: (recipe['source'] ?? '').toString().trim().isEmpty
          ? null
          : (recipe['source']).toString().trim(),
      imageUrl: (recipe['image'] ?? '').toString().trim().isEmpty
          ? null
          : (recipe['image']).toString().trim(),
      ingredients: ingredientLines.isEmpty ? null : ingredientLines.join(', '),
      dataType: cuisineType.isEmpty ? null : cuisineType.first,
      calories: calories,
      fat: fat,
      protein: protein,
      carbs: carbs,
      weight: parsedRecipeWeight,
      weightUnit: parsedRecipeWeight == null ? null : 'g',
      nutrients: nutrientList,
      ingredientItems: ingredients,
    );
  }
}

class EditableIngredient {
  String name;
  String weight;
  double calories;
  double protein;
  double fat;
  double carbs;
  bool isCustomAddition;

  EditableIngredient({
    required this.name,
    this.weight = '',
    this.calories = 0,
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
    this.isCustomAddition = false,
  });
}

class AddedNutrients {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? foodName;
  final double? gramsAdded;
  final double? confidence;

  const AddedNutrients({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.foodName,
    this.gramsAdded,
    this.confidence,
  });
}

typedef IngredientPortionSelected =
    void Function(UsdaFoodItem item, double grams);

class FoodSearchPanel extends StatefulWidget {
  final ValueChanged<UsdaFoodItem>? onFoodSelected;
  final ValueChanged<double>? onCaloriesAdded;
  final ValueChanged<AddedNutrients>? onNutrientsAdded;
  final ValueChanged<UsdaFoodItem>? onIngredientSelected;
  final IngredientPortionSelected? onIngredientPortionSelected;
  final VoidCallback? onClose;
  final int? dailyCalorieTarget;
  final int? dailyProteinTarget;
  final int? dailyFatTarget;
  final int? dailyCarbsTarget;
  final bool isIngredientMode;

  const FoodSearchPanel({
    super.key,
    this.onFoodSelected,
    this.onCaloriesAdded,
    this.onNutrientsAdded,
    this.onIngredientSelected,
    this.onIngredientPortionSelected,
    this.onClose,
    this.dailyCalorieTarget,
    this.dailyProteinTarget,
    this.dailyFatTarget,
    this.dailyCarbsTarget,
    this.isIngredientMode = false,
  });

  @override
  State<FoodSearchPanel> createState() => _FoodSearchPanelState();
}

class _FoodSearchPanelState extends State<FoodSearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  bool _isLoadingDefaultProducts = false;
  String? _errorText;
  String? _defaultProductsError;
  List<UsdaFoodItem> _results = const [];
  List<UsdaFoodItem> _defaultProducts = const [];
  String _lastRequestedQueryKey = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (!mounted) return;
      _onSearchChanged(_searchController.text);
      setState(() {});
    });
    _loadDefaultProductsFromApi();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _errorText = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 900), () {
      _searchFood(query);
    });
  }

  Future<void> _searchFood(String query) async {
    final key = _cacheKeyForQuery(query);

    final remainingLimit = _edamamApiService.remainingRateLimitDuration();
    if (remainingLimit > Duration.zero) {
      setState(() {
        _isLoading = false;
        _results = const [];
        _errorText =
            'Rate limit reached. Please wait ${remainingLimit.inSeconds}s and try again.';
      });
      return;
    }

    final cached = _edamamQueryCache[key];
    if (cached != null) {
      setState(() {
        _isLoading = false;
        _errorText = null;
        _results = cached;
      });
      return;
    }

    if (_isLoading && _lastRequestedQueryKey == key) {
      return;
    }

    if (!_edamamApiService.hasCredentials) {
      setState(() {
        _errorText =
            'Edamam credentials are missing. Run with --dart-define=EDAMAM_APP_ID=... --dart-define=EDAMAM_APP_KEY=...';
        _isLoading = false;
        _results = const [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    _lastRequestedQueryKey = key;

    final result = await _edamamApiService.searchRecipes(query);
    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _errorText = result.errorMessage;
        _isLoading = false;
        _results = const [];
      });
      return;
    }

    try {
      final parsed = result.hits
          .map(UsdaFoodItem.fromApi)
          .toList(growable: false);

      final normalizedQuery = _normalizedNameKey(query);
      final queryWords = normalizedQuery
          .split(' ')
          .where((word) => word.trim().isNotEmpty)
          .toList(growable: false);

      bool matchesByName(UsdaFoodItem item) {
        final normalizedName = _normalizedNameKey(item.name);
        if (normalizedName.isEmpty || queryWords.isEmpty) return false;

        if (normalizedName.startsWith(normalizedQuery)) return true;
        if (normalizedName.contains(' $normalizedQuery ')) return true;
        if (normalizedName.endsWith(' $normalizedQuery')) return true;
        if (normalizedName.contains('$normalizedQuery ')) return true;

        return queryWords.every(normalizedName.contains);
      }

      final strictNameMatches = parsed
          .where(matchesByName)
          .toList(growable: false);

      final sourceForResults = strictNameMatches.isNotEmpty
          ? strictNameMatches
          : parsed;

      final uniqueByName = <String, UsdaFoodItem>{};
      for (final item in sourceForResults) {
        final key = _normalizedNameKey(item.name);
        if (key.isEmpty) continue;
        uniqueByName.putIfAbsent(key, () => item);
      }

      final deduplicated = uniqueByName.values.toList(growable: false)
        ..sort((a, b) {
          final aName = _normalizedNameKey(a.name);
          final bName = _normalizedNameKey(b.name);
          final q = normalizedQuery;

          final aStarts = aName.startsWith(q) ? 0 : 1;
          final bStarts = bName.startsWith(q) ? 0 : 1;
          if (aStarts != bStarts) return aStarts - bStarts;

          final aContains = aName.contains(q) ? 0 : 1;
          final bContains = bName.contains(q) ? 0 : 1;
          if (aContains != bContains) return aContains - bContains;

          return aName.compareTo(bName);
        });

      final finalResults = deduplicated.take(12).toList(growable: false);
      _edamamQueryCache[key] = finalResults;

      setState(() {
        _results = finalResults;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorText = 'Could not fetch foods right now. Please try again.';
        _isLoading = false;
        _results = const [];
      });
    }
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _results = const [];
      _errorText = null;
    });
  }

  UsdaFoodItem? _pickBestQuickPick(List<UsdaFoodItem> items, String query) {
    final normalizedQuery = _normalizedNameKey(query);
    final queryWords = normalizedQuery
        .split(' ')
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);

    UsdaFoodItem? bestItem;
    int bestScore = -1;

    for (final item in items) {
      final normalizedName = _normalizedNameKey(item.name);
      if (normalizedName.isEmpty) {
        continue;
      }

      // Do not pick vegan/vegetarian variants unless the query asks for it.
      final asksForVegan =
          normalizedQuery.contains('vegan') ||
          normalizedQuery.contains('vegetarian');
      final isVeganVariant =
          normalizedName.contains('vegan') ||
          normalizedName.contains('vegetarian');
      if (!asksForVegan && isVeganVariant) {
        continue;
      }

      int score = 0;
      if (normalizedName == normalizedQuery) {
        score += 1000;
      }
      if (normalizedName.startsWith(normalizedQuery)) {
        score += 450;
      }
      if (normalizedName.contains(normalizedQuery)) {
        score += 400;
      }

      final matchingWords = queryWords
          .where((word) => normalizedName.contains(word))
          .length;
      score += matchingWords * 80;

      // Prefer tighter names over long noisy names.
      score -= (normalizedName.length - normalizedQuery.length).abs();

      if (score > bestScore) {
        bestScore = score;
        bestItem = item;
      }
    }

    return bestItem;
  }

  UsdaFoodItem _withDisplayName(UsdaFoodItem item, String displayName) {
    return UsdaFoodItem(
      id: item.id,
      name: displayName,
      brand: item.brand,
      imageUrl: item.imageUrl,
      ingredients: item.ingredients,
      dataType: item.dataType,
      calories: item.calories,
      fat: item.fat,
      protein: item.protein,
      carbs: item.carbs,
      weight: item.weight,
      weightUnit: item.weightUnit,
      nutrients: item.nutrients,
      ingredientItems: item.ingredientItems,
    );
  }

  Future<void> _loadDefaultProductsFromApi() async {
    if (_isLoadingDefaultProducts) return;

    setState(() {
      _isLoadingDefaultProducts = true;
      _defaultProductsError = null;
    });

    final loaded = <UsdaFoodItem>[];
    // Always include pizza margherita first
    const String pizzaQuery = 'pizza margherita';

    List<String> queriesToLoad = [pizzaQuery];

    for (final query in queriesToLoad) {
      List<UsdaFoodItem> items;
      final cacheKey = _cacheKeyForQuery(query);
      final cached = _edamamQueryCache[cacheKey];

      if (cached != null) {
        items = cached;
      } else {
        items = const [];
        final retryQueries = <String>[];

        // Add full query first
        retryQueries.add(query);

        // Add word variations with smart fallback per query
        final words = query
            .split(' ')
            .where((word) => word.trim().isNotEmpty)
            .toList();
        retryQueries.addAll(words);

        // Add specific fallbacks based on the query
        if (query.toLowerCase().contains('rice')) {
          retryQueries.addAll(['rice', 'white rice', 'brown rice']);
        }
        if (query.toLowerCase().contains('orange')) {
          retryQueries.addAll(['orange', 'orange juice', 'juice']);
        }
        if (query.toLowerCase().contains('egg')) {
          retryQueries.addAll(['egg', 'eggs', 'boiled egg']);
        }
        if (query.toLowerCase().contains('salad')) {
          retryQueries.addAll(['salad', 'garden salad']);
        }

        for (final retryQuery in retryQueries) {
          if (retryQuery.trim().isEmpty) continue;

          final result = await _edamamApiService.searchRecipes(retryQuery);
          if (!result.isSuccess) {
            continue;
          }

          final parsed = result.hits
              .map(UsdaFoodItem.fromApi)
              .toList(growable: false);
          if (parsed.isNotEmpty) {
            items = parsed;
            break;
          }
        }

        if (items.isNotEmpty) {
          _edamamQueryCache[cacheKey] = items;
        }
      }

      final itemsWithCalories = items
          .where((item) => item.calories > 0)
          .toList(growable: false);

      final bestItem = _pickBestQuickPick(
        itemsWithCalories.isNotEmpty ? itemsWithCalories : items,
        query,
      );

      // Prioritize items with actual calorie data
      if (bestItem != null && bestItem.calories > 0) {
        loaded.add(_withDisplayName(bestItem, query));
      } else if (itemsWithCalories.isNotEmpty) {
        loaded.add(_withDisplayName(itemsWithCalories.first, query));
      } else if (items.isNotEmpty) {
        final firstWithCalories = items.firstWhere(
          (item) => item.calories > 0,
          orElse: () => items.first,
        );
        loaded.add(_withDisplayName(firstWithCalories, query));
      }
    }

    if (!mounted) return;

    setState(() {
      _defaultProducts = loaded;
      _isLoadingDefaultProducts = false;
      if (loaded.isEmpty) {
        _defaultProductsError =
            'Could not load quick picks from API right now.';
      } else {
        _defaultProductsError = null;
      }
    });
  }

  String _normalizedNameKey(String input) {
    final firstPart = input.split(',').first;
    final normalized = firstPart
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized;
  }

  double _per100gValue(UsdaFoodItem item, double totalValue) {
    final recipeWeight = item.weight;
    if (recipeWeight == null || recipeWeight <= 0) return totalValue;
    return totalValue / recipeWeight * 100;
  }

  List<String> _wholeOptions() {
    return ['--', ...List<String>.generate(999, (i) => '${i + 1}')];
  }

  int _wholeIndexFromValue(int value) {
    if (value <= 0) return 0;
    if (value >= 999) return 999;
    return value;
  }

  int _wholeValueFromIndex(int index) {
    if (index <= 0) return 0;
    if (index >= 999) return 999;
    return index;
  }

  List<Map<String, dynamic>> _fractionOptions() {
    return const [
      {'label': '--', 'value': 0.0},
      {'label': '1/8', 'value': 0.125},
      {'label': '1/6', 'value': 1 / 6},
      {'label': '1/5', 'value': 0.2},
      {'label': '1/4', 'value': 0.25},
      {'label': '1/3', 'value': 1 / 3},
      {'label': '3/8', 'value': 0.375},
      {'label': '1/2', 'value': 0.5},
      {'label': '5/8', 'value': 0.625},
      {'label': '2/3', 'value': 2 / 3},
      {'label': '3/4', 'value': 0.75},
      {'label': '7/8', 'value': 0.875},
    ];
  }

  int _fractionIndexFromValue(double value) {
    final options = _fractionOptions();
    for (int i = 0; i < options.length; i++) {
      if (((options[i]['value'] as double) - value).abs() < 0.0001) {
        return i;
      }
    }
    return 0;
  }

  double _fractionValueFromIndex(int index) {
    final options = _fractionOptions();
    if (index < 0 || index >= options.length) return 0;
    return options[index]['value'] as double;
  }

  Future<void> _showIngredientPortionPicker(UsdaFoodItem item) async {
    int draftWhole = 1;
    double draftFraction = 0;
    final unitOptions = FoodCategoryClassifier.getUnitsForFood(
      item.name,
      dataType: item.dataType,
      brand: item.brand,
      ingredients: item.ingredients,
    );
    String draftUnit = unitOptions.isNotEmpty ? unitOptions.first : 'piece';

    final wholeController = FixedExtentScrollController(
      initialItem: _wholeIndexFromValue(draftWhole),
    );
    final fractionController = FixedExtentScrollController(
      initialItem: _fractionIndexFromValue(draftFraction),
    );
    final unitController = FixedExtentScrollController(
      initialItem: unitOptions.indexOf(draftUnit),
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD2D7E0),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 180,
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: wholeController,
                            itemExtent: 38,
                            onSelectedItemChanged: (index) {
                              setSheetState(() {
                                draftWhole = _wholeValueFromIndex(index);
                              });
                            },
                            children: _wholeOptions()
                                .map(
                                  (value) => Center(
                                    child: Text(
                                      value,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: fractionController,
                            itemExtent: 38,
                            onSelectedItemChanged: (index) {
                              setSheetState(() {
                                draftFraction = _fractionValueFromIndex(index);
                              });
                            },
                            children: _fractionOptions()
                                .map(
                                  (option) => Center(
                                    child: Text(
                                      option['label'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: unitController,
                            itemExtent: 38,
                            onSelectedItemChanged: (index) {
                              setSheetState(() {
                                if (index >= 0 && index < unitOptions.length) {
                                  draftUnit = unitOptions[index];
                                }
                              });
                            },
                            children: unitOptions
                                .map(
                                  (unit) => Center(
                                    child: Text(
                                      FoodCategoryClassifier.getUnitLabel(unit),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final quantity = draftWhole + draftFraction;
                        final safeQuantity = quantity <= 0 ? 1.0 : quantity;
                        final grams =
                            (FoodCategoryClassifier.getUnitGramValue(
                                      draftUnit,
                                    ) *
                                    safeQuantity)
                                .clamp(1.0, 3000.0)
                                .toDouble();

                        widget.onIngredientPortionSelected?.call(item, grams);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Add ingredient',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _quickAddFood(UsdaFoodItem item) {
    const gramsToAdd = 100.0;
    final addedCalories = _per100gValue(item, item.calories);
    final addedProtein = _per100gValue(item, item.protein);
    final addedCarbs = _per100gValue(item, item.carbs);
    final addedFat = _per100gValue(item, item.fat);

    widget.onCaloriesAdded?.call(addedCalories);
    widget.onNutrientsAdded?.call(
      AddedNutrients(
        calories: addedCalories,
        protein: addedProtein,
        carbs: addedCarbs,
        fat: addedFat,
        foodName: item.name,
        gramsAdded: gramsToAdd,
      ),
    );
  }

  Future<void> _openFoodDetails(UsdaFoodItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodProductDetailsScreen(
          item: item,
          dailyCalorieTarget: widget.dailyCalorieTarget,
          dailyProteinTarget: widget.dailyProteinTarget,
          dailyFatTarget: widget.dailyFatTarget,
          dailyCarbsTarget: widget.dailyCarbsTarget,
          onCaloriesAdded: widget.onCaloriesAdded,
          onNutrientsAdded: widget.onNutrientsAdded,
        ),
      ),
    );
  }

  Widget _buildFoodCard(UsdaFoodItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (widget.isIngredientMode) {
            _showIngredientPortionPicker(item);
          } else {
            _openFoodDetails(item);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.lightBlue.withOpacity(0.38)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (item.brand != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.brand!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.navy.withOpacity(0.62),
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          'CALORIES = ${_per100gValue(item, item.calories).toStringAsFixed(0)} KCAL / 100G',
                          style: TextStyle(
                            color: AppColors.navy.withOpacity(0.74),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      if (widget.isIngredientMode) {
                        // في وضع الإضافة كمكون فقط
                        widget.onIngredientSelected?.call(item);
                      } else {
                        // الوضع العادي: إضافة سريعة مباشرة من قائمة البحث
                        _quickAddFood(item);
                      }
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final shouldShowResultsArea = query.isNotEmpty;
    final showFixedDefaults = query.isEmpty;
    final showTopCloseForIntegration = widget.isIngredientMode;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTopCloseForIntegration)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 10),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.lightBlue.withOpacity(0.65),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    if (widget.onClose != null) {
                      widget.onClose!.call();
                    } else {
                      _clearSearch();
                    }
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
        SizedBox(height: showTopCloseForIntegration ? 12 : 0),
        Align(
          alignment: Alignment.center,
          child: FractionallySizedBox(
            widthFactor: 0.94,
            child: GlassTextField(
              label: '',
              hint: 'Type food name',
              controller: _searchController,
              keyboardType: TextInputType.text,
              prefixIcon: Icons.search_rounded,
              textAlign: TextAlign.left,
              suffix: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showFixedDefaults) ...[
          const SizedBox(height: 14),
          const Text(
            'Quick picks',
            style: TextStyle(
              color: AppColors.deepBlue,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          if (_isLoadingDefaultProducts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          else if (_defaultProductsError != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.caloriesBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.red.withOpacity(0.35)),
              ),
              child: Text(
                _defaultProductsError!,
                style: const TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Column(
              children: _defaultProducts
                  .map(_buildFoodCard)
                  .toList(growable: false),
            ),
        ],
        if (shouldShowResultsArea) ...[
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          else if (_errorText != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.caloriesBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.red.withOpacity(0.35)),
              ),
              child: Text(
                _errorText!,
                style: const TextStyle(
                  color: AppColors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (query.length < 2)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.babyBlueLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.lightBlue.withOpacity(0.75),
                ),
              ),
              child: const Text(
                'Start typing at least 2 letters to search for foods.',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (_results.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.babyBlueLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.lightBlue.withOpacity(0.75),
                ),
              ),
              child: const Text(
                'No foods found for this search.',
                style: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Column(
              children: _results.map(_buildFoodCard).toList(growable: false),
            ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: content,
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, const SizedBox(height: 10), content],
        );
      },
    );
  }
}
