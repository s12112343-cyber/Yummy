import 'package:flutter/material.dart';
import '/../../models/recipe_details_model.dart';

class RecipeDetailsPage extends StatefulWidget {
  final RecipeDetailsModel recipe;

  const RecipeDetailsPage({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipeDetailsPage> createState() => _RecipeDetailsPageState();
}

class _RecipeDetailsPageState extends State<RecipeDetailsPage> {
  final ScrollController _scrollController = ScrollController();

  bool _showScrollTop = false;

  static const Color navy = Color(0xff1B3C73);
  static const Color darkNavy = Color(0xff102A43);
  static const Color pageBg = Color(0xffF4F8FD);
  static const Color softBlue = Color(0xffEAF2FF);
  static const Color borderColor = Color(0xffDDE8F6);
  static const Color mutedText = Color(0xff6B7A90);

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      final shouldShow = _scrollController.offset > 450;

      if (shouldShow != _showScrollTop) {
        setState(() {
          _showScrollTop = shouldShow;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String cleanStepText(String text) {
    return text
        .replaceAll(RegExp(r'^step\s*\d+[:.-]?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\d+[:.-]?\s*'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,

      floatingActionButton: AnimatedScale(
        scale: _showScrollTop ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _showScrollTop ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: FloatingActionButton(
            mini: true,
            elevation: 4,
            backgroundColor: navy,
            onPressed: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutCubic,
              );
            },
            child: const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),

      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 330,
            pinned: true,
            stretch: true,
            elevation: 0,
            backgroundColor: navy,
            iconTheme: const IconThemeData(color: Colors.white),

            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    widget.recipe.image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: softBlue,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: navy,
                          size: 48,
                        ),
                      );
                    },
                  ),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.10),
                          Colors.black.withOpacity(0.35),
                          Colors.black.withOpacity(0.78),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 24,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 24 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.recipe.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              height: 1.18,
                              letterSpacing: -0.4,
                            ),
                          ),

                          const SizedBox(height: 14),

                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _buildGlassChip(
                                Icons.restaurant_menu_rounded,
                                widget.recipe.cuisine,
                              ),
                              _buildGlassChip(
                                Icons.local_fire_department_rounded,
                                "${widget.recipe.calories} kcal",
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnimatedFadeSlide(
                    delay: 80,
                    child: _buildCookingInfoCard(),
                  ),

                  const SizedBox(height: 26),

                  _AnimatedFadeSlide(
                    delay: 130,
                    child: _buildSectionTitle(
                      title: "Ingredients",
                      icon: Icons.shopping_basket_rounded,
                    ),
                  ),

                  const SizedBox(height: 14),

                  ...widget.recipe.ingredients.toList().asMap().entries.map(
                    (entry) {
                      final index = entry.key;
                      final ingredient = entry.value;

                      return _AnimatedFadeSlide(
                        delay: 160 + (index * 35),
                        child: _buildIngredientCard(ingredient.toString()),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  _AnimatedFadeSlide(
                    delay: 180,
                    child: _buildSectionTitle(
                      title: "Cooking Steps",
                      icon: Icons.format_list_numbered_rounded,
                    ),
                  ),

                  const SizedBox(height: 14),

                  ...widget.recipe.cookingSteps
                      .asMap()
                      .entries
                      .where((step) {
                    final cleanedText = cleanStepText(step.value.toString());
                    return cleanedText.isNotEmpty;
                  }).map(
                    (step) {
                      final cleanedText = cleanStepText(step.value.toString());

                      return _AnimatedFadeSlide(
                        delay: 180 + (step.key * 40),
                        child: _buildStepCard(
                          number: step.key + 1,
                          text: cleanedText,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  _AnimatedFadeSlide(
                    delay: 220,
                    child: _buildSectionTitle(
                      title: "Nutrition",
                      icon: Icons.monitor_heart_rounded,
                    ),
                  ),

                  const SizedBox(height: 14),

                  _AnimatedFadeSlide(
                    delay: 260,
                    child: GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.25,
                      ),
                      children: [
                        _buildNutritionCard(
                          title: "Calories",
                          value: "${widget.recipe.calories}",
                          icon: Icons.local_fire_department_rounded,
                        ),
                        _buildNutritionCard(
                          title: "Protein",
                          value: "${widget.recipe.protein}g",
                          icon: Icons.fitness_center_rounded,
                        ),
                        _buildNutritionCard(
                          title: "Carbs",
                          value: "${widget.recipe.carbs}g",
                          icon: Icons.rice_bowl_rounded,
                        ),
                        _buildNutritionCard(
                          title: "Fat",
                          value: "${widget.recipe.fat}g",
                          icon: Icons.opacity_rounded,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCookingInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.07),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCookingInfo(
              icon: Icons.schedule_rounded,
              title: "Prep",
              value: widget.recipe.preparationTime,
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildCookingInfo(
              icon: Icons.soup_kitchen_rounded,
              title: "Cook",
              value: widget.recipe.cookingTime,
            ),
          ),
          _buildDivider(),
          Expanded(
            child: _buildCookingInfo(
              icon: Icons.groups_rounded,
              title: "Servings",
              value: widget.recipe.servings.toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 48,
      color: borderColor,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildCookingInfo({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: softBlue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: navy, size: 21),
        ),
        const SizedBox(height: 9),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: darkNavy,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(
            color: mutedText,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: darkNavy,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientCard(String ingredient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.045),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: softBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: navy,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ingredient,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xff2D3748),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required int number,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: navy.withOpacity(0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "$number",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: Color(0xff2D3748),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: navy.withOpacity(0.055),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.94, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: softBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: navy,
                size: 21,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: darkNavy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedFadeSlide extends StatelessWidget {
  final Widget child;
  final int delay;

  const _AnimatedFadeSlide({
    required this.child,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + delay.clamp(0, 250)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}