import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/features/screen/page_cook_screen/home_cooks_screen.dart';
import 'chef_profile_screen.dart';
import 'recipe_detail_screen.dart';
import '../../../../core/config/app_config.dart';

const _kNavy = Color(0xFF001F3F);
const _kBlue = Color(0xFF005EB2);
const _kCard = Colors.white;
const _kSurface = Color(0xFFF7F8FA);
const _kError = Colors.red;
const _kAmber = Color(0xFFFBBF24);

// ✅ أضيفي هذه الدالة في بداية الملف
String safeString(dynamic value) {
  if (value == null) return '';
  if (value is List) {
    return value.map((e) => e.toString()).join(', ');
  }
  return value.toString();
}

class FavoritesPage extends StatefulWidget {
  final Set<String> favoriteChefs;
  final Set<String> favoriteRecipes;

  final List<dynamic> allChefs;
  final List<dynamic> allRecipes;

  final Function(String) onToggleFavoriteChef;

  final Function(String, Map<String, dynamic>) onToggleFavoriteRecipe;

  const FavoritesPage({
    super.key,
    required this.favoriteChefs,
    required this.favoriteRecipes,
    required this.allChefs,
    required this.allRecipes,
    required this.onToggleFavoriteChef,
    required this.onToggleFavoriteRecipe,
  });

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class ChefCard extends StatelessWidget {
  final Map<String, dynamic> chef;
  final bool isFavourite;
  final bool isFollowing;
  final VoidCallback onFavouriteToggle;
  final VoidCallback onFollowToggle;
  final VoidCallback onTap;

  const ChefCard({
    super.key,
    required this.chef,
    required this.isFavourite,
    required this.isFollowing,
    required this.onFavouriteToggle,
    required this.onFollowToggle,
    required this.onTap,
  });

  void _openChef(BuildContext context) {
    final chefId = chef['_id']?.toString() ?? '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChefProfileScreen(chefId: chefId, chefData: chef),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ استخدمي safeString هنا
    final specialty = safeString(chef['specialty']);

    return GestureDetector(
      onTap: () => _openChef(context),

      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),

          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Column(
          children: [
            SizedBox(
              height: 90,
              width: double.infinity,

              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),

                    child: Image.network(
                      (() {
                        final image = chef['profileImage'] ?? '';

                        if (image.toString().startsWith('http')) {
                          return image;
                        }

                        return '${AppConfig.baseUrl.replaceAll('/api', '')}$image';
                      })(),

                      fit: BoxFit.cover,

                      width: double.infinity,

                      cacheWidth: 500,
                      cacheHeight: 500,

                      filterQuality: FilterQuality.low,

                      errorBuilder: (_, _, _) => Container(
                        color: const Color(0xffEAF2FF),

                        child: const Center(
                          child: Text('👨‍🍳', style: TextStyle(fontSize: 34)),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: 8,
                    right: 8,

                    child: GestureDetector(
                      onTap: onFavouriteToggle,

                      child: Container(
                        padding: const EdgeInsets.all(6),

                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),

                        child: Icon(
                          isFavourite ? Icons.favorite : Icons.favorite_border,

                          color: Colors.red,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      chef['name'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 3),

                    // ✅ استخدمي specialty هنا بدلاً من chef['specialty'] مباشرة
                    Text(
                      specialty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),

                    const Spacer(),

                    Row(
                      children: [
                        const Icon(Icons.star, size: 12, color: Colors.amber),

                        const SizedBox(width: 4),

                        Text(
                          "${chef['rating'] ?? 4.9}",
                          style: const TextStyle(fontSize: 10),
                        ),

                        const Spacer(),

                        Flexible(
                          child: Text(
                            "${chef['recipesCount'] ?? 0} dishes",
                            overflow: TextOverflow.ellipsis,

                            style: const TextStyle(fontSize: 9),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    Align(
                      alignment: Alignment.centerRight,

                      child: InkWell(
                        onTap: () => _openChef(context),

                        borderRadius: BorderRadius.circular(10),

                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),

                          decoration: BoxDecoration(
                            color: _kBlue.withOpacity(.08),

                            borderRadius: BorderRadius.circular(10),
                          ),

                          child: const Text(
                            "View profile",
                            style: TextStyle(
                              color: _kBlue,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<dynamic> get favoriteChefsList => widget.allChefs.where((chef) {
    return widget.favoriteChefs.contains(chef['_id'].toString());
  }).toList();

  List<dynamic> get favoriteRecipesList {
    return widget.allRecipes.where((recipe) {
      final id = (recipe['_id'] ?? recipe['id']).toString();

      return widget.favoriteRecipes.contains(id);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,

      appBar: AppBar(
        backgroundColor: _kNavy,
        elevation: 0,
        centerTitle: true,

        leadingWidth: 72,

        leading: Padding(
          padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),

          child: Material(
            color: Colors.transparent,

            child: InkWell(
              borderRadius: BorderRadius.circular(30),

              onTap: () {
                Navigator.pop(context);
              },

              child: Container(
                decoration: BoxDecoration(
                  color: _kBlue,
                  shape: BoxShape.circle,

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),

                child: const Center(
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),

        title: const Text(
          "Favorites",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 22,
          ),
        ),

        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Favorite Chefs"),
            Tab(text: "Favorite Recipes"),
          ],
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          /// CHEFS
          favoriteChefsList.isEmpty
              ? _empty("No favorite chefs yet ❤️")
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),

                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),

                    itemCount: favoriteChefsList.length,

                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: .80,
                        ),
                    itemBuilder: (context, index) {
                      final chef = favoriteChefsList[index];
                      final chefId = chef['_id'].toString();

                      return ChefCard(
                        chef: Map<String, dynamic>.from(chef),

                        isFavourite: true,
                        isFollowing: false,

                        onFavouriteToggle: () {
                          widget.onToggleFavoriteChef(chefId);
                          setState(() {});
                        },

                        onFollowToggle: () {},

                        onTap: () {},
                      );
                    },
                  ),
                ),
          favoriteRecipesList.isEmpty
              ? _empty("No favorite recipes ❤️")
              : GridView.builder(
                  padding: const EdgeInsets.all(16),

                  itemCount: favoriteRecipesList.length,

                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: .72,
                  ),

                  itemBuilder: (context, index) {
                    final recipe = Map<String, dynamic>.from(
                      favoriteRecipesList[index],
                    );

                    return _buildFavoriteRecipeCard(recipe);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildFavoriteRecipeCard(Map<String, dynamic> recipe) {
    final recipeId = (recipe['_id'] ?? recipe['id']).toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),

                child: (() {
                  final image =
                      recipe["image"] ??
                      recipe["dishImage"] ??
                      recipe["photo"] ??
                      '';

                  String finalImage = '';

                  if (image.toString().startsWith('http')) {
                    finalImage = image;
                  } else {
                    finalImage =
                        '${AppConfig.baseUrl.replaceAll('/api', '')}$image';
                  }

                  return Image.network(
                    finalImage,

                    height: 100,

                    width: double.infinity,

                    fit: BoxFit.cover,

                    cacheWidth: 500,
                    cacheHeight: 500,

                    filterQuality: FilterQuality.low,

                    errorBuilder: (_, _, _) {
                      return Container(
                        height: 100,

                        color: Colors.grey.shade200,

                        child: const Center(
                          child: Icon(
                            Icons.fastfood_rounded,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  );
                })(),
              ),

              Positioned(
                top: 8,
                right: 8,

                child: GestureDetector(
                  onTap: () {
                    /// يحذف مباشرة من fav
                    widget.onToggleFavoriteRecipe(
                      recipeId,
                      Map<String, dynamic>.from(recipe),
                    );

                    /// إزالة مباشرة من الصفحة
                    widget.favoriteRecipes.remove(recipeId);

                    setState(() {});

                    HapticFeedback.lightImpact();
                  },

                  child: Container(
                    padding: EdgeInsets.all(7),

                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),

                    child: Icon(Icons.favorite, color: Colors.red, size: 17),
                  ),
                ),
              ),
            ],
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    recipe["name"] ?? "",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,

                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),

                  SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(Icons.star, size: 13, color: _kAmber),

                      SizedBox(width: 4),

                      Text(
                        "${recipe["rating"] ?? 4.8}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      Spacer(),

                      Text(
                        "\$${recipe["price"] ?? 0}",
                        style: TextStyle(
                          color: _kBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 34,

                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(recipe: recipe),
                          ),
                        );
                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      icon: Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color: Colors.white,
                      ),

                      label: Text(
                        "View",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  Widget _empty(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }
}
