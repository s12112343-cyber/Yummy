// 📁 lib/features/home/category_chefs_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import 'chef_profile_screen.dart';

const _kNavy = Color(0xFF001F3F);
const _kBlue = Color(0xFF005EB2);
const _kBluePale = Color(0xFFD5E3FF);
const _kCard = Color(0xFFFFFFFF);
const _kText = Color(0xFF191C1D);
const _kTextDim = Color(0xFF43474E);
const _kAmber = Color(0xFFFBBF24);
const _kError = Color(0xFFBA1A1A);
const _kTeal = Color(0xFF76D2F6);

class CategoryChefsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final List<dynamic>? preFilteredChefs; // ✅ إضافة هذا

  const CategoryChefsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.preFilteredChefs, // ✅ اختياري
  });

  @override
  State<CategoryChefsScreen> createState() => _CategoryChefsScreenState();
}

class _CategoryChefsScreenState extends State<CategoryChefsScreen> {
  List<dynamic> _chefs = [];
  bool _isLoading = true;
  String? _errorMessage;
  Set<String> _favoriteChefs = {};
  Set<String> _followingChefs = {};

  @override
  void initState() {
    super.initState();
    _loadChefsByCategory();
    _loadFavorites();
    _loadFollowing();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final savedChefs = prefs.getStringList('favoriteChefs') ?? [];
    setState(() {
      _favoriteChefs = savedChefs.toSet();
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteChefs', _favoriteChefs.toList());
  }

  Future<void> _loadFollowing() async {
    final prefs = await SharedPreferences.getInstance();
    final following = prefs.getStringList('followingChefs') ?? [];
    setState(() {
      _followingChefs = following.toSet();
    });
  }

  Future<void> _saveFollowing() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('followingChefs', _followingChefs.toList());
  }

  void _toggleFavorite(String chefId) {
    setState(() {
      if (_favoriteChefs.contains(chefId)) {
        _favoriteChefs.remove(chefId);
      } else {
        _favoriteChefs.add(chefId);
      }
      _saveFavorites();
    });
  }

  void _toggleFollow(String chefId) {
    setState(() {
      if (_followingChefs.contains(chefId)) {
        _followingChefs.remove(chefId);
      } else {
        _followingChefs.add(chefId);
      }
      _saveFollowing();
    });
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

  Future<void> _loadChefsByCategory() async {
    // ✅ إذا تم تمرير البيانات مسبقاً، استخدمها مباشرة
    if (widget.preFilteredChefs != null &&
        widget.preFilteredChefs!.isNotEmpty) {
      setState(() {
        _chefs = widget.preFilteredChefs!;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse('${AppConfig.baseUrl}/chefs'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> allChefs = data['data'] ?? [];

        final filteredChefs = allChefs.where((chef) {
          final specialty = (chef['specialty'] ?? '').toString().toLowerCase();
          if (widget.categoryId == 'all') {
            return true;
          }
          return specialty.contains(widget.categoryId.toLowerCase());
        }).toList();

        setState(() {
          _chefs = filteredChefs;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load chefs. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading chefs: $e');
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _kNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kTeal),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.categoryName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _kTeal,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _kBlue));
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: _kTextDim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChefsByCategory,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_chefs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.restaurant_menu_outlined,
              size: 64,
              color: _kTextDim,
            ),
            const SizedBox(height: 16),
            Text(
              'No chefs found in ${widget.categoryName}',
              style: const TextStyle(fontSize: 16, color: _kTextDim),
            ),
            const SizedBox(height: 8),
            Text(
              'Try another category',
              style: TextStyle(fontSize: 14, color: _kTextDim.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChefsByCategory,
      color: _kBlue,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.72,
        ),
        itemCount: _chefs.length,
        itemBuilder: (context, index) {
          final chef = _chefs[index];
          final chefId = chef['_id']?.toString() ?? index.toString();
          return _CategoryChefCard(
            chef: chef,
            isFavourite: _favoriteChefs.contains(chefId),
            isFollowing: _followingChefs.contains(chefId),
            onFavouriteToggle: () => _toggleFavorite(chefId),
            onFollowToggle: () => _toggleFollow(chefId),
            onTap: () => _navigateToChefProfile(chef),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Category Chef Card Widget
// ════════════════════════════════════════════════════════════════════════════
class _CategoryChefCard extends StatelessWidget {
  final Map<String, dynamic> chef;
  final bool isFavourite;
  final bool isFollowing;
  final VoidCallback onFavouriteToggle;
  final VoidCallback onFollowToggle;
  final VoidCallback onTap;

  const _CategoryChefCard({
    required this.chef,
    required this.isFavourite,
    required this.isFollowing,
    required this.onFavouriteToggle,
    required this.onFollowToggle,
    required this.onTap,
  });

  String get _bgEmoji {
    final s = chef['specialty'] is List
        ? (chef['specialty'] as List).join(', ')
        : (chef['specialty'] ?? '').toString();
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
    final s = (chef['specialty'] ?? '').toString();
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
    final name = (chef['name'] ?? 'Chef').toString();
    final img = (chef['profileImage'] ?? '').toString();
    final specialty = chef['specialty'] is List
        ? (chef['specialty'] as List).join(', ')
        : (chef['specialty'] ?? 'Chef').toString();
    final rating = ((chef['rating'] ?? 0) as num).toDouble();
    final dishes = chef['dishes'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
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
                          ? Image.network(
                              img,
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
                          color: Colors.white.withOpacity(0.85),
                          shape: BoxShape.circle,
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
                        color: Colors.white.withOpacity(0.85),
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
            ),
            Padding(
              padding: const EdgeInsets.all(10),
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
                        '$dishes dishes',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2F486A),
                        ),
                      ),
                      GestureDetector(
                        onTap: onTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _kBlue,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'View',
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

  Widget _imgFallback() {
    return Container(
      color: _bgColor,
      child: Center(
        child: Text(_bgEmoji, style: const TextStyle(fontSize: 40)),
      ),
    );
  }
}
