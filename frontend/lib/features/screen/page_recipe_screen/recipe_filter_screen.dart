import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/core/config/app_config.dart';

class RecipeFilterScreen extends StatefulWidget {
  final String initialMealTime;
  final String initialCuisine;
  final String initialCookingTime;
  final String initialNutritionFilter;
  final List<String> initialIncludeIngredients;
  final List<String> initialExcludeIngredients;
  final List<String> initialDietTypes;
  final List<String> initialMedicalDiets;

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
  });

  @override
  State<RecipeFilterScreen> createState() => _RecipeFilterScreenState();
}

class _RecipeFilterScreenState extends State<RecipeFilterScreen> {
  static const Color navy = Color(0xff1B3C73);
  static const Color lightBg = Color(0xffF4F8FD);
  static const Color softBlue = Color(0xffEAF2FB);
  static const Color borderBlue = Color(0xffDDE7F3);
  String selectedMealTime = '';
  String selectedCuisine = '';
  String selectedCookingTime = '';
  String selectedNutritionFilter = '';

  List<String> selectedIncludeIngredients = [];
  List<String> selectedExcludeIngredients = [];
  List<String> selectedDietTypes = [];
  List<String> selectedMedicalDiets = [];

  final mealTimes = const [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
    'Drinks',
    'Dessert',
  ];

  final cuisines = const [
    'Italian',
    'Mexican',
    'Indian',
    'Chinese',
    'Arabic',
    'Japanese',
    'Spanish',
    'American',
    'French',
    'Turkish',
    'Mediterranean',
    'Thai',
  ];

  final includeIngredients = const [
    'Chicken',
    'Beef',
    'Salmon',
    'Shrimp',
    'Rice',
    'Pasta',
    'Cheese',
    'Tomato',
    'Eggs',
    'Avocado',
    'Mushroom',
    'Broccoli',
    'Corn',
    'Potato',
    'Garlic',
    'Onion',
    'Chili',
    'Carrot',
    'Lettuce',
    'Lemon',
  ];

  final excludeIngredients = const [
    'Pork',
    'Red Meat',
    'Spicy Food',
    'Mushroom',
    'Butter',
    'Garlic',
    'Onion',
    'Nuts',
    'Gluten',
    'Dairy',
    'Alcohol',
    'Shellfish',
    'Fish',
    'Eggs',
    'Honey',
  ];

  final diets = const [
    'Vegetarian',
    'Vegan',
    'Keto',
    'Balanced',
    'High Energy',
    'Detox',
  ];

  final medicalDiets = const [
    'Diabetic',
    'DASH',
    'MIND Diet',
    'Heart Healthy',
    'Anti-Inflammatory',
    'Low Sodium',
    'Low FODMAP',
  ];

  final cookingTimes = const ['≤ 15 min', '≤ 30 min', '≤ 60 min', '>= 1 hour'];

  final nutritionFilters = const [
    'Low Calories',
    'High Calories',
    'High Protein',
    'Low Protein',
    'Low Carb',
    'High Carb',
    'Low Fat',
    'High Fat',
  ];

  @override
  void initState() {
    super.initState();

    selectedMealTime = widget.initialMealTime;
    selectedCuisine = widget.initialCuisine;
    selectedCookingTime = widget.initialCookingTime;
    selectedNutritionFilter = widget.initialNutritionFilter;

    selectedIncludeIngredients = List<String>.from(
      widget.initialIncludeIngredients,
    );
    selectedExcludeIngredients = List<String>.from(
      widget.initialExcludeIngredients,
    );
    selectedDietTypes = List<String>.from(widget.initialDietTypes);
    selectedMedicalDiets = List<String>.from(widget.initialMedicalDiets);
  }

  void toggleMultiSelect(List<String> list, String value) {
    if (!mounted) return;

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
    if (!mounted) return;

    setState(() {
      if (currentValue == newValue) {
        onChanged('');
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
        selectedMedicalDiets.length;
  }

  void _clearAllFilters() {
    if (!mounted) return;

    setState(() {
      selectedMealTime = '';
      selectedCuisine = '';
      selectedCookingTime = '';
      selectedNutritionFilter = '';
      selectedIncludeIngredients = [];
      selectedExcludeIngredients = [];
      selectedDietTypes = [];
      selectedMedicalDiets = [];
    });

    Navigator.pop(context, {
      'mealTime': '',
      'cuisine': 'All',
      'includeIngredients': <String>[],
      'excludeIngredients': <String>[],
      'diets': <String>[],
      'medicalDiets': <String>[],
      'cookingTime': '',
      'nutritionFilter': '',
    });
  }

  void _applyFilters() {
    Navigator.pop(context, {
      'mealTime': selectedMealTime,
      'cuisine': selectedCuisine.isEmpty ? 'All' : selectedCuisine,
      'includeIngredients': selectedIncludeIngredients,
      'excludeIngredients': selectedExcludeIngredients,
      'diets': selectedDietTypes,
      'medicalDiets': selectedMedicalDiets,
      'cookingTime': selectedCookingTime,
      'nutritionFilter': selectedNutritionFilter,
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
          'Recipe Filters',
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
              title: 'Meal Time',
              subtitle: 'Choose when you want to eat',
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
            _buildMultiSection(
              title: 'Include Ingredients',
              subtitle: 'Ingredients you want in your recipes',
              items: includeIngredients,
              selected: selectedIncludeIngredients,
              onTap: (value) {
                toggleMultiSelect(selectedIncludeIngredients, value);
              },
            ),
            _buildSingleSection(
              title: 'Cuisines',
              subtitle: 'Pick your favorite kitchen style',
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
              title: 'Avoid Ingredients',
              subtitle: 'Ingredients and allergens you want to avoid',
              items: excludeIngredients,
              selected: selectedExcludeIngredients,
              onTap: (value) {
                toggleMultiSelect(selectedExcludeIngredients, value);
              },
            ),
            _buildMultiSection(
              title: 'Diet Types',
              subtitle: 'Choose your lifestyle preference',
              items: diets,
              selected: selectedDietTypes,
              onTap: (value) {
                toggleMultiSelect(selectedDietTypes, value);
              },
            ),
            _buildMultiSection(
              title: 'Medical Diets',
              subtitle: 'Helpful filters for special conditions',
              items: medicalDiets,
              selected: selectedMedicalDiets,
              onTap: (value) {
                toggleMultiSelect(selectedMedicalDiets, value);
              },
            ),
            _buildSingleSection(
              title: 'Cooking Time',
              subtitle: 'How much time do you have?',
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
              title: 'Nutrition Goals',
              subtitle: 'Filter recipes by nutrition target',
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
            color: navy.withValues(alpha: 0.18),
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
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
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
                  'Customize your recipes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  totalSelected == 0
                      ? 'Select filters to find better meals'
                      : '$totalSelected filters selected',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
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
            color: navy.withValues(alpha: 0.08),
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
                    'Clear',
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
                    'Show Recipes',
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
    final shouldPrioritizeSelected =
        title != 'Meal Time' && title != 'Cooking Time';

    final visibleItems = shouldPrioritizeSelected
        ? _prioritizeSelectedItems(items, (item) => item == selected)
        : items;

    final bool isCuisineSection = title == 'Cuisines';

    return _buildSectionContainer(
      title: title,
      subtitle: subtitle,
      selectedCount: selected.isEmpty ? 0 : 1,
      headerAction: items.length > 6
          ? TextButton.icon(
              onPressed: () {
                _openItemsBottomSheet(
                  title: title,
                  items: items,
                  selectedValue: selected,
                  onSingleSelect: onTap,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: navy,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: navy,
              ),
              label: const Text(
                'Show all',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
            )
          : null,
      child: _buildOptionsGrid(
        items: visibleItems.take(6).toList(),
        itemBuilder: (item) {
          final isSelected = selected == item;

          return _buildChip(
            text: item,
            isSelected: isSelected,
            leading: _buildAssetIcon(title, item),
            iconOnTop: isCuisineSection,
            onTap: () => onTap(item),
          );
        },
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
    final mergedItems = {...selected, ...items}.toList();

    final visibleItems = _prioritizeSelectedItems(
      mergedItems,
      (item) => selected.contains(item),
    );

    return _buildSectionContainer(
      title: title,
      subtitle: subtitle,
      selectedCount: selected.length,
      headerAction: mergedItems.length > 6
          ? TextButton.icon(
              onPressed: () {
                _openItemsBottomSheet(
                  title: title,
                  items: mergedItems,
                  selectedValues: selected,
                  onMultiToggle: onTap,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: navy,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: navy,
              ),
              label: const Text(
                'Show all',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
            )
          : null,
      child: _buildOptionsGrid(
        items: visibleItems.take(6).toList(),
        itemBuilder: (item) {
          final isSelected = selected.contains(item);

          return _buildChip(
            text: item,
            isSelected: isSelected,
            leading: _buildAssetIcon(title, item),
            iconOnTop: false,
            onTap: () => onTap(item),
          );
        },
      ),
    );
  }

  List<String> _prioritizeSelectedItems(
    List<String> items,
    bool Function(String item) isSelected,
  ) {
    return [
      ...items.where(isSelected),
      ...items.where((item) => !isSelected(item)),
    ];
  }

  Widget _buildOptionsGrid({
    required List<String> items,
    required Widget Function(String item) itemBuilder,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        mainAxisExtent: 58,
      ),
      itemBuilder: (context, index) => itemBuilder(items[index]),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required String subtitle,
    required int selectedCount,
    required Widget child,
    Widget? headerAction,
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
            color: navy.withValues(alpha: 0.045),
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
              if (headerAction != null) ...[
                const SizedBox(width: 8),
                headerAction,
              ],
              if (selectedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: softBlue,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    '$selectedCount selected',
                    style: const TextStyle(
                      color: navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  void _openItemsBottomSheet({
    required String title,
    required List<String> items,
    String? selectedValue,
    List<String>? selectedValues,
    ValueChanged<String>? onSingleSelect,
    ValueChanged<String>? onMultiToggle,
  }) {
    final isMultiSelect = selectedValues != null;
    final bool isCuisineSection = title == 'Cuisines';
    final bool enableIngredientApiSearch =
        isMultiSelect &&
        (title == 'Include Ingredients' || title == 'Avoid Ingredients');

    String? tempSelectedValue = selectedValue;
    String searchQuery = '';
    bool isSearchingIngredients = false;
    List<String> apiIngredientResults = [];
    int latestSearchRequestId = 0;

    final originalSelectedValues = <String>{...selectedValues ?? const []};
    final tempSelectedValues = <String>{...originalSelectedValues};

    Future<void> searchIngredientsFromApi(
      String query,
      void Function(void Function()) setSheetState,
    ) async {
      if (!enableIngredientApiSearch) {
        return;
      }

      final normalizedQuery = query.trim();
      final requestId = ++latestSearchRequestId;

      if (normalizedQuery.isEmpty) {
        setSheetState(() {
          isSearchingIngredients = false;
          apiIngredientResults = [];
        });
        return;
      }

      setSheetState(() {
        isSearchingIngredients = true;
      });

      try {
        final response = await http.get(
          Uri.parse(
            '${AppConfig.baseUrl}/ingredients/search?q=${Uri.encodeQueryComponent(normalizedQuery)}',
          ),
        );

        if (!mounted || requestId != latestSearchRequestId) return;

        if (response.statusCode != 200) {
          setSheetState(() {
            isSearchingIngredients = false;
            apiIngredientResults = [];
          });
          return;
        }

        final decoded = jsonDecode(response.body);
        final data = decoded is List ? decoded : const [];

        final fetchedNames = data
            .map((e) => (e['name'] ?? '').toString().trim())
            .where((name) => name.isNotEmpty)
            .toList();

        setSheetState(() {
          isSearchingIngredients = false;
          apiIngredientResults = fetchedNames;
        });
      } catch (_) {
        if (!mounted || requestId != latestSearchRequestId) return;

        setSheetState(() {
          isSearchingIngredients = false;
          apiIngredientResults = [];
        });
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final normalizedSearchQuery = searchQuery.trim().toLowerCase();

            final baseSource = {
              ...tempSelectedValues,
              ...items,
              ...apiIngredientResults,
            }.toList();

            final typedIngredient = searchQuery.trim();
            final hasTypedIngredient = baseSource.any(
              (item) => item.toLowerCase() == typedIngredient.toLowerCase(),
            );

            if (enableIngredientApiSearch &&
                typedIngredient.isNotEmpty &&
                !hasTypedIngredient) {
              baseSource.insert(0, typedIngredient);
            }

            final filteredSource = normalizedSearchQuery.isEmpty
                ? baseSource
                : baseSource.where((item) {
                    return item.toLowerCase().contains(normalizedSearchQuery);
                  }).toList();

            final selectedFirstItems = filteredSource.where((item) {
              return isMultiSelect
                  ? tempSelectedValues.contains(item)
                  : tempSelectedValue == item;
            }).toList();

            final unselectedItems = filteredSource.where((item) {
              return isMultiSelect
                  ? !tempSelectedValues.contains(item)
                  : tempSelectedValue != item;
            }).toList();

            final orderedItems = [...selectedFirstItems, ...unselectedItems];
            final searchHintText = !enableIngredientApiSearch
                ? 'Search'
                : title == 'Include Ingredients'
                ? 'Search what is in your pantry'
                : 'Search ingredients or allergens to avoid';

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: SizedBox(
                    height: MediaQuery.of(sheetContext).size.height * 0.78,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: borderBlue,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: navy,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: navy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          onChanged: (value) {
                            setSheetState(() {
                              searchQuery = value;
                            });

                            if (enableIngredientApiSearch) {
                              searchIngredientsFromApi(value, setSheetState);
                            }
                          },
                          decoration: InputDecoration(
                            hintText: searchHintText,
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: navy,
                            ),
                            suffixIcon: isSearchingIngredients
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xffF7FAFE),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: borderBlue),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: borderBlue),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xff6F95CF),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: orderedItems.isEmpty
                              ? Center(
                                  child: Text(
                                    searchQuery.trim().isEmpty
                                        ? 'No items available'
                                        : 'No matching ingredients',
                                    style: const TextStyle(
                                      color: navy,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  itemCount: orderedItems.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 6,
                                        mainAxisSpacing: 6,
                                        mainAxisExtent: 58,
                                      ),
                                  itemBuilder: (context, index) {
                                    final item = orderedItems[index];

                                    final isSelected = isMultiSelect
                                        ? tempSelectedValues.contains(item)
                                        : tempSelectedValue == item;

                                    return _buildChip(
                                      text: item,
                                      isSelected: isSelected,
                                      leading: _buildAssetIcon(title, item),
                                      iconOnTop: isCuisineSection,
                                      onTap: () {
                                        setSheetState(() {
                                          if (isMultiSelect) {
                                            if (tempSelectedValues.contains(
                                              item,
                                            )) {
                                              tempSelectedValues.remove(item);
                                            } else {
                                              tempSelectedValues.add(item);
                                            }
                                          } else {
                                            tempSelectedValue = item;
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              if (isMultiSelect) {
                                final allItems = <String>{
                                  ...originalSelectedValues,
                                  ...tempSelectedValues,
                                };

                                for (final item in allItems) {
                                  final wasSelected = originalSelectedValues
                                      .contains(item);
                                  final isNowSelected = tempSelectedValues
                                      .contains(item);

                                  if (wasSelected != isNowSelected) {
                                    onMultiToggle?.call(item);
                                  }
                                }
                              } else {
                                if (tempSelectedValue != null) {
                                  onSingleSelect?.call(tempSelectedValue!);
                                }
                              }

                              Navigator.pop(sheetContext);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChip({
    required String text,
    required bool isSelected,
    Widget? leading,
    required VoidCallback onTap,
    bool iconOnTop = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: double.infinity,
          height: 58,
          padding: EdgeInsets.symmetric(
            horizontal: iconOnTop ? 6 : 7,
            vertical: iconOnTop ? 5 : 4,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xffD7E7FB)
                : const Color(0xffF7FAFE),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected ? const Color(0xff6F95CF) : borderBlue,
              width: isSelected ? 1.7 : 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xff6F95CF).withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: iconOnTop
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leading != null)
                        SizedBox(width: 24, height: 24, child: leading),
                      if (leading != null) const SizedBox(height: 3),
                      Flexible(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? const Color(0xff1B3C73) : navy,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leading != null) ...[
                        SizedBox(width: 20, height: 20, child: leading),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? const Color(0xff1B3C73) : navy,
                            fontSize: 12.5,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget? _buildAssetIcon(String sectionTitle, String item) {
    final assetPath = _getAssetIconPath(sectionTitle, item);

    if (assetPath == null) return null;

    return Image.asset(
      assetPath,
      width: 24,
      height: 24,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return const SizedBox.shrink();
      },
    );
  }

  String? _getAssetIconPath(String sectionTitle, String item) {
    final title = sectionTitle.toLowerCase();
    final value = item.toLowerCase();

    if (title.contains('cooking time')) {
      return null;
    }

    if (title.contains('meal time')) {
      if (value.contains('breakfast')) return 'assets/icons/breakfast (2).png';
      if (value.contains('lunch')) return 'assets/icons/lunch (2).png';
      if (value.contains('dinner')) return 'assets/icons/dinner (2).png';
      if (value.contains('snack')) return 'assets/icons/snack (2).png';
      if (value.contains('drink')) return 'assets/icons/drink.png';
      if (value.contains('dessert')) return 'assets/icons/cupcake.png';
    }

    if (title.contains('include')) {
      if (value.contains('chicken')) return 'assets/icons/chicken.png';
      if (value.contains('beef')) return 'assets/icons/beef.png';
      if (value.contains('salmon')) return 'assets/icons/salmon.png';
      if (value.contains('shrimp')) return 'assets/icons/shrimp.png';
      if (value.contains('rice')) return 'assets/icons/rice.png';
      if (value.contains('pasta')) return 'assets/icons/pasta.png';
      if (value.contains('cheese')) return 'assets/icons/cheese.png';
      if (value.contains('tomato')) return 'assets/icons/tomato.png';
      if (value.contains('eggs')) return 'assets/icons/eggs2.png';
      if (value.contains('avocado')) return 'assets/icons/avocado.png';
      if (value.contains('mushroom')) return 'assets/icons/mushroom.png';
      if (value.contains('broccoli')) return 'assets/icons/broccoli.png';
      if (value.contains('corn')) return 'assets/icons/corn.png';
      if (value.contains('potato')) return 'assets/icons/potato.png';
      if (value.contains('garlic')) return 'assets/icons/garlic.png';
      if (value.contains('onion')) return 'assets/icons/onion.png';
      if (value.contains('chili')) return 'assets/icons/chili.png';
      if (value.contains('carrot')) return 'assets/icons/carrot.png';
      if (value.contains('lettuce')) return 'assets/icons/lettuce.png';
      if (value.contains('lemon')) return 'assets/icons/lemon.png';
    }

    if (title.contains('cuisine')) {
      if (value.contains('italian')) return 'assets/icons/italian.png';
      if (value.contains('mexican')) return 'assets/icons/mexican.png';
      if (value.contains('indian')) return 'assets/icons/indian.png';
      if (value.contains('chinese')) return 'assets/icons/chinese.png';
      if (value.contains('arabic')) return 'assets/icons/arabic.png';
      if (value.contains('japanese')) return 'assets/icons/japanese.png';
      if (value.contains('spanish')) return 'assets/icons/spanish.png';
      if (value.contains('american')) return 'assets/icons/american.png';
      if (value.contains('french')) return 'assets/icons/french.png';
      if (value.contains('turkish')) return 'assets/icons/turkish.png';
      if (value.contains('mediterranean')) {
        return 'assets/icons/mediterranean.png';
      }
      if (value.contains('thai')) return 'assets/icons/thai.png';
    }

    if (title.contains('avoid')) {
      if (value.contains('pork')) return 'assets/icons/pork.png';
      if (value.contains('red meat')) return 'assets/icons/beef.png';
      if (value.contains('spicy')) return 'assets/icons/chili.png';
      if (value.contains('mushroom')) return 'assets/icons/mushroom.png';
      if (value.contains('butter')) return 'assets/icons/butter.png';
      if (value.contains('garlic')) return 'assets/icons/garlic.png';
      if (value.contains('onion')) return 'assets/icons/onion.png';
      if (value.contains('nut')) return 'assets/icons/nut_free.png';
      if (value.contains('gluten')) return 'assets/icons/gluten_free.png';
      if (value.contains('dairy')) return 'assets/icons/dairy_free.png';
      if (value.contains('alcohol')) return 'assets/icons/alcohol_free.png';
      if (value.contains('shellfish')) return 'assets/icons/shellfish_free.png';
      if (value.contains('fish')) return 'assets/icons/fish_free.png';
      if (value.contains('egg')) return 'assets/icons/egg_free.png';
      if (value.contains('honey')) return 'assets/icons/honey_free.png';
    }

    if (title.contains('diet types')) {
      if (value.contains('vegetarian')) return 'assets/icons/vegetarian.png';
      if (value.contains('vegan')) return 'assets/icons/vegan.png';
      if (value.contains('keto')) return 'assets/icons/keto.png';
      if (value.contains('balanced')) return 'assets/icons/balanced.png';
      if (value.contains('high energy')) return 'assets/icons/energy.png';
      if (value.contains('detox')) return 'assets/icons/detox.png';
    }

    if (title.contains('medical')) {
      if (value.contains('diabetic')) return 'assets/icons/diabetic.png';
      if (value.contains('dash')) return 'assets/icons/dash.png';
      if (value.contains('mind')) return 'assets/icons/mind.png';
      if (value.contains('heart')) return 'assets/icons/heart2.png';
      if (value.contains('anti-inflammatory')) {
        return 'assets/icons/anti_inflammatory.png';
      }
      if (value.contains('low sodium')) return 'assets/icons/low_sodium.png';
      if (value.contains('fodmap')) return 'assets/icons/low_fodmap.png';
    }

    if (title.contains('nutrition')) {
      if (value.contains('low calories')) {
        return 'assets/icons/low_calories.png';
      }
      if (value.contains('high calories')) {
        return 'assets/icons/high_calories.png';
      }
      if (value.contains('high protein')) {
        return 'assets/icons/high_protein.png';
      }
      if (value.contains('low protein')) {
        return 'assets/icons/low_protein.png';
      }
      if (value.contains('low carb')) return 'assets/icons/low_carb.png';
      if (value.contains('high carb')) return 'assets/icons/high_carb.png';
      if (value.contains('low fat')) return 'assets/icons/low_fat.png';
      if (value.contains('high fat')) return 'assets/icons/high_fat.png';
    }

    return null;
  }
}
