class RecipeDetailsModel {
  final String id;

  final String title;

  final String image;

  final String cuisine;

  final String dietType;

  final String preparationTime;

  final String cookingTime;

  final int servings;

  final double rating;

  final int calories;

  final int protein;

  final int carbs;

  final int fat;

  final List<dynamic> ingredients;

  final List<dynamic> cookingSteps;

  RecipeDetailsModel({
    required this.id,

    required this.title,

    required this.image,

    required this.cuisine,

    required this.dietType,

    required this.preparationTime,

    required this.cookingTime,

    required this.servings,

    required this.rating,

    required this.calories,

    required this.protein,

    required this.carbs,

    required this.fat,

    required this.ingredients,

    required this.cookingSteps,
  });

  factory RecipeDetailsModel.fromJson(Map<String, dynamic> json) {
    return RecipeDetailsModel(
      // =========================
      // ID
      // =========================
      id: json["_id"]?.toString() ?? json["id"]?.toString() ?? "",

      // =========================
      // BASIC INFO
      // =========================
      title: json["title"] ?? "",

      image: json["image"] ?? "",

      cuisine: json["cuisine"] ?? "General",

      dietType: json["dietType"] ?? "Normal",

      // =========================
      // COOKING INFO
      // =========================
      preparationTime: json["preparationTime"] ?? "0 min",

      cookingTime: json["cookingTime"] ?? "0 min",

      servings: (json["servings"] ?? 0).toInt(),

      rating: (json["rating"] ?? 0).toDouble(),

      // =========================
      // NUTRITION
      // =========================
      calories: (json["calories"] ?? 0).toInt(),

      protein: (json["protein"] ?? 0).toInt(),

      carbs: (json["carbs"] ?? 0).toInt(),

      fat: (json["fat"] ?? 0).toInt(),

      // =========================
      // LISTS
      // =========================
      ingredients: json["ingredients"] ?? [],

      cookingSteps: json["cookingSteps"] ?? [],
    );
  }
}
