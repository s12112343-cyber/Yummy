import 'package:flutter/material.dart';

class RecipeFilterScreen extends StatefulWidget {
  final String initialMealTime;
  final String initialCuisine;
  final String initialCookingTime;
  final String initialNutritionFilter;
  final List<String> initialIncludeIngredients;
  final List<String> initialExcludeIngredients;
  final List<String> initialDietTypes;
  final List<String> initialMedicalDiets;
  final List<String> initialFoodExceptions;

  const RecipeFilterScreen({
    super.key,
    this.initialMealTime = '',
    this.initialCuisine = '',
    this.initialCookingTime = '',
    this.initialNutritionFilter = '',
    this.initialIncludeIngredients = const [],
    this.initialExcludeIngredients = const [],
    this.initialDietTypes = const [],
    this.initialMedicalDiets = const [],
    this.initialFoodExceptions = const [],
  });

  @override
  State<RecipeFilterScreen> createState() => _RecipeFilterScreenState();
}

class _RecipeFilterScreenState extends State<RecipeFilterScreen> {
  static const Color navy = Color(0xff1B3C73);
  static const Color lightBg = Color(0xffF4F8FD);
  static const Color softBlue = Color(0xffEAF2FB);
  static const Color borderBlue = Color(0xffDDE7F3);
  static const Color textMuted = Color(0xff6B7A90);

  String selectedMealTime = "";
  String selectedCuisine = "";
  String selectedCookingTime = "";
  String selectedNutritionFilter = "";

  List<String> selectedIncludeIngredients = [];
  List<String> selectedExcludeIngredients = [];
  List<String> selectedDietTypes = [];
  List<String> selectedMedicalDiets = [];
  List<String> selectedFoodExceptions = [];

  @override
  void initState() {
    super.initState();

    selectedMealTime = widget.initialMealTime;
    selectedCuisine = widget.initialCuisine;
    selectedCookingTime = widget.initialCookingTime;
    selectedNutritionFilter = widget.initialNutritionFilter;

    selectedIncludeIngredients = List<String>.from(widget.initialIncludeIngredients);
    selectedExcludeIngredients = List<String>.from(widget.initialExcludeIngredients);
    selectedDietTypes = List<String>.from(widget.initialDietTypes);
    selectedMedicalDiets = List<String>.from(widget.initialMedicalDiets);
    selectedFoodExceptions = List<String>.from(widget.initialFoodExceptions);
  }

  final mealTimes = [
    "🌅 Breakfast",
    "☀️ Lunch",
    "🌙 Dinner",
    "🍪 Snack",
    "🥤 Drinks",
    "🍰 Dessert",
  ];

  final cuisines = [
    "🍕 Italian",
    "🌮 Mexican",
    "🍛 Indian",
    "🥡 Chinese",
    "🥙 Arabic",
    "🍣 Japanese",
    "🥘 Spanish",
    "🍔 American",
    "🥐 French",
    "🍢 Turkish",
    "🥗 Mediterranean",
    "🌶 Thai",
  ];

  final includeIngredients = [
    "🍗 Chicken",
    "🥩 Beef",
    "🐟 Salmon",
    "🦐 Shrimp",
    "🍚 Rice",
    "🍝 Pasta",
    "🧀 Cheese",
    "🍅 Tomato",
    "🥚 Eggs",
    "🥑 Avocado",
    "🍄 Mushroom",
    "🥦 Broccoli",
    "🌽 Corn",
    "🥔 Potato",
    "🧄 Garlic",
    "🧅 Onion",
    "🌶 Chili",
    "🥕 Carrot",
    "🥬 Lettuce",
    "🍋 Lemon",
  ];

  final nutritionFilters = [
    "🔥 Low Calories",
    "🍔 High Calories",
    "💪 High Protein",
    "🥩 Low Protein",
    "🥬 Low Carb",
    "🍞 High Carb",
    "🧈 Low Fat",
    "🍟 High Fat",
  ];

  final excludeIngredients = [
    "🥜 Nuts",
    "🥛 Dairy",
    "🥚 Eggs",
    "🌾 Gluten",
    "🦐 Seafood",
    "🐟 Fish",
    "🍯 Honey",
    "🍖 Pork",
    "🥩 Red Meat",
    "🌶 Spicy Food",
    "🍄 Mushroom",
    "🧈 Butter",
    "🧄 Garlic",
    "🧅 Onion",
  ];

  final diets = [
    "🥗 Vegetarian",
    "🌱 Vegan",
    "🥩 Keto",
    "💪 High Protein",
    "🥬 Low Carb",
    "❤️ Healthy",
    "🍞 Balanced",
    "⚡ High Energy",
    "🍃 Detox",
    "🔥 Weight Loss",
  ];

  final medicalDiets = [
    "🩸 Diabetic",
    "❤️ DASH",
    "🧠 MIND Diet",
    "🫀 Heart Healthy",
    "🌿 Anti-Inflammatory",
    "🩺 Low Sodium",
    "🦠 Low FODMAP",
    "⚕️ Gluten Free",
    "🥛 Lactose Free",
  ];

  final foodExceptions = [
    "🥜 Nut Free",
    "🌾 Gluten Free",
    "🥛 Dairy Free",
    "🍷 Alcohol Free",
    "🦐 Shellfish Free",
    "🐟 Fish Free",
    "🥚 Egg Free",
    "🍯 Honey Free",
    "🍖 Pork Free",
    "🌶 Mild Food",
  ];

  final cookingTimes = [
    "⚡ ≤ 15 min",
    "🔥 ≤ 30 min",
    "🍲 ≤ 60 min",
    "👨‍🍳 ≥ 1 hour",
  ];

  void toggleMultiSelect(List<String> list, String value) {
    setState(() {
      if (list.contains(value)) {
        list.remove(value);
      } else {
        list.add(value);
      }
    });
  }

  void toggleSingleSelect({
    required String currentValue,
    required String newValue,
    required Function(String) onChanged,
  }) {
    setState(() {
      if (currentValue == newValue) {
        onChanged("");
      } else {
        onChanged(newValue);
      }
    });
  }

  int get totalSelected {
    return [
      selectedMealTime,
      selectedCuisine,
      selectedCookingTime,
      selectedNutritionFilter,
    ].where((e) => e.isNotEmpty).length +
        selectedIncludeIngredients.length +
        selectedExcludeIngredients.length +
        selectedDietTypes.length +
        selectedMedicalDiets.length +
        selectedFoodExceptions.length;
  }

  void _clearAllFilters() {
    setState(() {
      selectedMealTime = "";
      selectedCuisine = "";
      selectedCookingTime = "";
      selectedNutritionFilter = "";
      selectedIncludeIngredients = [];
      selectedExcludeIngredients = [];
      selectedDietTypes = [];
      selectedMedicalDiets = [];
      selectedFoodExceptions = [];
    });

    Navigator.pop(context, {
      "mealTime": "",
      "cuisine": "All",
      "includeIngredients": <String>[],
      "excludeIngredients": <String>[],
      "diets": <String>[],
      "medicalDiets": <String>[],
      "foodExceptions": <String>[],
      "cookingTime": "",
      "nutritionFilter": "",
    });
  }

  void _applyFilters() {
    Navigator.pop(context, {
      "mealTime": selectedMealTime,
      "cuisine": selectedCuisine.isEmpty ? "All" : selectedCuisine,
      "includeIngredients": selectedIncludeIngredients,
      "excludeIngredients": selectedExcludeIngredients,
      "diets": selectedDietTypes,
      "medicalDiets": selectedMedicalDiets,
      "foodExceptions": selectedFoodExceptions,
      "cookingTime": selectedCookingTime,
      "nutritionFilter": selectedNutritionFilter,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        backgroundColor: lightBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: navy),
        title: const Text(
          "Recipe Filters",
          style: TextStyle(
            color: navy,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopCard(),
            const SizedBox(height: 18),

            _buildSingleSection(
              title: "Meal Time",
              subtitle: "Choose when you want to eat",
              items: mealTimes,
              selected: selectedMealTime,
              onTap: (value) {
                toggleSingleSelect(
                  currentValue: selectedMealTime,
                  newValue: value,
                  onChanged: (newValue) => selectedMealTime = newValue,
                );
              },
            ),

            _buildSingleSection(
              title: "Cuisines",
              subtitle: "Pick your favorite kitchen style",
              items: cuisines,
              selected: selectedCuisine,
              onTap: (value) {
                toggleSingleSelect(
                  currentValue: selectedCuisine,
                  newValue: value,
                  onChanged: (newValue) => selectedCuisine = newValue,
                );
              },
            ),

            _buildMultiSection(
              title: "Include Ingredients",
              subtitle: "Ingredients you want in your recipes",
              items: includeIngredients,
              selected: selectedIncludeIngredients,
              onTap: (value) {
                toggleMultiSelect(selectedIncludeIngredients, value);
              },
            ),

            _buildMultiSection(
              title: "Exclude Ingredients",
              subtitle: "Ingredients you prefer to avoid",
              items: excludeIngredients,
              selected: selectedExcludeIngredients,
              onTap: (value) {
                toggleMultiSelect(selectedExcludeIngredients, value);
              },
            ),

            _buildMultiSection(
              title: "Diet Types",
              subtitle: "Choose your lifestyle preference",
              items: diets,
              selected: selectedDietTypes,
              onTap: (value) {
                toggleMultiSelect(selectedDietTypes, value);
              },
            ),

            _buildMultiSection(
              title: "Medical Diets",
              subtitle: "Helpful filters for special conditions",
              items: medicalDiets,
              selected: selectedMedicalDiets,
              onTap: (value) {
                toggleMultiSelect(selectedMedicalDiets, value);
              },
            ),

            _buildMultiSection(
              title: "Food Exceptions",
              subtitle: "Remove recipes that do not fit you",
              items: foodExceptions,
              selected: selectedFoodExceptions,
              onTap: (value) {
                toggleMultiSelect(selectedFoodExceptions, value);
              },
            ),

            _buildSingleSection(
              title: "Cooking Time",
              subtitle: "How much time do you have?",
              items: cookingTimes,
              selected: selectedCookingTime,
              onTap: (value) {
                toggleSingleSelect(
                  currentValue: selectedCookingTime,
                  newValue: value,
                  onChanged: (newValue) => selectedCookingTime = newValue,
                );
              },
            ),

            _buildSingleSection(
              title: "Nutrition Goals",
              subtitle: "Filter recipes by nutrition target",
              items: nutritionFilters,
              selected: selectedNutritionFilter,
              onTap: (value) {
                toggleSingleSelect(
                  currentValue: selectedNutritionFilter,
                  newValue: value,
                  onChanged: (newValue) => selectedNutritionFilter = newValue,
                );
              },
            ),

            const SizedBox(height: 88),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
              ),
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Customize your recipes",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  totalSelected == 0
                      ? "Select filters to find better meals"
                      : "$totalSelected filters selected",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: borderBlue, width: 1.4),
                    backgroundColor: const Color(0xffF8FBFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _clearAllFilters,
                  child: const Text(
                    "Clear",
                    style: TextStyle(
                      color: navy,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _applyFilters,
                  child: const Text(
                    "Show Recipes",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSection({
    required String title,
    required String subtitle,
    required List<String> items,
    required String selected,
    required Function(String) onTap,
  }) {
    return _buildSectionContainer(
      title: title,
      subtitle: subtitle,
      selectedCount: selected.isEmpty ? 0 : 1,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) {
          final isSelected = selected == item;
          return _buildChip(
            text: item,
            isSelected: isSelected,
            onTap: () => onTap(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMultiSection({
    required String title,
    required String subtitle,
    required List<String> items,
    required List<String> selected,
    required Function(String) onTap,
  }) {
    return _buildSectionContainer(
      title: title,
      subtitle: subtitle,
      selectedCount: selected.length,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items.map((item) {
          final isSelected = selected.contains(item);
          return _buildChip(
            text: item,
            isSelected: isSelected,
            onTap: () => onTap(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required String subtitle,
    required int selectedCount,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffE5EEF8)),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: navy,
                  ),
                ),
              ),
              if (selectedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: softBlue,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    "$selectedCount selected",
                    style: const TextStyle(
                      color: navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              color: textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildChip({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? navy : const Color(0xffF7FAFE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? navy : borderBlue,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: navy.withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                text,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: isSelected ? Colors.white : navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 7),
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 17,
              ),
            ],
          ],
        ),
      ),
    );
  }
}