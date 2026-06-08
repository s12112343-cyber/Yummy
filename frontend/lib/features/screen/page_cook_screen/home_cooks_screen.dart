import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/core/services/favorite_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/home_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../models/category_model.dart';
import '../../../shared/custom_bottom_nav.dart';
import '../../home/home_screen.dart';
import 'CartScreen.dart';
import 'category_chefs_screen.dart';
import 'chef_profile_screen.dart';
import 'favorites_page.dart';
import 'recipe_detail_screen.dart';

// ─── Colour Palette ──────────────────────────────────────────────────────────
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

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Converts a specialty field that may be a List or a String into a String.
String safeString(dynamic value) {
  if (value == null) return '';
  if (value is List) return value.map((e) => e.toString()).join(', ');
  return value.toString();
}

/// Returns an absolute image URL from a relative or absolute path.
String fullImageUrl(dynamic image) {
  if (image == null) return '';
  String img = image.toString().trim();
  if (img.isEmpty) return '';

  if (img.startsWith('http://') || img.startsWith('https://')) return img;

  img = img
      .replaceAll('http://localhost:5000', '')
      .replaceAll('http://127.0.0.1:5000', '');

  if (!img.startsWith('/uploads/')) {
    img = img.startsWith('uploads/') ? '/$img' : '/uploads/$img';
  }

  final base = AppConfig.baseUrl.replaceAll('/api', '');
  return '$base$img';
}

final Map<String, List<String>> _palestineAreaKeywords = {
  'القدس': ['القدس', 'jerusalem', 'al quds'],
  'رام الله': ['رام الله', 'ramallah', 'ram allah', 'البيرة', 'al bireh'],
  'نابلس': ['نابلس', 'nablus'],
  'الخليل': ['الخليل', 'hebron'],
  'بيت لحم': ['بيت لحم', 'bethlehem'],
  'جنين': ['جنين', 'jenin'],
  'طولكرم': ['طولكرم', 'tulkarm', 'tulkarem'],
  'قلقيلية': ['قلقيلية', 'qalqilya', 'qalqilia'],
  'سلفيت': ['سلفيت', 'salfit'],
  'أريحا': ['أريحا', 'اريحا', 'jericho'],
  'طوباس': ['طوباس', 'tubas'],
  'غزة': ['غزة', 'gaza'],
};

final Map<String, ({double lat, double lng})> _palestineAreaCenters = {
  'القدس': (lat: 31.7683, lng: 35.2137),
  'رام الله': (lat: 31.9038, lng: 35.2034),
  'نابلس': (lat: 32.2211, lng: 35.2544),
  'الخليل': (lat: 31.5326, lng: 35.0998),
  'بيت لحم': (lat: 31.7054, lng: 35.2024),
  'جنين': (lat: 32.4594, lng: 35.3009),
  'طولكرم': (lat: 32.3104, lng: 35.0286),
  'قلقيلية': (lat: 32.1960, lng: 34.9819),
  'سلفيت': (lat: 32.0837, lng: 35.1808),
  'أريحا': (lat: 31.8560, lng: 35.4599),
  'طوباس': (lat: 32.3209, lng: 35.3699),
  'غزة': (lat: 31.5017, lng: 34.4668),
};

String _normalizeLocationText(String value) {
  return value
      .toLowerCase()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[,،\-_/]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _areaFromText(String value) {
  final normalized = _normalizeLocationText(value);

  for (final entry in _palestineAreaKeywords.entries) {
    final matched = entry.value.any((keyword) {
      return normalized.contains(_normalizeLocationText(keyword));
    });

    if (matched) return entry.key;
  }

  return value.trim();
}

String _nearestAreaFromCoordinates(double latitude, double longitude) {
  String closestArea = 'رام الله';
  double closestDistance = double.infinity;

  for (final entry in _palestineAreaCenters.entries) {
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      entry.value.lat,
      entry.value.lng,
    );

    if (distance < closestDistance) {
      closestDistance = distance;
      closestArea = entry.key;
    }
  }

  return closestArea;
}

// ─────────────────────────────────────────────────────────────────────────────
// HomeCooksScreen
// ─────────────────────────────────────────────────────────────────────────────
class HomeCooksScreen extends StatefulWidget {
  const HomeCooksScreen({super.key});

  @override
  State<HomeCooksScreen> createState() => _HomeCooksScreenState();
}

class _HomeCooksScreenState extends State<HomeCooksScreen>
    with TickerProviderStateMixin {
  // ── User state ──────────────────────────────────────────────────────────────
  String _userName = '';
  String _userAvatar = '';
  bool _loading = true;

  // ── Data ────────────────────────────────────────────────────────────────────
  List<dynamic> _chefs = [];
  List<dynamic> _filteredChefs = [];
  List<dynamic> _trendingRecipes = [];
  List<dynamic> _banners = [];
  final List<dynamic> _allRecipes = [];

  bool _loadingChefs = true;
  bool _loadingBanners = true;
  bool _loadingTrending = true;

  // ── Search ──────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final ScrollController _pageScrollController = ScrollController();
  final GlobalKey _storesSectionKey = GlobalKey();
  String _searchQuery = '';
  final List<String> _selectedUserLocations = [];
  bool _isGettingGpsLocation = false;

  String get _selectedUserLocation => _selectedUserLocations.join(', ');

  // ── Favourites / Following ───────────────────────────────────────────────────
  int _selectedCategory = 0;
  Set<String> _favoriteChefs = {};
  Set<String> _favoriteRecipes = {};
  Set<String> _followingChefs = {};

  // ── Banner slider ────────────────────────────────────────────────────────────
  final PageController _bannerCtrl = PageController();
  int _bannerPage = 0;
  Timer? _bannerTimer;

  // ── Animations ───────────────────────────────────────────────────────────────
  late AnimationController _headerAnim;
  late AnimationController _contentAnim;

  // ── Categories ───────────────────────────────────────────────────────────────
  static const List<CategoryModel> _categories = [
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

  // ── Lifecycle ────────────────────────────────────────────────────────────────
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
    _loadSavedUserLocation();
    _loadChefs();
    _loadBanners();
    _loadTrendingRecipes();
    _loadFavorites();
    _loadFollowing();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _searchController.dispose();
    _locationController.dispose();
    _pageScrollController.dispose();
    _bannerCtrl.dispose();
    _headerAnim.dispose();
    _contentAnim.dispose();
    super.dispose();
  }

  // ── Data Loading ─────────────────────────────────────────────────────────────

  Future<void> _loadUser() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = p.getString('userName') ?? 'Guest';
      _userAvatar = p.getString('userAvatar') ?? '';
      _loading = false;
    });
  }

  Future<void> _loadSavedUserLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocations = prefs.getStringList('userSelectedLocations') ?? [];
    final oldSavedLocation = prefs.getString('userSelectedLocation') ?? '';

    final cleanedLocations = <String>{
      ...savedLocations.map(_areaFromText).where((e) => e.trim().isNotEmpty),
      if (oldSavedLocation.trim().isNotEmpty) _areaFromText(oldSavedLocation),
    }.toList();

    if (!mounted || cleanedLocations.isEmpty) return;

    setState(() {
      _selectedUserLocations
        ..clear()
        ..addAll(cleanedLocations);
    });
  }

  Future<void> _saveUserLocations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('userSelectedLocations', _selectedUserLocations);
    await prefs.setString('userSelectedLocation', _selectedUserLocation);
  }

  void _applyLocationFilter(String location) {
    final cleanedLocation = _areaFromText(location).trim();

    if (cleanedLocation.isEmpty) return;

    if (cleanedLocation == 'All') {
      _clearLocationFilter();
      return;
    }

    final alreadyExists = _selectedUserLocations.any((item) {
      return _normalizeLocationText(item) ==
          _normalizeLocationText(cleanedLocation);
    });

    if (!alreadyExists) {
      _selectedUserLocations.add(cleanedLocation);
    }

    _locationController.clear();
    _applySelectedLocationFilters();
  }

  void _removeLocationFilter(String location) {
    _selectedUserLocations.removeWhere((item) {
      return _normalizeLocationText(item) == _normalizeLocationText(location);
    });

    _applySelectedLocationFilters();
  }

  void _applySelectedLocationFilters() {
    final normalizedUserLocations = _selectedUserLocations
        .map(_normalizeLocationText)
        .where((item) => item.isNotEmpty)
        .toList();

    final filtered = normalizedUserLocations.isEmpty
        ? _chefs
        : _chefs.where((chef) {
            final rawLocation = (chef['location'] ?? '').toString();
            final chefLocation = _areaFromText(rawLocation);
            final normalizedChefLocation = _normalizeLocationText(chefLocation);
            final normalizedRawLocation = _normalizeLocationText(rawLocation);

            return normalizedUserLocations.any((userLocation) {
              return normalizedChefLocation.contains(userLocation) ||
                  normalizedRawLocation.contains(userLocation) ||
                  userLocation.contains(normalizedChefLocation);
            });
          }).toList();

    if (!mounted) return;
    setState(() {
      _filteredChefs = filtered;
    });

    _saveUserLocations();
  }

  void _clearLocationFilter() {
    if (!mounted) return;
    setState(() {
      _selectedUserLocations.clear();
      _locationController.clear();
      _filteredChefs = _chefs;
    });
    _saveUserLocations();
  }

  Future<void> _useGpsLocation() async {
    if (!mounted) return;

    setState(() => _isGettingGpsLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      debugPrint('GPS LAT: ${position.latitude}');
      debugPrint('GPS LNG: ${position.longitude}');

      final nearestArea = _nearestAreaFromCoordinates(
        position.latitude,
        position.longitude,
      );

      _applyLocationFilter(nearestArea);
      _scrollToStoresSection();
    } catch (e) {
      debugPrint('GPS ERROR DETAILS: $e');
    } finally {
      if (mounted) {
        setState(() => _isGettingGpsLocation = false);
      }
    }
  }

  void _scrollToStoresSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storesContext = _storesSectionKey.currentContext;
      if (storesContext == null) return;

      Scrollable.ensureVisible(
        storesContext,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _favoriteChefs = (prefs.getStringList('favoriteChefs') ?? []).toSet();
      _favoriteRecipes = (prefs.getStringList('favoriteRecipes') ?? []).toSet();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteChefs', _favoriteChefs.toList());
    await prefs.setStringList('favoriteRecipes', _favoriteRecipes.toList());
  }

  Future<void> _loadFollowing() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _followingChefs = (prefs.getStringList('followingChefs') ?? []).toSet();
    });
  }

  Future<void> _saveFollowing() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('followingChefs', _followingChefs.toList());
  }

  Future<Map<String, String>?> _authHeaders() async {
    final token = await AuthService().getToken();
    if (token != null && token.trim().isNotEmpty) {
      return {'Authorization': 'Bearer $token'};
    }
    return null;
  }

  Future<void> _loadChefs() async {
    if (!mounted) return;
    setState(() => _loadingChefs = true);

    try {
      final r = await http.get(
        Uri.parse('${AppConfig.baseUrl}/chefs'),
        headers: await _authHeaders(),
      );

      if (r.statusCode == 200) {
        final list = ((jsonDecode(r.body)['data'] ?? []) as List)
          ..sort(
            (a, b) => ((b['rating'] ?? 0) as num).compareTo(
              (a['rating'] ?? 0) as num,
            ),
          );

        if (mounted) {
          setState(() {
            _chefs = list;
            _filteredChefs = list;
            _loadingChefs = false;
          });

          if (_selectedUserLocations.isNotEmpty) {
            _applySelectedLocationFilters();
          }
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
      debugPrint('❌ Error loading chefs: $e');
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
    setState(() => _loadingTrending = true);

    try {
      final r = await http.get(
        Uri.parse('${AppConfig.baseUrl}/recipes/trending'),
        headers: await _authHeaders(),
      );

      if (r.statusCode == 200) {
        final raw = (jsonDecode(r.body)['data'] ?? []) as List;

        if (mounted) {
          setState(() {
            _trendingRecipes = raw.map<Map<String, dynamic>>((item) {
              final m = Map<String, dynamic>.from(item ?? {});
              m['image'] = fullImageUrl(
                m['image'] ?? m['dishImage'] ?? m['photo'] ?? '',
              );
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
        if (mounted)
          setState(() {
            _trendingRecipes = [];
            _loadingTrending = false;
          });
      }
    } catch (e) {
      debugPrint('❌ Error loading trending recipes: $e');
      if (mounted)
        setState(() {
          _trendingRecipes = [];
          _loadingTrending = false;
        });
    }
  }

  Future<void> _loadBanners() async {
    if (!mounted) return;
    setState(() => _loadingBanners = true);

    try {
      final r = await http.get(
        Uri.parse('${AppConfig.baseUrl}/banners'),
        headers: await _authHeaders(),
      );

      if (r.statusCode == 200) {
        if (mounted) {
          setState(() {
            _banners = jsonDecode(r.body)['banners'] ?? [];
            _loadingBanners = false;
          });
          _startBannerTimer();
        }
      } else {
        if (mounted) setState(() => _loadingBanners = false);
      }
    } catch (e) {
      debugPrint('❌ Error loading banners: $e');
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

  // ── Favourites / Following ───────────────────────────────────────────────────

  void addRecipeToGlobalFavorites(Map<String, dynamic> recipe) {
    final recipeId = (recipe['_id'] ?? recipe['id']).toString();
    final exists = _allRecipes.any(
      (r) => (r['_id'] ?? r['id']).toString() == recipeId,
    );
    if (!exists) setState(() => _allRecipes.add(recipe));
  }

  Future<void> _toggleFavoriteChef(String chefId) async {
    await FavoriteService.toggleChef(chefId);
    if (mounted)
      setState(() => _favoriteChefs = Set.from(FavoriteService.favoriteChefs));
  }

  Future<void> _toggleFavoriteRecipe(
    String recipeId,
    Map<String, dynamic> recipe,
  ) async {
    final enriched = {
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
          addRecipeToGlobalFavorites(enriched);
        }
      });
    }
    await _saveFavorites();
  }

  void _toggleFollowChef(String chefId) {
    if (!mounted) return;
    setState(() {
      _followingChefs.contains(chefId)
          ? _followingChefs.remove(chefId)
          : _followingChefs.add(chefId);
    });
    _saveFollowing();
  }

  // ── Filtering ────────────────────────────────────────────────────────────────

  List<dynamic> _chefsForCategory(String categoryId) {
    if (categoryId == 'all') return _chefs;
    return _chefs.where((chef) {
      final raw = chef['specialty'];
      final specialty = raw is List
          ? raw.join(',').toLowerCase()
          : (raw ?? '').toString().toLowerCase();
      return specialty.contains(categoryId.toLowerCase());
    }).toList();
  }

  // ── Navigation ───────────────────────────────────────────────────────────────

  void _navigateToChefProfile(Map<String, dynamic> chef) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChefProfileScreen(
          chefId: chef['_id']?.toString() ?? '',
          chefData: chef,
        ),
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

  // ── Bottom Sheets ────────────────────────────────────────────────────────────

  void _showChefsBottomSheet(List<dynamic> chefs, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _sheetHandle(),
              _sheetHeader(title, context),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 8),
              Expanded(
                child: chefs.isEmpty
                    ? _emptyState('No chefs available')
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: chefs.length,
                        itemBuilder: (_, i) => _ChefListItem(
                          chef: chefs[i],
                          onTap: () {
                            Navigator.pop(context);
                            _navigateToChefProfile(chefs[i]);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
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
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _sheetHandle(),
              _sheetHeader(title, context),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 8),
              Expanded(
                child: recipes.isEmpty
                    ? _emptyState('No recipes available')
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: recipes.length,
                        itemBuilder: (_, i) => _RecipeListItem(
                          recipe: recipes[i],
                          onTap: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Opening ${recipes[i]['name']}...',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Small shared widgets ──────────────────────────────────────────────────────

  Widget _sheetHandle() => Container(
    margin: const EdgeInsets.only(top: 12),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: _kTextDim.withOpacity(0.3),
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _sheetHeader(String title, BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
  );

  Widget _emptyState(String message) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.restaurant_menu_outlined,
          size: 48,
          color: _kTextDim.withOpacity(0.5),
        ),
        const SizedBox(height: 12),
        Text(message, style: const TextStyle(fontSize: 14, color: _kTextDim)),
      ],
    ),
  );

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

  Widget _recipeFallback() => Container(
    height: 145,
    color: _kBluePale,
    child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 42))),
  );

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return CustomResponsiveNavShell(
      currentIndex: 1,
      backgroundColor: _kSurface,
      onAddWaterTap: (amount) {
        Provider.of<HomeProvider>(context, listen: false).addWaterBy(amount);
      },
      child: Scaffold(
        backgroundColor: _kSurface,
        appBar: _buildAppBar(),
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: _kBlue,
          child: SingleChildScrollView(
            controller: _pageScrollController,
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
                    onTapAction: _showAllCategoriesSheet,
                  ),
                  const SizedBox(height: 14),
                  _buildCategories(),
                  const SizedBox(height: 28),

                  _buildSectionHeader(
                    '⭐ Top Chefs',
                    'See Rank',
                    onTapAction: () =>
                        _showChefsBottomSheet(_chefs, 'Top Chefs'),
                  ),
                  const SizedBox(height: 14),
                  _buildTopChefs(),
                  const SizedBox(height: 28),

                  _buildSectionHeader(
                    '🔥 Trending Recipes',
                    'View all →',
                    onTapAction: () => _showRecipesBottomSheet(
                      _trendingRecipes,
                      'Trending Recipes',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildTrendingRecipes(),
                  const SizedBox(height: 28),

                  KeyedSubtree(
                    key: _storesSectionKey,
                    child: _buildSectionHeader(
                      '👨‍🍳 All Chefs',
                      'View all →',
                      onTapAction: () =>
                          _showChefsBottomSheet(_filteredChefs, 'All Chefs'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildChefsGrid(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      titleSpacing: 10,
      title: SizedBox(height: 42, child: _buildSearchBar()),
      actions: [
        _buildLocationSideButton(),
        _buildFavouriteButton(),
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined, color: _kNavy),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildFavouriteButton() {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: FavoriteService.favoriteRecipesNotifier,
      builder: (_, __, ___) {
        final total =
            FavoriteService.favoriteChefs.length +
            FavoriteService.favoriteRecipes.length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: Icon(
                total > 0 ? Icons.favorite : Icons.favorite_border_rounded,
                color: _kNavy,
              ),
              onPressed: _navigateToFavorites,
            ),
            if (total > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: _kError,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$total',
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
    );
  }

  Widget _buildLocationSideButton() {
    final count = _selectedUserLocations.length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: count == 0 ? 'Choose locations' : _selectedUserLocation,
          icon: const Icon(Icons.location_on_rounded, color: _kNavy),
          onPressed: _openLocationSheet,
        ),
        if (count > 0)
          Positioned(
            right: 5,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: const BoxDecoration(
                color: _kBlue,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openLocationSheet() {
    _locationController.clear();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void refreshSheet() {
              if (mounted) setState(() {});
              setSheetState(() {});
            }

            void addTypedLocation() {
              final value = _locationController.text.trim();
              if (value.isEmpty) return;
              _applyLocationFilter(value);
              refreshSheet();
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 18,
                    right: 18,
                    top: 12,
                    bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _kOutline.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _kBluePale,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: _kBlue,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Choose your locations',
                                  style: TextStyle(
                                    color: _kText,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Add one or more areas to find nearby stores',
                                  style: TextStyle(
                                    color: _kTextDim,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: _kNavy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _locationController,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => addTypedLocation(),
                              decoration: InputDecoration(
                                hintText: 'Example: رام الله، نابلس، الخليل',
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: _kBlue,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF7FAFE),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: _kOutline.withOpacity(0.4),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: _kOutline.withOpacity(0.4),
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(16),
                                  ),
                                  borderSide: BorderSide(
                                    color: _kBlue,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: addTypedLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _kBlue,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Add',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: _isGettingGpsLocation
                              ? null
                              : () async {
                                  await _useGpsLocation();
                                  refreshSheet();
                                },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _kOutline.withOpacity(0.55),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _isGettingGpsLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.my_location_rounded,
                                  color: _kBlue,
                                ),
                          label: const Text(
                            'Use GPS location',
                            style: TextStyle(
                              color: _kNavy,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_selectedUserLocations.isNotEmpty) ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Selected areas',
                                style: TextStyle(
                                  color: _kText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _clearLocationFilter();
                                refreshSheet();
                              },
                              child: const Text(
                                'Clear all',
                                style: TextStyle(
                                  color: _kError,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedUserLocations.map((area) {
                            return InputChip(
                              label: Text(area),
                              avatar: const Icon(
                                Icons.location_on_rounded,
                                size: 16,
                                color: _kBlue,
                              ),
                              onDeleted: () {
                                _removeLocationFilter(area);
                                refreshSheet();
                              },
                              backgroundColor: _kBluePale.withOpacity(0.65),
                              labelStyle: const TextStyle(
                                color: _kNavy,
                                fontWeight: FontWeight.w800,
                              ),
                              deleteIconColor: _kError,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                                side: BorderSide(
                                  color: _kOutline.withOpacity(0.25),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                      ],
                      const Text(
                        'Quick areas',
                        style: TextStyle(
                          color: _kText,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _palestineAreaKeywords.keys.map((area) {
                          final selected = _selectedUserLocations.any((item) {
                            return _normalizeLocationText(item) ==
                                _normalizeLocationText(area);
                          });

                          return GestureDetector(
                            onTap: () {
                              if (selected) {
                                _removeLocationFilter(area);
                              } else {
                                _applyLocationFilter(area);
                              }
                              refreshSheet();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selected ? _kBlue : _kBluePale,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                area,
                                style: TextStyle(
                                  color: selected ? Colors.white : _kBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchBar() {
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
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
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
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );
  }

  // ── Hero Banner ───────────────────────────────────────────────────────────────

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
                onPageChanged: (i) => setState(() => _bannerPage = i),
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

  // ── User Location Filter ─────────────────────────────────────────────────────

  Widget _buildLocationSelector() {
    final hasLocation = _selectedUserLocation.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _kOutline.withOpacity(0.45)),
          boxShadow: [
            BoxShadow(
              color: _kNavy.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _kBluePale,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: _kBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Find stores near you',
                        style: TextStyle(
                          color: _kText,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasLocation
                            ? 'Showing stores in $_selectedUserLocation'
                            : 'Type your area or use GPS',
                        style: const TextStyle(
                          color: _kTextDim,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasLocation)
                  TextButton(
                    onPressed: _clearLocationFilter,
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        color: _kError,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _applyLocationFilter,
                    decoration: InputDecoration(
                      hintText: 'Example: رام الله، نابلس، الخليل',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _kBlue,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7FAFE),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: _kOutline.withOpacity(0.4),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: _kOutline.withOpacity(0.4),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: _kBlue, width: 1.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isGettingGpsLocation ? null : _useGpsLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kNavy,
                      disabledBackgroundColor: _kNavy.withOpacity(0.55),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _isGettingGpsLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.my_location_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                    label: const Text(
                      'GPS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _palestineAreaKeywords.keys.take(8).map((area) {
                final selected =
                    _normalizeLocationText(area) ==
                    _normalizeLocationText(_selectedUserLocation);

                return GestureDetector(
                  onTap: () => _applyLocationFilter(area),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? _kBlue : _kBluePale,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      area,
                      style: TextStyle(
                        color: selected ? Colors.white : _kBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Header ────────────────────────────────────────────────────────────

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
              onTapAction?.call();
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

  // ── Categories ────────────────────────────────────────────────────────────────

  void _showAllCategoriesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .82,
        minChildSize: .55,
        maxChildSize: .95,
        expand: false,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'All Categories',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _kText,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoryChefsScreen(
                              categoryId: cat.id,
                              categoryName: cat.name,
                              preFilteredChefs: _chefsForCategory(cat.id),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: _kBluePale,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(cat.icon, color: _kBlue, size: 28),
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
        ),
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
              setState(() => _selectedCategory = i);
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryChefsScreen(
                    categoryId: cat.id,
                    categoryName: cat.name,
                    preFilteredChefs: _chefsForCategory(cat.id),
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

  // ── Top Chefs ─────────────────────────────────────────────────────────────────

  Widget _buildTopChefs() {
    if (_loadingChefs) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator(color: _kBlue)),
      );
    }

    final chefs = _chefs.take(6).toList();
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

  // ── Trending Recipes ──────────────────────────────────────────────────────────

  Widget _buildTrendingRecipes() {
    if (_loadingTrending) {
      return const Center(child: CircularProgressIndicator(color: _kBlue));
    }
    if (_trendingRecipes.isEmpty) {
      return const Center(child: Text('No trending recipes'));
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
          final isTrend = i < 3;

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
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image ──
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: Image.network(
                        fullImageUrl(recipe['image']),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _recipeFallback(),
                      ),
                    ),
                    if (isTrend)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB347), Color(0xFFFF8C42)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 11,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Trending',
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
                            key: ValueKey(isFav),
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: Colors.red,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Info ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe['name'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: _kAmber,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${recipe['rating'] ?? 4.8}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '\$${recipe['price'] ?? 0}',
                              style: const TextStyle(
                                color: _kBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 34,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    RecipeDetailScreen(recipe: recipe),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kBlue,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'View',
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

  // ── Chefs Grid ────────────────────────────────────────────────────────────────

  Widget _buildChefsGrid() {
    if (_loadingChefs) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: _kBlue)),
      );
    }

    final displayed = _filteredChefs.where((chef) {
      final name = (chef['name'] ?? '').toString().toLowerCase();
      final specialty = safeString(chef['specialty']).toLowerCase();
      return name.contains(_searchQuery) || specialty.contains(_searchQuery);
    }).toList();

    if (displayed.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No chefs found near this area 🔍',
            style: TextStyle(color: _kTextDim),
          ),
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
        itemCount: displayed.length,
        itemBuilder: (_, i) {
          final chef = displayed[i];
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

// ─────────────────────────────────────────────────────────────────────────────
// _BannerCard
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// _ChefCard
// ─────────────────────────────────────────────────────────────────────────────
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
    final s = safeString(chef['specialty']);
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
    final s = safeString(chef['specialty']);
    if (s.contains('Italian')) return const Color(0xFFFFF3E0);
    if (s.contains('Pastry') || s.contains('Dessert'))
      return const Color(0xFFFCE4EC);
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
            // ── Image ──
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
                            errorBuilder: (_, __, ___) => _imgFallback(),
                          )
                        : _imgFallback(),
                  ),
                ),
                // Favourite button
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
                // Rating badge
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

            // ── Info ──
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

// ─────────────────────────────────────────────────────────────────────────────
// _ChefListItem
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// _RecipeListItem
// ─────────────────────────────────────────────────────────────────────────────
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
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('🍽️', style: TextStyle(fontSize: 30)),
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// ChefSearchDelegate
// ─────────────────────────────────────────────────────────────────────────────
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
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.clear, color: _kTeal),
      onPressed: () => query = '',
    ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back, color: _kTeal),
    onPressed: () => close(context, ''),
  );

  List<dynamic> _matchingChefs() => chefs.where((chef) {
    final name = (chef['name'] ?? '').toString().toLowerCase();
    final specialty = safeString(chef['specialty']).toLowerCase();
    return name.contains(query.toLowerCase()) ||
        specialty.contains(query.toLowerCase());
  }).toList();

  List<dynamic> _matchingRecipes() => recipes.where((recipe) {
    final name = (recipe['name'] ?? '').toString().toLowerCase();
    final chefName = (recipe['chefName'] ?? '').toString().toLowerCase();
    return name.contains(query.toLowerCase()) ||
        chefName.contains(query.toLowerCase());
  }).toList();

  @override
  Widget buildResults(BuildContext context) {
    final cf = _matchingChefs();
    final rf = _matchingRecipes();

    if (cf.isEmpty && rf.isEmpty) return _noResults(context);

    return ListView(
      children: [
        if (cf.isNotEmpty) ...[
          _sectionLabel('👨‍🍳 Chefs'),
          ...cf.map((c) => _buildChefTile(c, context)),
        ],
        if (rf.isNotEmpty) ...[
          _sectionLabel('🍽️ Recipes'),
          ...rf.map((r) => _buildRecipeTile(r, context)),
        ],
      ],
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return ListView(
        children: [
          _sectionLabel('🔍 Popular Searches'),
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
          _sectionLabel('⭐ Top Chefs'),
          ...chefs.take(5).map((c) => _buildChefTile(c, context)),
        ],
      );
    }

    final cf = _matchingChefs();
    final rf = _matchingRecipes();

    if (cf.isEmpty && rf.isEmpty) return _noResults(context);

    return ListView(
      children: [
        if (cf.isNotEmpty) ...[
          _sectionLabel('👨‍🍳 Chefs'),
          ...cf.map((c) => _buildChefTile(c, context)),
        ],
        if (rf.isNotEmpty) ...[
          _sectionLabel('🍽️ Recipes'),
          ...rf.map((r) => _buildRecipeTile(r, context)),
        ],
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: _kBlue,
      ),
    ),
  );

  Widget _noResults(BuildContext context) => Center(
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
            builder: (_) => ChefProfileScreen(
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

// ─────────────────────────────────────────────────────────────────────────────
// _FavoriteChefCard
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// _FavoriteRecipeCard
// ─────────────────────────────────────────────────────────────────────────────
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
            decoration: const BoxDecoration(
              color: _kBluePale,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
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
