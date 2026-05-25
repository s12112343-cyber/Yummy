import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/services/favorite_service.dart';
import '../../home/home_screen.dart';
import 'chef_profile_screen.dart';
import 'category_chefs_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/auth_service.dart';
import '../../../shared/custom_bottom_nav.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../models/category_model.dart';
import 'CartScreen.dart';
import 'favorites_page.dart';
import 'recipe_detail_screen.dart';

// ─── Palette ────────────────────────────────────────────────────────────────
const _kNavy = Color(0xFF001F3F);
const _kBlue = Color(0xFF005EB2);
const _kBlueLight = Color(0xFF4597FE);
const _kBluePale = Color(0xFFD5E3FF);
const _kTeal = Color(0xFF76D2F6);
const _kSurface = Color(0xFFF8F9FA);
const _kSurfaceHigh = Color(0xFFE7E8E9);
const _kCard = Color(0xFFFFFFFF);
const _kText = Color(0xFF191C1D);
const _kTextDim = Color(0xFF43474E);
const _kOutline = Color(0xFFC4C6CF);
const _kError = Color(0xFFBA1A1A);
const _kAmber = Color(0xFFFBBF24);
const _kGreen = Color(0xFF10B981);

// ✅ الدالة المعدلة للتعامل مع List أو String
String safeString(dynamic value) {
  if (value == null) return '';
  if (value is List) {
    return value.map((e) => e.toString()).join(', ');
  }
  return value.toString();
}

class HomeCooksScreen extends StatefulWidget {
  const HomeCooksScreen({super.key});

  @override
  State<HomeCooksScreen> createState() => _HomeCooksScreenState();
}

class _HomeCooksScreenState extends State<HomeCooksScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  String _userName = '';
  String _userAvatar = '';
  bool _loading = true;

  List<dynamic> _chefs = [];
  List<dynamic> _filteredChefs = [];
  List<dynamic> _trendingRecipes = [];
  List<dynamic> _banners = [];
  bool _loadingChefs = true;
  bool _loadingBanners = true;
  bool _loadingTrending = true;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  final List<dynamic> _allRecipes = [];
  int _selectedCategory = 0;
  Set<String> _favoriteChefs = {};
  Set<String> _favoriteRecipes = {};
  Set<String> _followingChefs = {};

  // Banners slider
  final PageController _bannerCtrl = PageController();
  int _bannerPage = 0;
  Timer? _bannerTimer;

  // Animations
  late AnimationController _headerAnim;
  late AnimationController _contentAnim;

  // ── Categories ─────────────────────────────────────────────────────────────
  final List<CategoryModel> _categories = const [
    CategoryModel(name: 'All', icon: Icons.grid_view_rounded, id: 'all'),
    CategoryModel(name: 'Pizza', icon: Icons.local_pizza_rounded, id: 'pizza'),
    CategoryModel(
      name: 'Burger',
      icon: Icons.lunch_dining_rounded,
      id: 'burger',
    ),
    CategoryModel(name: 'Asian', icon: Icons.ramen_dining_rounded, id: 'asian'),
    CategoryModel(name: 'Dessert', icon: Icons.icecream_rounded, id: 'dessert'),
    CategoryModel(name: 'Seafood', icon: Icons.set_meal_rounded, id: 'seafood'),
    CategoryModel(name: 'Healthy', icon: Icons.eco_rounded, id: 'healthy'),
    CategoryModel(name: 'Coffee', icon: Icons.coffee_rounded, id: 'coffee'),
    CategoryModel(
      name: 'Breakfast',
      icon: Icons.free_breakfast_rounded,
      id: 'breakfast',
    ),
    CategoryModel(
      name: 'Middle East',
      icon: Icons.kebab_dining_rounded,
      id: 'middle eastern',
    ),
    CategoryModel(
      name: 'Bakery',
      icon: Icons.bakery_dining_rounded,
      id: 'bakery',
    ),
    CategoryModel(name: 'Sushi', icon: Icons.rice_bowl_rounded, id: 'sushi'),
  ];

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    _contentAnim = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();
    _loadUser();
    _loadChefs();
    _loadBanners();
    _loadTrendingRecipes();
    _loadFavorites();
    _loadFollowing();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    _headerAnim.dispose();
    _contentAnim.dispose();
    super.dispose();
  }

  // ── Data Loading ────────────────────────────────────────────────────────────
  Future<void> _loadUser() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = p.getString('userName') ?? 'Guest';
        _userAvatar = p.getString('userAvatar') ?? '';
        _loading = false;
      });
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final savedChefs = prefs.getStringList('favoriteChefs') ?? [];
    final savedRecipes = prefs.getStringList('favoriteRecipes') ?? [];
    if (mounted) {
      setState(() {
        _favoriteChefs = savedChefs.toSet();
        _favoriteRecipes = savedRecipes.toSet();
      });
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteChefs', _favoriteChefs.toList());
    await prefs.setStringList('favoriteRecipes', _favoriteRecipes.toList());
  }

  Future<void> _loadFollowing() async {
    final prefs = await SharedPreferences.getInstance();
    final following = prefs.getStringList('followingChefs') ?? [];
    if (mounted) {
      setState(() {
        _followingChefs = following.toSet();
      });
    }
  }

  Future<void> _saveFollowing() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('followingChefs', _followingChefs.toList());
  }

  Future<void> _loadChefs() async {
    if (!mounted) return;
    setState(() {
      _loadingChefs = true;
    });

    try {
      final token = await AuthService().getToken();
      final headers = token != null && token.trim().isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : null;

      final r = await http.get(
        Uri.parse('${AppConfig.baseUrl}/chefs'),
        headers: headers,
      );
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        final list = (d['data'] ?? []) as List;
        list.sort(
          (a, b) =>
              ((b['rating'] ?? 0) as num).compareTo((a['rating'] ?? 0) as num),
        );
        if (mounted) {
          setState(() {
            _chefs = list;
            _filteredChefs = list;
            _loadingChefs = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _chefs = [];
            _filteredChefs = [];
            _loadingChefs = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading chefs: $e');
      if (mounted) {
        setState(() {
          _chefs = [];
          _filteredChefs = [];
          _loadingChefs = false;
        });
      }
    }
  }

  Future<void> _loadTrendingRecipes() async {
    if (!mounted) return;
    setState(() {
      _loadingTrending = true;
    });

    try {
      final token = await AuthService().getToken();
      final headers = token != null && token.trim().isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : null;

      final r = await http.get(
        Uri.parse('${AppConfig.baseUrl}/recipes/trending'),
        headers: headers,
      );
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (mounted) {
          setState(() {
            _trendingRecipes = (d['data'] ?? []).map<Map<String, dynamic>>((
              item,
            ) {
              final Map<String, dynamic> m = Map<String, dynamic>.from(
                item ?? {},
              );

              final String image = fullImageUrl(
                m['image'] ?? m['dishImage'] ?? m['photo'] ?? '',
              );

              m['image'] = image;
              m['chefName'] = (m['chef'] is Map)
                  ? (m['chef']['name'] ?? '')
                  : (m['chefName'] ?? '');
              m['chefImage'] = (m['chef'] is Map)
                  ? (m['chef']['profileImage'] ?? '')
                  : (m['chefImage'] ?? '');

              return m;
            }).toList();
            _loadingTrending = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _trendingRecipes = [];
          _loadingTrending = false;
        });
      }
    } catch (e) {
      print('❌ Error loading trending recipes: $e');
      if (mounted) {
        setState(() {
          _trendingRecipes = [];
          _loadingTrending = false;
        });
      }
    }
  }

  Future<void> _loadBanners() async {
    if (!mounted) return;
    setState(() {
      _loadingBanners = true;
    });

    try {
      final token = await AuthService().getToken();
      final headers = token != null && token.trim().isNotEmpty
          ? {'Authorization': 'Bearer $token'}
          : null;

      final r = await http.get(
        Uri.parse('${AppConfig.baseUrl}/banners'),
        headers: headers,
      );
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (mounted) {
          setState(() {
            _banners = d['banners'] ?? [];
            _loadingBanners = false;
          });
          _startBannerTimer();
        }
      } else {
        if (mounted) setState(() => _loadingBanners = false);
      }
    } catch (e) {
      print('❌ Error loading banners: $e');
      if (mounted) setState(() => _loadingBanners = false);
    }
  }

  void _startBannerTimer() {
    if (_banners.length <= 1) return;
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _banners.isEmpty) return;
      _bannerPage = (_bannerPage + 1) % _banners.length;
      if (_bannerCtrl.hasClients) {
        _bannerCtrl.animateToPage(
          _bannerPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _filterByCategory(String categoryId) {
    setState(() {
      _filteredChefs = categoryId == 'all'
          ? _chefs
          : _chefs.where((chef) {
              final raw = chef['specialty'];
              final specialty = raw is List
                  ? raw.join(',').toLowerCase()
                  : (raw ?? '').toString().toLowerCase();
              return specialty.contains(categoryId.toLowerCase());
            }).toList();
    });
  }

  void addRecipeToGlobalFavorites(Map<String, dynamic> recipe) {
    final recipeId = (recipe['_id'] ?? recipe['id']).toString();

    final exists = _allRecipes.any(
      (r) => (r['_id'] ?? r['id']).toString() == recipeId,
    );

    if (!exists) {
      setState(() {
        _allRecipes.add(recipe);
      });
    }
  }

  Future<void> _toggleFavoriteChef(String chefId) async {
    await FavoriteService.toggleChef(chefId);

    if (mounted) {
      setState(() {
        _favoriteChefs = Set.from(FavoriteService.favoriteChefs);
      });
    }
  }

  Future<void> _toggleFavoriteRecipe(
    String recipeId,
    Map<String, dynamic> recipe,
  ) async {
    final enrichedRecipe = {
      ...recipe,
      'chefName': recipe['chef']?['name'] ?? recipe['chefName'] ?? 'Chef',
      'chefImage': recipe['chef']?['profileImage'] ?? recipe['chefImage'] ?? '',
    };

    if (mounted) {
      setState(() {
        if (_favoriteRecipes.contains(recipeId)) {
          _favoriteRecipes.remove(recipeId);
        } else {
          _favoriteRecipes.add(recipeId);
          addRecipeToGlobalFavorites(enrichedRecipe);
        }
      });
    }

    await _saveFavorites();
  }

  void _toggleFollowChef(String chefId) {
    if (mounted) {
      setState(() {
        if (_followingChefs.contains(chefId)) {
          _followingChefs.remove(chefId);
        } else {
          _followingChefs.add(chefId);
        }
        _saveFollowing();
      });
    }
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loadingChefs = true;
        _loadingBanners = true;
        _loadingTrending = true;
      });
      _contentAnim.forward(from: 0);
    }
    await Future.wait([_loadChefs(), _loadBanners(), _loadTrendingRecipes()]);
  }

  void _navigateToChefProfile(Map<String, dynamic> chef) {
    final chefId = chef['_id']?.toString() ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChefProfileScreen(chefId: chefId, chefData: chef),
      ),
    );
  }

  void _navigateToFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FavoritesPage(
          favoriteChefs: FavoriteService.favoriteChefs,
          favoriteRecipes: FavoriteService.favoriteRecipes,
          allChefs: _chefs,
          allRecipes: {
            for (final r in [
              ..._trendingRecipes,
              ...FavoriteService.favoriteRecipesDataNotifier.value,
            ])
              (r['_id'] ?? r['id']).toString(): r,
          }.values.toList(),
          onToggleFavoriteChef: _toggleFavoriteChef,
          onToggleFavoriteRecipe: _toggleFavoriteRecipe,
        ),
      ),
    );
  }

  void _goBack() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _showChefsBottomSheet(List<dynamic> chefs, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kTextDim.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _kText,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _kTextDim),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 8),
                Expanded(
                  child: chefs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant_menu_outlined,
                                size: 48,
                                color: _kTextDim.withOpacity(0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No chefs available',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _kTextDim,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: chefs.length,
                          itemBuilder: (context, index) {
                            final chef = chefs[index];
                            return _ChefListItem(
                              chef: chef,
                              onTap: () {
                                Navigator.pop(context);
                                _navigateToChefProfile(chef);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRecipesBottomSheet(List<dynamic> recipes, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kTextDim.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _kText,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _kTextDim),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 8),
                Expanded(
                  child: recipes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant_menu_outlined,
                                size: 48,
                                color: _kTextDim.withOpacity(0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No recipes available',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _kTextDim,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: recipes.length,
                          itemBuilder: (context, index) {
                            final recipe = recipes[index];
                            return _RecipeListItem(
                              recipe: recipe,
                              onTap: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Opening ${recipe['name']}...',
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: _kBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: FadeTransition(
            opacity: _contentAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 15),

                _buildHeroBanner(),
                const SizedBox(height: 24),
                _buildSectionHeader(
                  'Categories',
                  'See all →',
                  onTapAction: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => DraggableScrollableSheet(
                        initialChildSize: .82,
                        minChildSize: .55,
                        maxChildSize: .95,
                        expand: false,
                        builder: (context, controller) {
                          return Container(
                            decoration: const BoxDecoration(
                              color: _kSurface,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(28),
                              ),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 12),
                                Container(
                                  width: 45,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "All Categories",
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: _kText,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(),
                                Expanded(
                                  child: GridView.builder(
                                    controller: controller,
                                    padding: const EdgeInsets.all(20),
                                    itemCount: _categories.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          mainAxisSpacing: 18,
                                          crossAxisSpacing: 18,
                                          childAspectRatio: .92,
                                        ),
                                    itemBuilder: (_, i) {
                                      final cat = _categories[i];
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.pop(context);
                                          List<dynamic> filtered = [];
                                          if (cat.id == 'all') {
                                            filtered = _chefs;
                                          } else {
                                            filtered = _chefs.where((chef) {
                                              final raw = chef['specialty'];
                                              final s = raw is List
                                                  ? raw.join(',').toLowerCase()
                                                  : (raw ?? '')
                                                        .toString()
                                                        .toLowerCase();
                                              return s.contains(
                                                cat.id.toLowerCase(),
                                              );
                                            }).toList();
                                          }
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  CategoryChefsScreen(
                                                    categoryId: cat.id,
                                                    categoryName: cat.name,
                                                    preFilteredChefs: filtered,
                                                  ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  .05,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  14,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _kBluePale,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  cat.icon,
                                                  color: _kBlue,
                                                  size: 28,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                cat.name,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
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
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                _buildCategories(),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  '⭐ Top Chefs',
                  'See Rank',
                  onTapAction: () {
                    _showChefsBottomSheet(_chefs, 'Top Chefs');
                  },
                ),
                const SizedBox(height: 14),
                _buildTopChefs(),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  '🔥 Trending Recipes',
                  'View all →',
                  onTapAction: () {
                    _showRecipesBottomSheet(
                      _trendingRecipes,
                      'Trending Recipes',
                    );
                  },
                ),
                const SizedBox(height: 14),
                _buildTrendingRecipes(),
                const SizedBox(height: 28),
                _buildSectionHeader(
                  '👨‍🍳 All Chefs',
                  'View all →',
                  onTapAction: () {
                    _showChefsBottomSheet(_filteredChefs, 'All Chefs');
                  },
                ),
                const SizedBox(height: 14),
                _buildChefsGrid(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 1,
        onAddWaterTap: (amount) {
          final provider = Provider.of<HomeProvider>(context, listen: false);
          provider.addWaterBy(amount);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,

      title: SizedBox(height: 42, child: _buildTopSearchBar()),
      actions: [
        ValueListenableBuilder<Set<String>>(
          valueListenable: FavoriteService.favoriteRecipesNotifier,
          builder: (context, favs, _) {
            final totalFavorites =
                FavoriteService.favoriteChefs.length +
                FavoriteService.favoriteRecipes.length;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(
                    totalFavorites > 0
                        ? Icons.favorite
                        : Icons.favorite_border_rounded,
                    color: _kNavy,
                  ),
                  onPressed: _navigateToFavorites,
                ),
                if (totalFavorites > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: _kError,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$totalFavorites',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _kNavy,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined, color: _kNavy),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTopSearchBar() {
    return Container(
      height: 42,

      alignment: Alignment.center,

      padding: const EdgeInsets.symmetric(horizontal: 14),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(30),

        border: Border.all(color: Colors.grey.shade300, width: 1.2),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: TextField(
        controller: _searchController,

        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },

        decoration: InputDecoration(
          border: InputBorder.none,

          hintText: 'Search',

          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),

          icon: Icon(Icons.search, color: Colors.grey.shade600, size: 20),

          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close),

                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _avatarFallback(String letter) => Container(
    color: _kBlue,
    child: Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );

  Widget _buildHeroBanner() {
    if (_loadingBanners) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: 180,
            color: _kSurfaceHigh,
            child: const Center(
              child: CircularProgressIndicator(color: _kBlue),
            ),
          ),
        ),
      );
    }

    final hasBanners = _banners.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 180,
              child: PageView.builder(
                controller: _bannerCtrl,
                itemCount: hasBanners ? _banners.length : 1,
                onPageChanged: (i) {
                  if (mounted) setState(() => _bannerPage = i);
                },
                itemBuilder: (_, i) {
                  final b = hasBanners ? _banners[i] : null;
                  return _BannerCard(
                    imageUrl: b?['image'] ?? '',
                    title: b?['title'] ?? '',
                  );
                },
              ),
            ),
          ),
          if (hasBanners && _banners.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_banners.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _bannerPage == i ? 24 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _bannerPage == i ? _kBlue : _kBlue.withOpacity(0.25),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String action, {
    VoidCallback? onTapAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _kText,
              letterSpacing: -0.4,
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (onTapAction != null) {
                onTapAction();
              }
            },
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final isAct = _selectedCategory == i;

          return GestureDetector(
            onTap: () {
              if (mounted) setState(() => _selectedCategory = i);
              HapticFeedback.lightImpact();

              List<dynamic> filteredChefsForCategory = [];
              if (cat.id == 'all') {
                filteredChefsForCategory = _chefs;
              } else {
                filteredChefsForCategory = _chefs.where((chef) {
                  final raw = chef['specialty'];
                  final specialty = raw is List
                      ? raw.join(',').toLowerCase()
                      : (raw ?? '').toString().toLowerCase();
                  return specialty.contains(cat.id.toLowerCase());
                }).toList();
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryChefsScreen(
                    categoryId: cat.id,
                    categoryName: cat.name,
                    preFilteredChefs: filteredChefsForCategory,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isAct ? _kNavy : _kCard,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isAct
                      ? [
                          BoxShadow(
                            color: _kNavy.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                  border: isAct
                      ? null
                      : Border.all(color: _kOutline.withOpacity(0.5)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cat.icon, size: 26, color: isAct ? _kTeal : _kTextDim),
                    const SizedBox(height: 6),
                    Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isAct ? FontWeight.w700 : FontWeight.w500,
                        color: isAct ? _kTeal : _kTextDim,
                      ),
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

  Widget _buildTopChefs() {
    if (_loadingChefs) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator(color: _kBlue)),
      );
    }

    final chefs = _chefs.isEmpty ? <dynamic>[] : _chefs.take(6).toList();

    if (chefs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text('No chefs yet', style: TextStyle(color: _kTextDim)),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: chefs.length,
        itemBuilder: (_, i) {
          final chef = chefs[i] as Map<String, dynamic>;

          final name = (chef['name'] ?? 'Chef') as String;
          final img = (chef['profileImage'] ?? '') as String;
          final rating = ((chef['rating'] ?? 0) as num).toDouble();

          return GestureDetector(
            onTap: () => _navigateToChefProfile(chef),
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _kCard, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: _kNavy.withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: img.isNotEmpty
                              ? Image.network(
                                  fullImageUrl(img),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _chefAvatarFallback(name),
                                )
                              : _chefAvatarFallback(name),
                        ),
                      ),
                      Positioned(
                        bottom: -4,
                        right: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 11,
                                color: _kAmber,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: _kText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name.split(' ').take(2).join(' '),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendingRecipes() {
    if (_loadingTrending) {
      return const Center(child: CircularProgressIndicator(color: _kBlue));
    }

    if (_trendingRecipes.isEmpty) {
      return const Center(child: Text("No trending recipes"));
    }

    final recipes = _trendingRecipes.take(8).toList();

    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: recipes.length,
        itemBuilder: (_, i) {
          final recipe = Map<String, dynamic>.from(recipes[i]);

          final recipeId = (recipe['_id'] ?? recipe['id']).toString();

          final isFav = FavoriteService.isFavoriteRecipe(recipeId);

          final isTrending = i < 3;

          return Container(
            width: 220,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 12,
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
                        top: Radius.circular(24),
                      ),
                      child: Image.network(
                        fullImageUrl(recipe["image"]),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _recipeFallback(),
                      ),
                    ),
                    if (isTrending)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFFFB347), Color(0xFFFF8C42)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 11,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Trending",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () async {
                          await FavoriteService.toggleRecipe(recipe);
                          if (mounted) setState(() {});
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              key: ValueKey(isFav),
                              color: Colors.red,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe["name"] ?? "",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.star, color: _kAmber, size: 13),
                                  SizedBox(width: 4),
                                  Text(
                                    "${recipe["rating"] ?? 4.8}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Spacer(),
                            Text(
                              "\$${recipe["price"] ?? 0}",
                              style: TextStyle(
                                color: _kBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
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
                                  builder: (_) =>
                                      RecipeDetailScreen(recipe: recipe),
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
        },
      ),
    );
  }

  Widget _recipeFallback() {
    return Container(
      height: 145,
      color: _kBluePale,
      child: Center(child: Text("🍽️", style: TextStyle(fontSize: 42))),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _chefAvatarFallback(String name) => Container(
    color: _kBluePale,
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'C',
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: _kBlue,
        ),
      ),
    ),
  );
  Widget _buildChefsGrid() {
    if (_loadingChefs) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: _kBlue)),
      );
    }

    //
    // 🔥 SEARCH FILTER
    //
    final displayedChefs = _filteredChefs.where((chef) {
      final name = (chef['name'] ?? '').toString().toLowerCase();

      final specialty = safeString(chef['specialty']).toLowerCase();

      return name.contains(_searchQuery) || specialty.contains(_searchQuery);
    }).toList();

    //
    // 🔥 EMPTY STATE
    //
    if (displayedChefs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('No chefs found 🔍', style: TextStyle(color: _kTextDim)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),

      child: GridView.builder(
        shrinkWrap: true,

        physics: const NeverScrollableScrollPhysics(),

        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,

          crossAxisSpacing: 14,

          mainAxisSpacing: 14,

          childAspectRatio: 0.72,
        ),

        itemCount: displayedChefs.length,

        itemBuilder: (_, i) {
          final chef = displayedChefs[i];

          final chefId = chef['_id']?.toString() ?? i.toString();

          return _ChefCard(
            chef: chef,

            isFavourite: _favoriteChefs.contains(chefId),

            isFollowing: _followingChefs.contains(chefId),

            onFavouriteToggle: () => _toggleFavoriteChef(chefId),

            onFollowToggle: () => _toggleFollowChef(chefId),

            onTap: () => _navigateToChefProfile(chef),
          );
        },
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  const _BannerCard({required this.imageUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: imageUrl.isNotEmpty
            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
            : null,
        gradient: imageUrl.isEmpty
            ? const LinearGradient(
                colors: [_kNavy, Color(0xFF0A3264)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
          ),
        ),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Chef Card Widget
// ════════════════════════════════════════════════════════════════════════════
class _ChefCard extends StatelessWidget {
  final Map<String, dynamic> chef;
  final bool isFavourite;
  final bool isFollowing;
  final VoidCallback onFavouriteToggle;
  final VoidCallback onFollowToggle;
  final VoidCallback onTap;

  const _ChefCard({
    required this.chef,
    required this.isFavourite,
    required this.isFollowing,
    required this.onFavouriteToggle,
    required this.onFollowToggle,
    required this.onTap,
  });

  String get _bgEmoji {
    final s = (safeString(chef['specialty']) ?? '') as String;
    if (s.contains('Italian')) return '🍝';
    if (s.contains('Pastry') || s.contains('Dessert')) return '🍰';
    if (s.contains('Grill')) return '🥩';
    if (s.contains('Vegan')) return '🥗';
    if (s.contains('Seafood')) return '🐟';
    if (s.contains('Asian')) return '🍜';
    if (s.contains('Breakfast')) return '🍳';
    if (s.contains('Bakery')) return '🥖';
    return '👨‍🍳';
  }

  Color get _bgColor {
    final s = (safeString(chef['specialty']) ?? '') as String;
    if (s.contains('Italian')) return const Color(0xFFFFF3E0);
    if (s.contains('Pastry') || s.contains('Dessert')) {
      return const Color(0xFFFCE4EC);
    }
    if (s.contains('Grill')) return const Color(0xFFFFEBEE);
    if (s.contains('Vegan')) return const Color(0xFFE8F5E9);
    if (s.contains('Seafood')) return const Color(0xFFE0F7FA);
    if (s.contains('Breakfast')) return const Color(0xFFFFF8E1);
    return const Color(0xFFEFF6FF);
  }

  @override
  Widget build(BuildContext context) {
    final name = (chef['name'] ?? 'Chef') as String;
    final img = (chef['profileImage'] ?? '') as String;
    final specialty = safeString(chef['specialty']);
    final rating = ((chef['rating'] ?? 0) as num).toDouble();
    final dishes = chef['dishes'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _kNavy.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1.2,
                    child: img.isNotEmpty
                        ? Image.network(
                            fullImageUrl(img),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _imgFallback(),
                          )
                        : _imgFallback(),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      onFavouriteToggle();
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        isFavourite ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isFavourite ? _kError : _kTextDim,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 10,
                          color: _kAmber,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _kText,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    specialty,
                    style: const TextStyle(fontSize: 10, color: _kTextDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$dishes recipes',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2F486A),
                        ),
                      ),
                      GestureDetector(
                        onTap: onTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _kBlue,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'View profile',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
    color: _bgColor,
    child: Center(child: Text(_bgEmoji, style: const TextStyle(fontSize: 40))),
  );
}

String fullImageUrl(dynamic image) {
  if (image == null) return '';

  String img = image.toString().trim();

  if (img.isEmpty) return '';

  // ✅ full url
  if (img.startsWith('http://') || img.startsWith('https://')) {
    return img;
  }

  // ✅ remove localhost
  img = img.replaceAll('http://localhost:5000', '');

  img = img.replaceAll('http://127.0.0.1:5000', '');

  // ✅ fix uploads
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

// ════════════════════════════════════════════════════════════════════════════
// Chef List Item Widget
// ════════════════════════════════════════════════════════════════════════════
class _ChefListItem extends StatelessWidget {
  final Map<String, dynamic> chef;
  final VoidCallback onTap;

  const _ChefListItem({required this.chef, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (chef['name'] ?? 'Chef') as String;
    final img = (chef['profileImage'] ?? '') as String;
    final specialty = safeString(chef['specialty']);
    final rating = ((chef['rating'] ?? 0) as num).toDouble();
    final dishes = chef['dishes'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _kNavy.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 60,
                height: 60,
                color: _kBluePale,
                child: img.isNotEmpty
                    ? Image.network(fullImageUrl(img), fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _kBlue,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _kText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    specialty,
                    style: const TextStyle(fontSize: 11, color: _kTextDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 12, color: _kAmber),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.restaurant, size: 12, color: _kBlue),
                      const SizedBox(width: 2),
                      Text(
                        '$dishes dishes',
                        style: const TextStyle(fontSize: 11, color: _kTextDim),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _kTextDim),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Recipe List Item Widget
// ════════════════════════════════════════════════════════════════════════════
class _RecipeListItem extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final VoidCallback onTap;

  const _RecipeListItem({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = recipe['name'] ?? 'Recipe';
    final chefName = recipe['chefName'] ?? 'Chef';
    final price = recipe['price'] ?? 0;
    final rating = recipe['rating'] ?? 0;
    final orders = recipe['orders'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _kNavy.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 60,
                height: 60,
                color: _kBluePale,
                child:
                    recipe['image'] != null &&
                        recipe['image'].toString().isNotEmpty
                    ? Image.network(
                        fullImageUrl(recipe['image']),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return const Center(
                            child: Text('🍽️', style: TextStyle(fontSize: 30)),
                          );
                        },
                      )
                    : const Center(
                        child: Text('🍽️', style: TextStyle(fontSize: 30)),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _kText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'by $chefName',
                    style: const TextStyle(fontSize: 11, color: _kTextDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 12, color: _kAmber),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.trending_up, size: 12, color: _kBlue),
                      const SizedBox(width: 2),
                      Text(
                        '$orders orders',
                        style: const TextStyle(fontSize: 11, color: _kTextDim),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _kBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _kTextDim),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Search Delegate
// ════════════════════════════════════════════════════════════════════════════
class ChefSearchDelegate extends SearchDelegate<String> {
  final List<dynamic> chefs;
  final List<dynamic> recipes;

  ChefSearchDelegate(this.chefs, this.recipes);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white, fontSize: 16),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear, color: _kTeal),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: _kTeal),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final chefResults = chefs.where((chef) {
      final name = (chef['name'] ?? '').toString().toLowerCase();
      final specialty = safeString(chef['specialty']).toLowerCase();
      return name.contains(query.toLowerCase()) ||
          specialty.contains(query.toLowerCase());
    }).toList();

    final recipeResults = recipes.where((recipe) {
      final name = (recipe['name'] ?? '').toString().toLowerCase();
      final chefName = (recipe['chefName'] ?? '').toString().toLowerCase();
      return name.contains(query.toLowerCase()) ||
          chefName.contains(query.toLowerCase());
    }).toList();

    final hasChefResults = chefResults.isNotEmpty;
    final hasRecipeResults = recipeResults.isNotEmpty;

    if (chefResults.isEmpty && recipeResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results found for "$query"',
              style: const TextStyle(color: _kTextDim),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (hasChefResults) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '👨‍🍳 Chefs',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _kBlue,
              ),
            ),
          ),
          ...chefResults.map((chef) => _buildChefTile(chef, context)),
        ],
        if (hasRecipeResults) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '🍽️ Recipes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _kBlue,
              ),
            ),
          ),
          ...recipeResults.map((recipe) => _buildRecipeTile(recipe, context)),
        ],
      ],
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '🔍 Popular Searches',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _kBlue,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  [
                        'Italian',
                        'Sushi',
                        'Bakery',
                        'Pasta',
                        'Dessert',
                        'Vegan',
                        'Seafood',
                        'Grill',
                      ]
                      .map(
                        (term) => GestureDetector(
                          onTap: () {
                            query = term;
                            showResults(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _kBluePale,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              term,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _kBlue,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '⭐ Top Chefs',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _kBlue,
              ),
            ),
          ),
          ...chefs.take(5).map((chef) => _buildChefTile(chef, context)),
        ],
      );
    }

    final chefResults = chefs.where((chef) {
      final name = (chef['name'] ?? '').toString().toLowerCase();
      final specialty = safeString(chef['specialty']).toLowerCase();
      return name.contains(query.toLowerCase()) ||
          specialty.contains(query.toLowerCase());
    }).toList();

    final recipeResults = recipes.where((recipe) {
      final name = (recipe['name'] ?? '').toString().toLowerCase();
      final chefName = (recipe['chefName'] ?? '').toString().toLowerCase();
      return name.contains(query.toLowerCase()) ||
          chefName.contains(query.toLowerCase());
    }).toList();

    if (chefResults.isEmpty && recipeResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No chefs or recipes found for "$query"',
              style: const TextStyle(color: _kTextDim),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (chefResults.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              '👨‍🍳 Chefs',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _kBlue,
              ),
            ),
          ),
          ...chefResults.map((chef) => _buildChefTile(chef, context)),
        ],
        if (recipeResults.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '🍽️ Recipes',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _kBlue,
              ),
            ),
          ),
          ...recipeResults.map((recipe) => _buildRecipeTile(recipe, context)),
        ],
      ],
    );
  }

  Widget _buildChefTile(Map<String, dynamic> chef, BuildContext context) {
    final name = chef['name'] ?? 'Chef';
    final specialty = safeString(chef['specialty']);
    final rating = (chef['rating'] ?? 0).toDouble();
    final img = chef['profileImage'] ?? '';

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: img.isNotEmpty
            ? NetworkImage(fullImageUrl(img))
            : null,
        backgroundColor: _kBluePale,
        child: img.isEmpty
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'C',
                style: const TextStyle(
                  color: _kBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
            : null,
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, color: _kText),
      ),
      subtitle: Text(specialty, style: const TextStyle(color: _kTextDim)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: _kAmber),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w600, color: _kText),
          ),
        ],
      ),
      onTap: () {
        close(context, '');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChefProfileScreen(
              chefId: chef['_id']?.toString() ?? '',
              chefData: chef,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipeTile(Map<String, dynamic> recipe, BuildContext context) {
    final name = recipe['name'] ?? 'Recipe';
    final chefName = recipe['chefName'] ?? 'Chef';
    final price = recipe['price'] ?? 0;
    final rating = recipe['rating'] ?? 0;

    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: _kBluePale,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 24))),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, color: _kText),
      ),
      subtitle: Text('by $chefName', style: const TextStyle(color: _kTextDim)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: _kAmber),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w600, color: _kText),
          ),
          const SizedBox(width: 8),
          Text(
            '\$${price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: _kBlue),
          ),
        ],
      ),
      onTap: () {
        close(context, '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Opening $name...')));
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Favorite Chef Card
// ════════════════════════════════════════════════════════════════════════════
class _FavoriteChefCard extends StatelessWidget {
  final Map<String, dynamic> chef;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteChefCard({
    required this.chef,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = (chef['name'] ?? 'Chef') as String;
    final img = (chef['profileImage'] ?? '') as String;
    final specialty = safeString(chef['specialty']);
    final rating = ((chef['rating'] ?? 0) as num).toDouble();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _kNavy.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              flex: 5,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    child: SizedBox.expand(
                      child: img.isNotEmpty
                          ? Image.network(fullImageUrl(img), fit: BoxFit.cover)
                          : Container(
                              color: _kBluePale,
                              child: const Center(
                                child: Text(
                                  '👨‍🍳',
                                  style: TextStyle(fontSize: 56),
                                ),
                              ),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          size: 18,
                          color: _kError,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 11,
                            color: _kAmber,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    specialty,
                    style: const TextStyle(fontSize: 11, color: _kTextDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Favorite Recipe Card
// ════════════════════════════════════════════════════════════════════════════
class _FavoriteRecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final VoidCallback onRemove;

  const _FavoriteRecipeCard({required this.recipe, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name = recipe['name'] ?? '';
    final price = recipe['price'] ?? 0;
    final rating = recipe['rating'] ?? 0;
    final chefName = recipe['chefName'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kNavy.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _kBluePale,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
            ),
            child: const Center(
              child: Text('🍽️', style: TextStyle(fontSize: 40)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onRemove,
                        child: const Icon(
                          Icons.favorite,
                          size: 20,
                          color: _kError,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chefName,
                    style: const TextStyle(fontSize: 12, color: _kTextDim),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: _kAmber),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _kBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
