import 'package:flutter/material.dart';
import 'dart:async';

import '../../../shared/custom_bottom_nav.dart';
import '../../../core/theme/app_colors.dart';

import 'recipe_videos_section.dart';
import 'recipe_cards_section.dart';

enum _RecipeSortOrder { newestFirst, oldestFirst, mostPopular }

enum _RecipeFilter {
  all,
  favorites,
  quickMeals, // أقل من 30 دقيقة
  healthy, // سعرات قليلة
  highProtein,
  vegetarian,
  withVideo,
}

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  String selectedCuisine = "All";
  bool _isSearchExpanded = false;
  Timer? _searchDebounce;

  _RecipeSortOrder _sortOrder = _RecipeSortOrder.newestFirst;
  _RecipeFilter _recipeFilter = _RecipeFilter.all;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _searchFocusNode.addListener(() {
      if (!mounted) return;
      final hasQuery = searchController.text.trim().isNotEmpty;
      setState(() {
        _isSearchExpanded = _searchFocusNode.hasFocus || hasQuery;
      });
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    "Filters",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff1B3C73),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  "Cuisine Type",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xff6B7A90),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  value: selectedCuisine,
                  items:
                      [
                            "All",
                            "Arabic",
                            "Italian",
                            "Indian",
                            "Turkish",
                            "Mexican",
                          ]
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCuisine = value!;
                    });
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xffF7FAFE),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff1B3C73),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Apply Filters",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchSection() {
    final query = searchController.text.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const buttonWidth = 44.0;
          const gap = 10.0;

          final maxSearchWidth = (constraints.maxWidth - buttonWidth - gap)
              .clamp(120.0, double.infinity);

          final collapsedWidth = maxSearchWidth < 170 ? maxSearchWidth : 170.0;

          final expanded = _isSearchExpanded || query.isNotEmpty;

          return Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: expanded ? maxSearchWidth : collapsedWidth,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: expanded
                            ? const Color(0xFFC9DCF4)
                            : const Color(0xFFDDE9F6),
                      ),
                      boxShadow: [
                        if (expanded)
                          BoxShadow(
                            color: const Color(0xFF93B4DF).withOpacity(0.12),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      focusNode: _searchFocusNode,
                      onTap: () {
                        if (!_isSearchExpanded) {
                          setState(() => _isSearchExpanded = true);
                        }
                      },
                      onChanged: (value) {
                        setState(() {});
                        _searchDebounce?.cancel();
                        if (value.trim().length >= 2) {
                          _searchDebounce = Timer(
                            const Duration(milliseconds: 350),
                            () {
                              // يمكنك إضافة منطق البحث هنا
                              print('🔍 Searching for: ${value.trim()}');
                            },
                          );
                        }
                      },
                      decoration: InputDecoration(
                        hintText: expanded ? "Search recipes..." : "Search",
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xff8B9BB4),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xff6B7A90),
                          size: 20,
                        ),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  searchController.clear();
                                  final keepExpanded =
                                      _searchFocusNode.hasFocus;
                                  setState(() {
                                    _isSearchExpanded = keepExpanded;
                                  });
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Color(0xff6B7A90),
                                  size: 18,
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF7FAFE),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _buildFilterButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterButton() {
    final hasActiveFilter =
        _recipeFilter != _RecipeFilter.all ||
        _sortOrder != _RecipeSortOrder.newestFirst ||
        selectedCuisine != "All";

    return Builder(
      builder: (ctx) {
        return InkWell(
          onTap: () {
            final scaffold = Scaffold.maybeOf(ctx);
            scaffold?.openEndDrawer();
          },
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: AppColors.deepBlue,
                  size: 20,
                ),
              ),
              if (hasActiveFilter)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orange,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _filterTitle(_RecipeFilter f) {
    switch (f) {
      case _RecipeFilter.all:
        return 'All recipes';
      case _RecipeFilter.favorites:
        return 'Favorites';
      case _RecipeFilter.quickMeals:
        return 'Quick meals';
      case _RecipeFilter.healthy:
        return 'Healthy';
      case _RecipeFilter.highProtein:
        return 'High protein';
      case _RecipeFilter.vegetarian:
        return 'Vegetarian';
      case _RecipeFilter.withVideo:
        return 'With video';
    }
  }

  IconData _filterIcon(_RecipeFilter f) {
    switch (f) {
      case _RecipeFilter.all:
        return Icons.restaurant_menu_rounded;
      case _RecipeFilter.favorites:
        return Icons.favorite_rounded;
      case _RecipeFilter.quickMeals:
        return Icons.timer_rounded;
      case _RecipeFilter.healthy:
        return Icons.eco_rounded;
      case _RecipeFilter.highProtein:
        return Icons.fitness_center_rounded;
      case _RecipeFilter.vegetarian:
        return Icons.grass_rounded;
      case _RecipeFilter.withVideo:
        return Icons.play_circle_outline_rounded;
    }
  }

  String _filterSubtitle(_RecipeFilter f) {
    switch (f) {
      case _RecipeFilter.all:
        return 'Show all available recipes';
      case _RecipeFilter.favorites:
        return 'Your saved favorites';
      case _RecipeFilter.quickMeals:
        return 'Ready in under 30 minutes';
      case _RecipeFilter.healthy:
        return 'Low calorie options';
      case _RecipeFilter.highProtein:
        return 'High in protein content';
      case _RecipeFilter.vegetarian:
        return 'Plant-based recipes';
      case _RecipeFilter.withVideo:
        return 'Recipes with video tutorials';
    }
  }

  Widget _buildFilterSidebar({bool closeAfterSelect = false}) {
    final isFiltered =
        _recipeFilter != _RecipeFilter.all ||
        _sortOrder != _RecipeSortOrder.newestFirst ||
        selectedCuisine != "All";

    return SafeArea(
      child: Container(
        color: const Color(0xFFF7FAFF),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          child: ListView(
            children: [
              if (closeAfterSelect)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    splashRadius: 20,
                    color: const Color(0xff6B7A90),
                  ),
                ),
              _buildDrawerSectionTitle('Sort Order'),
              const SizedBox(height: 8),
              _buildSortSection(closeAfterSelect: closeAfterSelect),
              const SizedBox(height: 14),
              _buildDrawerSectionTitle('Filters'),
              const SizedBox(height: 8),
              _buildFilterSection(closeAfterSelect: closeAfterSelect),
              const SizedBox(height: 14),
              _buildDrawerSectionTitle('Cuisine Type'),
              const SizedBox(height: 8),
              _buildCuisineSection(closeAfterSelect: closeAfterSelect),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: isFiltered
                    ? () {
                        setState(() {
                          _recipeFilter = _RecipeFilter.all;
                          _sortOrder = _RecipeSortOrder.newestFirst;
                          selectedCuisine = "All";
                        });
                        if (closeAfterSelect) Navigator.pop(context);
                      }
                    : null,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Clear all filters'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff1B3C73),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE4ECF7),
                  disabledForegroundColor: const Color(0xff6B7A90),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortSection({required bool closeAfterSelect}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1EBF7)),
      ),
      child: Column(
        children: _RecipeSortOrder.values.map((order) {
          final selected = _sortOrder == order;
          String title;
          String subtitle;
          IconData icon;

          switch (order) {
            case _RecipeSortOrder.newestFirst:
              title = 'Newest first';
              subtitle = 'Recently added recipes';
              icon = Icons.new_releases_outlined;
              break;
            case _RecipeSortOrder.oldestFirst:
              title = 'Oldest first';
              subtitle = 'Classic recipes first';
              icon = Icons.history_rounded;
              break;
            case _RecipeSortOrder.mostPopular:
              title = 'Most popular';
              subtitle = 'Highest rated recipes';
              icon = Icons.trending_up_rounded;
              break;
          }

          return Material(
            color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: order == _RecipeSortOrder.values.first
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : order == _RecipeSortOrder.values.last
                ? const BorderRadius.vertical(bottom: Radius.circular(16))
                : BorderRadius.zero,
            child: InkWell(
              borderRadius: order == _RecipeSortOrder.values.first
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : order == _RecipeSortOrder.values.last
                  ? const BorderRadius.vertical(bottom: Radius.circular(16))
                  : BorderRadius.zero,
              onTap: () {
                setState(() => _sortOrder = order);
                if (closeAfterSelect) Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: order != _RecipeSortOrder.values.last
                      ? const Border(
                          bottom: BorderSide(color: Color(0xFFE1EBF7)),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFF3F7FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: selected
                            ? const Color(0xff1B3C73)
                            : const Color(0xff6B7A90),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? const Color(0xff1B3C73)
                                  : const Color(0xFF2B3440),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff6B7A90),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? const Color(0xff1B3C73)
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? const Color(0xff1B3C73)
                              : const Color(0xFFCCD9EA),
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 13,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterSection({required bool closeAfterSelect}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1EBF7)),
      ),
      child: ListView.separated(
        itemCount: _RecipeFilter.values.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 46),
        itemBuilder: (_, index) {
          final f = _RecipeFilter.values[index];
          final selected = _recipeFilter == f;

          return Material(
            color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: index == 0
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : index == _RecipeFilter.values.length - 1
                ? const BorderRadius.vertical(bottom: Radius.circular(16))
                : BorderRadius.zero,
            child: InkWell(
              borderRadius: index == 0
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : index == _RecipeFilter.values.length - 1
                  ? const BorderRadius.vertical(bottom: Radius.circular(16))
                  : BorderRadius.zero,
              onTap: () {
                setState(() => _recipeFilter = f);
                if (closeAfterSelect) Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFF3F7FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _filterIcon(f),
                        size: 18,
                        color: selected
                            ? const Color(0xff1B3C73)
                            : const Color(0xff6B7A90),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _filterTitle(f),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? const Color(0xff1B3C73)
                                  : const Color(0xFF2B3440),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _filterSubtitle(f),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff6B7A90),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? const Color(0xff1B3C73)
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? const Color(0xff1B3C73)
                              : const Color(0xFFCCD9EA),
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 13,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCuisineSection({required bool closeAfterSelect}) {
    final cuisines = [
      "All",
      "Arabic",
      "Italian",
      "Indian",
      "Turkish",
      "Mexican",
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1EBF7)),
      ),
      child: ListView.separated(
        itemCount: cuisines.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 46),
        itemBuilder: (_, index) {
          final cuisine = cuisines[index];
          final selected = selectedCuisine == cuisine;

          IconData icon;
          switch (cuisine) {
            case "All":
              icon = Icons.public_rounded;
              break;
            case "Arabic":
              icon = Icons.mosque_rounded;
              break;
            case "Italian":
              icon = Icons.local_pizza_rounded;
              break;
            case "Indian":
              icon = Icons.restaurant_rounded;
              break;
            case "Turkish":
              icon = Icons.kebab_dining_rounded;
              break;
            case "Mexican":
              icon = Icons.local_dining_rounded;
              break;
            default:
              icon = Icons.restaurant_menu_rounded;
          }

          return Material(
            color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: index == 0
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : index == cuisines.length - 1
                ? const BorderRadius.vertical(bottom: Radius.circular(16))
                : BorderRadius.zero,
            child: InkWell(
              borderRadius: index == 0
                  ? const BorderRadius.vertical(top: Radius.circular(16))
                  : index == cuisines.length - 1
                  ? const BorderRadius.vertical(bottom: Radius.circular(16))
                  : BorderRadius.zero,
              onTap: () {
                setState(() => selectedCuisine = cuisine);
                if (closeAfterSelect) Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFF3F7FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: selected
                            ? const Color(0xff1B3C73)
                            : const Color(0xff6B7A90),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cuisine,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? const Color(0xff1B3C73)
                              : const Color(0xFF2B3440),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? const Color(0xff1B3C73)
                            : Colors.transparent,
                        border: Border.all(
                          color: selected
                              ? const Color(0xff1B3C73)
                              : const Color(0xFFCCD9EA),
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 13,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawerSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Color(0xff6B7A90),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F8FD),

      bottomNavigationBar: const CustomBottomNav(currentIndex: 3),

      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // للشاشات الكبيرة: عرض الفلتر على الجانب
            if (constraints.maxWidth >= 700) {
              return Row(
                children: [
                  Container(
                    width: 280,
                    color: Colors.white,
                    child: _buildFilterSidebar(),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xFFEDEEF0)),
                  Expanded(child: _buildMainContent()),
                ],
              );
            }

            // للشاشات الصغيرة: عرض المحتوى فقط
            return _buildMainContent();
          },
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildSearchSection(),

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),

          child: Container(
            height: 55,

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius: BorderRadius.circular(18),

              border: Border.all(color: const Color(0xffDDE7F3)),
            ),

            child: TabBar(
              controller: _tabController,

              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.pressed)) {
                  return const Color(0xffB9C8E3);
                }

                return null;
              }),

              splashBorderRadius: BorderRadius.circular(14),

              indicator: BoxDecoration(
                color: const Color(0xff1B3C73),

                borderRadius: BorderRadius.circular(14),
              ),

              indicatorPadding: const EdgeInsets.all(5),

              labelColor: Colors.white,

              unselectedLabelColor: const Color(0xff6B7A90),

              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,

                fontSize: 14,
              ),

              dividerColor: Colors.transparent,

              tabs: const [
                Tab(
                  height: 45,

                  child: SizedBox(
                    width: double.infinity,

                    child: Center(child: Text("Videos")),
                  ),
                ),

                Tab(
                  height: 45,

                  child: SizedBox(
                    width: double.infinity,

                    child: Center(child: Text("Recipes")),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        Expanded(
          child: TabBarView(
            controller: _tabController,

            children: [
              // ======================
              // VIDEOS
              // ======================
              RecipeVideosSection(
                searchText: searchController.text,

                selectedCuisine: selectedCuisine,
              ),

              // ======================
              // RECIPES
              // ======================
              RecipeCardsSection(searchText: searchController.text),
            ],
          ),
        ),
      ],
    );
  }
}
