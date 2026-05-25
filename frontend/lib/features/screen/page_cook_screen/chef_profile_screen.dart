import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import 'recipe_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'saved_recipes_screen.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/favorite_service.dart';
import 'CartScreen.dart';
import '../../../core/services/chef_socket_service.dart';
import '../../../core/services/saved_service.dart';

const _kBlue = Color(0xFF005EB2);
const _kBluePale = Color(0xFFD5E3FF);
const _kCard = Color(0xFFFFFFFF);
const _kSurface = Color(0xFFF8F9FA);
const _kText = Color(0xFF191C1D);
const _kTextDim = Color(0xFF43474E);
const _kOutline = Color(0xFFC4C6CF);
const _kAmber = Color(0xFFFBBF24);
const _kError = Color(0xFFBA1A1A);

// ✅ دالة تحويل آمنة للتعامل مع List أو String
String safeString(dynamic value) {
  if (value == null) return '';
  if (value is List) {
    return value.map((e) => e.toString()).join(', ');
  }
  return value.toString();
}

String fullImageUrl(dynamic image) {
  if (image == null) return '';

  String img = image.toString().trim();

  if (img.isEmpty) return '';

  // ✅ already full url
  if (img.startsWith('http://') || img.startsWith('https://')) {
    return img;
  }

  // ✅ remove localhost
  img = img.replaceAll('http://localhost:5000', '');

  img = img.replaceAll('http://127.0.0.1:5000', '');

  // ✅ uploads path
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

class ChefProfileScreen extends StatefulWidget {
  final String chefId;
  final Map<String, dynamic>? chefData;

  const ChefProfileScreen({super.key, required this.chefId, this.chefData});

  @override
  State<ChefProfileScreen> createState() => _ChefProfileScreenState();
}

class _ChefProfileScreenState extends State<ChefProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _chef;

  bool _loadingChef = true;
  bool _loadingRecipes = true;
  bool _loadingReviews = true;

  String? _errorMessage;
  String _sortRecipesBy = 'popular';
  String _reviewFilter = 'recent';
  Set<String> _savedRecipes = {};
  final TextEditingController _reviewController = TextEditingController();
  int _selectedRating = 0;
  final bool _isSubmittingReview = false;

  List<Map<String, dynamic>> _recipes = [];
  List<Map<String, dynamic>> _reviews = [];
  Set<String> _favoriteRecipes = {};

  @override
  void initState() {
    super.initState();
    ChefSocketService.connect(widget.chefId);
    _tabController = TabController(length: 3, vsync: this);
    _initializeChefProfile();
    _loadSavedRecipes();
    _loadFavoriteRecipes();
  }

  Future<void> _loadFavoriteRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('favoriteRecipes') ?? [];
    if (mounted) {
      setState(() {
        _favoriteRecipes = saved.toSet();
      });
    }
  }

  Future<void> _saveFavoriteRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteRecipes', _favoriteRecipes.toList());
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _tabController.dispose();
    _reviewController.dispose();
    ChefSocketService.disconnect();
    super.dispose();
  }

  Future<void> _loadSavedRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('savedRecipes') ?? [];
    if (mounted) {
      setState(() {
        _savedRecipes = saved.toSet();
      });
    }
  }

  Future<void> _toggleSaveRecipe(String recipeId) async {
    if (!mounted) return;
    setState(() {
      if (_savedRecipes.contains(recipeId)) {
        _savedRecipes.remove(recipeId);
      } else {
        _savedRecipes.add(recipeId);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('savedRecipes', _savedRecipes.toList());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _savedRecipes.contains(recipeId)
              ? '📌 Recipe saved for later'
              : '📌 Removed from saved',
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _initializeChefProfile() async {
    try {
      if (!mounted) return;
      await _loadChefData();
      if (!mounted) return;
      await _loadRecipes();
      if (!mounted) return;
      await _loadReviews();
      if (!mounted) return;
    } catch (e) {
      debugPrint("Chef profile init error: $e");
      if (!mounted) return;
      setState(() {
        _loadingChef = false;
        _loadingRecipes = false;
        _loadingReviews = false;
        _errorMessage = "Failed loading chef";
      });
    }
  }

  Future<void> _loadChefData() async {
    if (widget.chefData != null) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'chefId',
        widget.chefData?['_id']?.toString() ?? '',
      );

      if (mounted) {
        setState(() {
          _chef = widget.chefData;
          _loadingChef = false;
        });
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/chefs/${widget.chefId}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('chefId', data['data']['_id']?.toString() ?? '');

        if (mounted) {
          setState(() {
            _chef = data['data'];
            _loadingChef = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load chef data';
            _loadingChef = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Connection error';
          _loadingChef = false;
        });
      }
    }
  }

  Future<void> _loadRecipes() async {
    if (!mounted) return;

    setState(() {
      _loadingRecipes = true;
    });

    try {
      final chefId = _chef?['_id']?.toString() ?? widget.chefId;

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/recipes/chef/$chefId'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> recipesData = data['data'] ?? [];

        final recipes = recipesData.map((item) {
          return {
            '_id': item['_id'],
            'id': item['_id'],
            'name': item['name'] ?? '',
            'description': item['description'] ?? '',
            'price': (item['price'] ?? 0).toDouble(),

            'rating': double.tryParse(item['rating'].toString()) ?? 0.0,

            'image': fullImageUrl(
              item['image'] ?? item['dishImage'] ?? item['photo'] ?? '',
            ),

            'category': item['category'] ?? 'Main',
            'totalTime': item['totalTime'] ?? 0,
            'calories': item['calories'] ?? 0,
            'fat': item['fat'] ?? 0,
            'protein': item['protein'] ?? 0,
            'carbs': item['carbs'] ?? item['potassium'] ?? 0,
            'ingredients': item['ingredients'] ?? [],
            'unknownIngredients': item['unknownIngredients'] ?? [],
            'chefName': item['chef']?['name'] ?? '',
            'chefImage': item['chef']?['profileImage'] ?? '',
            'chefId': item['chefId']?['_id'] ?? item['chefId'],
            'views': item['views'] ?? 0,
            'orders': item['orders'] ?? 0,
            'likes': item['likes'] ?? 0,
            'isTrending': item['isTrending'] ?? false,
          };
        }).toList();

        setState(() {
          _recipes = List<Map<String, dynamic>>.from(recipes);
          _loadingRecipes = false;
        });
      } else {
        setState(() {
          _recipes = [];
          _loadingRecipes = false;
        });
      }
    } catch (e) {
      debugPrint("Recipes load error: $e");

      if (!mounted) return;

      setState(() {
        _recipes = [];
        _loadingRecipes = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    if (!mounted) return;
    setState(() {
      _loadingReviews = true;
    });

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/reviews/chef/${widget.chefId}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final apiReviews = data['data'] ?? [];

        if (apiReviews.isNotEmpty) {
          double avgRating = _calculateAverageRating(apiReviews);
          if (mounted) {
            setState(() {
              _reviews = List<Map<String, dynamic>>.from(apiReviews);
              if (_chef != null) {
                _chef!['rating'] = avgRating;
                _chef!['reviews'] = apiReviews.length;
              }
              _loadingReviews = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _reviews = [];
              _loadingReviews = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _reviews = [];
            _loadingReviews = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reviews = [];
          _loadingReviews = false;
        });
      }
    }
  }

  double _calculateAverageRating(List<dynamic> reviews) {
    if (reviews.isEmpty) return 0;
    double sum = 0;
    for (var review in reviews) {
      final rating = review['rating'];
      if (rating is int) {
        sum += rating.toDouble();
      } else if (rating is double) {
        sum += rating;
      } else if (rating is num) {
        sum += rating.toDouble();
      }
    }
    return sum / reviews.length;
  }

  List<Map<String, dynamic>> get _filteredRecipes {
    List<Map<String, dynamic>> result = List.from(_recipes);
    switch (_sortRecipesBy) {
      case 'popular':
        result.sort((a, b) => (b['rating'] ?? 0).compareTo(a['rating'] ?? 0));
        break;
      case 'price_low':
        result.sort((a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0));
        break;
      case 'price_high':
        result.sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));
        break;
      case 'most_ordered':
        result.sort((a, b) => (b['orders'] ?? 0).compareTo(a['orders'] ?? 0));
        break;
    }
    return result;
  }

  List<Map<String, dynamic>> get _filteredReviews {
    List<Map<String, dynamic>> result = List.from(_reviews);
    switch (_reviewFilter) {
      case 'highest':
        result.sort((a, b) => (b['rating'] ?? 0).compareTo(a['rating'] ?? 0));
        break;
      case 'lowest':
        result.sort((a, b) => (a['rating'] ?? 0).compareTo(b['rating'] ?? 0));
        break;
      default:
        result.sort((a, b) {
          DateTime aDate =
              DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
              DateTime(2000);
          DateTime bDate =
              DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
              DateTime(2000);
          return bDate.compareTo(aDate);
        });
    }
    return result;
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0;
    double sum = 0;
    for (var review in _reviews) {
      final rating = review['rating'];
      if (rating is int) {
        sum += rating.toDouble();
      } else if (rating is double)
        sum += rating;
      else if (rating is num)
        sum += rating.toDouble();
    }
    return sum / _reviews.length;
  }

  void _showAddReviewDialog() {
    final TextEditingController commentController = TextEditingController();
    bool isSubmitting = false;
    int tempRating = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Write Your Review',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Rate this Chef',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 4,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setStateDialog(() {
                            tempRating = index + 1;
                            _selectedRating = tempRating;
                          });
                        },
                        child: Icon(
                          index < tempRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 28,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your Review',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Share your experience...',
                      hintStyle: TextStyle(color: _kTextDim.withOpacity(0.6)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (tempRating == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Select rating ⭐')),
                          );

                          return;
                        }

                        if (commentController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Write a review')),
                          );

                          return;
                        }

                        setStateDialog(() {
                          isSubmitting = true;
                        });

                        try {
                          final prefs = await SharedPreferences.getInstance();
                          final userName = prefs.getString('userName');

                          final token = prefs.getString('token');

                          print("TOKEN => $token");

                          final response = await http.post(
                            Uri.parse('${AppConfig.baseUrl}/reviews'),

                            headers: {
                              'Content-Type': 'application/json',

                              'Authorization': 'Bearer $token',
                            },
                            body: jsonEncode({
                              'chefId': widget.chefId,

                              'userName': userName,

                              'rating': tempRating,

                              'comment': commentController.text.trim(),
                            }),
                          );

                          print("STATUS => ${response.statusCode}");

                          print("BODY => ${response.body}");

                          if (response.statusCode == 201) {
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Review submitted successfully 🔥',
                                ),
                              ),
                            );

                            await _loadReviews();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('FAILED => ${response.body}'),
                              ),
                            );
                          }
                        } catch (e) {
                          print("ERROR => $e");

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('ERROR => $e')),
                          );
                        }

                        if (mounted) {
                          setStateDialog(() {
                            isSubmitting = false;
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: _kError),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Something went wrong',
            style: const TextStyle(color: _kTextDim),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _loadingChef = true;
                _errorMessage = null;
              });
              _initializeChefProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: _loadingChef
          ? const Center(child: CircularProgressIndicator(color: _kBlue))
          : _errorMessage != null
          ? _buildErrorView()
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildAppBar(),
                  _buildProfileHeader(),
                  _buildStatsRow(),
                  _buildBioSection(),
                  _buildTabBar(),
                  SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: IndexedStack(
                      index: _tabController.index,
                      children: [
                        _buildRecipesTab(),
                        _buildAboutTab(),
                        _buildReviewsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: onTap,
          child: Center(child: Icon(icon, size: 20, color: _kBlue)),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final coverImage = fullImageUrl(_chef?['coverImage']);
    return Container(
      height: coverImage.isNotEmpty ? 200 : 80,
      width: double.infinity,
      decoration: const BoxDecoration(color: _kSurface),
      child: Stack(
        children: [
          if (coverImage.isNotEmpty)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: coverImage,

                fit: BoxFit.cover,

                memCacheWidth: 300,
                memCacheHeight: 300,

                maxWidthDiskCache: 300,
                maxHeightDiskCache: 300,

                fadeInDuration: Duration.zero,

                fadeOutDuration: Duration.zero,

                errorWidget: (_, __, ___) {
                  return Container(color: Colors.grey.shade200);
                },
              ),
            ),
          Positioned(
            top: 40,
            left: 10,
            child: _circleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            top: 40,
            right: 60,
            child: _circleButton(
              icon: Icons.bookmark_border_outlined,
              onTap: () {
                Navigator.push(
                  context,

                  MaterialPageRoute(builder: (_) => const SavedRecipesScreen()),
                );
              },
            ),
          ),
          Positioned(
            top: 40,
            right: 10,
            child: ValueListenableBuilder<int>(
              valueListenable: CartService.cartCountNotifier,
              builder: (context, cartCount, _) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _circleButton(
                      icon: Icons.shopping_cart_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CartScreen()),
                        );
                      },
                    ),
                    if (cartCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            cartCount > 99 ? '99+' : '$cartCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _chef?['name'] ?? 'Chef Name';
    // ✅ استخدام safeString للتعامل مع List أو String
    final specialty = safeString(_chef?['specialty']);
    final rating = (_chef?['rating'] ?? 0).toDouble();
    final reviews = _chef?['reviews'] ?? _reviews.length;
    final profileImage = _chef?['profileImage'] ?? '';

    return Column(
      children: [
        Hero(
          tag: 'chef_${_chef?['_id']}',
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _kCard, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: profileImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: fullImageUrl(profileImage),
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          placeholder: (_, _) => _avatarFallback(name),
                          errorWidget: (_, _, _) => _avatarFallback(name),
                        )
                      : _avatarFallback(name),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _kText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          specialty,
          style: const TextStyle(fontSize: 12, color: _kTextDim),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _kAmber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(mainAxisSize: MainAxisSize.min),
        ),
      ],
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: _kBlue,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'C',
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final rating = (_chef?['rating'] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),

      padding: const EdgeInsets.symmetric(vertical: 14),

      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,

        children: [
          // 🔥 Recipes
          _buildStatItem(_recipes.length.toString(), 'Recipes', () {
            _tabController.animateTo(0);

            setState(() {});
          }),

          Container(height: 35, width: 1, color: Colors.grey.shade300),

          // 🔥 Rating
          _buildStatItem(rating.toStringAsFixed(1), 'Rating', () {
            _tabController.animateTo(2);

            setState(() {});
          }),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(16),

        splashColor: _kBlue.withOpacity(0.15),
        highlightColor: _kBlue.withOpacity(0.05),

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),

          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),

          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),

          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _kText,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _kTextDim,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBioSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Text(
        _chef?['bio'] ?? 'Passionate chef with over 10 years of experience.',
        style: const TextStyle(fontSize: 12, color: _kTextDim, height: 1.3),
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTabBar() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          onTap: (index) {
            setState(() {});
          },
          isScrollable: true,
          labelColor: _kBlue,
          unselectedLabelColor: _kTextDim,
          indicatorColor: _kBlue,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(text: 'Recipes'),
            Tab(text: 'About'),
            Tab(text: 'Reviews'),
          ],
        ),
        const Divider(height: 1, thickness: 1),
      ],
    );
  }

  Widget _buildSortButton() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kOutline.withOpacity(0.5)),
      ),
      child: DropdownButton<String>(
        value: _sortRecipesBy,
        underline: const SizedBox(),
        icon: const Icon(Icons.sort, size: 18),
        items: const [
          DropdownMenuItem(value: 'popular', child: Text('⭐ Top Rated')),
          DropdownMenuItem(
            value: 'price_low',
            child: Text('💰 Price: Low to High'),
          ),
          DropdownMenuItem(
            value: 'price_high',
            child: Text('💰 Price: High to Low'),
          ),
          DropdownMenuItem(
            value: 'most_ordered',
            child: Text('🔥 Most Ordered'),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _sortRecipesBy = value;
            });
          }
        },
      ),
    );
  }

  Widget _buildFavoriteChefs() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [].map((chef) {
        return SizedBox();
      }).toList(),
    );
  }

  Widget _buildRecipesTab() {
    if (_loadingRecipes) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recipes.isEmpty) {
      return const Center(child: Text('No recipes yet'));
    }
    return Column(
      children: [
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: .72,
            ),
            itemCount: _filteredRecipes.length,
            itemBuilder: (context, index) {
              final recipe = _filteredRecipes[index];
              final recipeId = (recipe['_id'] ?? recipe['id']).toString();
              final isFav = FavoriteService.isFavoriteRecipe(recipeId);
              return PerfectRecipeCard(
                recipe: recipe,
                isFavorite: isFav,
                isSaved: SavedService.isSavedRecipe(recipeId),
                onFavorite: () async {
                  await FavoriteService.toggleRecipe(recipe);
                  if (mounted) {
                    setState(() {
                      if (FavoriteService.isFavoriteRecipe(recipeId)) {
                        _favoriteRecipes.add(recipeId);
                      } else {
                        _favoriteRecipes.remove(recipeId);
                      }
                    });
                  }
                  HapticFeedback.lightImpact();
                },
                onSave: () async {
                  await SavedService.toggleSavedRecipe(recipe);

                  setState(() {
                    if (SavedService.isSavedRecipe(recipeId)) {
                      _savedRecipes.add(recipeId);
                    } else {
                      _savedRecipes.remove(recipeId);
                    }
                  });

                  HapticFeedback.lightImpact();
                },
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(
                        recipe: {
                          ...recipe,
                          'isFavorite': FavoriteService.isFavoriteRecipe(
                            recipeId,
                          ),
                        },
                      ),
                    ),
                  );
                  if (mounted) {
                    await _loadRecipes();

                    setState(() {});
                  }
                  {
                    final id = result['recipeId'].toString();
                    setState(() {
                      if (FavoriteService.isFavoriteRecipe(id)) {
                        _favoriteRecipes.add(id);
                      } else {
                        _favoriteRecipes.remove(id);
                      }
                    });
                  }
                },
                onAddToCart: () async {
                  await CartService.addItem({
                    ...recipe,

                    'chefId': recipe['chefId'] ?? _chef?['_id'],

                    'chefName': _chef?['name'] ?? 'Chef',
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAboutTab() {
    if (_chef == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final about = _chef!['bio'] ?? 'No bio available';
    final location = _chef!['location'] ?? 'Not specified';
    final experience = _chef!['experience'] ?? 'Not specified';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: _kBlue),
                    SizedBox(width: 6),
                    Text(
                      'About Chef',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _kText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  about,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kTextDim,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 18, color: _kBlue),
                    SizedBox(width: 6),
                    Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _kText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  location,
                  style: const TextStyle(fontSize: 13, color: _kTextDim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.work_rounded, size: 18, color: _kBlue),
                    SizedBox(width: 6),
                    Text(
                      'Experience',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _kText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  experience,
                  style: const TextStyle(fontSize: 13, color: _kTextDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_loadingReviews) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: _kBlue),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kBlue, _kBlue.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return Icon(
                            index < _averageRating.round()
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color: Colors.white,
                          );
                        }),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_reviews.length} ${_reviews.length == 1 ? 'review' : 'reviews'}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 30, width: 1, color: Colors.white24),
                Expanded(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.rate_review,
                        size: 24,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Share your experience',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: _showAddReviewDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _kBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 28),
                        ),
                        child: const Text(
                          'Write',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'All Reviews',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _kText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kOutline.withOpacity(0.5)),
                ),
                child: DropdownButton<String>(
                  value: _reviewFilter,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.filter_list, size: 14),
                  items: const [
                    DropdownMenuItem(
                      value: 'recent',
                      child: Text('📅 Recent', style: TextStyle(fontSize: 11)),
                    ),
                    DropdownMenuItem(
                      value: 'highest',
                      child: Text('⭐ Highest', style: TextStyle(fontSize: 11)),
                    ),
                    DropdownMenuItem(
                      value: 'lowest',
                      child: Text('⭐ Lowest', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _reviewFilter = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_reviews.isEmpty)
            _buildEmptyReviews()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredReviews.length,
              itemBuilder: (context, index) =>
                  _buildReviewCard(_filteredReviews[index]),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyReviews() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 48,
            color: _kTextDim.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text('No reviews yet', style: TextStyle(color: _kTextDim)),
          const SizedBox(height: 8),
          Text(
            'Be the first to review this chef!',
            style: TextStyle(fontSize: 12, color: _kTextDim.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] ?? 0).toInt();
    final userName = review['userName'] ?? review['user']?['name'] ?? 'User';
    final comment = review['comment'] ?? review['review'] ?? '';
    final createdAt = review['createdAt'] ?? review['date'];

    String date = '';
    if (createdAt != null) {
      try {
        final dateTime = DateTime.parse(createdAt.toString());
        date = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _kBluePale,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: _kBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: TextStyle(fontSize: 11, color: _kTextDim),
                      ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: _kAmber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment,
            style: const TextStyle(fontSize: 13, height: 1.4, color: _kTextDim),
          ),
        ],
      ),
    );
  }
}

// ✅ PerfectRecipeCard المعدل
class PerfectRecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final bool isFavorite;
  final bool isSaved;
  final VoidCallback onFavorite;
  final VoidCallback onSave;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const PerfectRecipeCard({
    super.key,
    required this.recipe,
    required this.isFavorite,
    required this.isSaved,
    required this.onFavorite,
    required this.onSave,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final name = recipe['name'] ?? '';
    final price = (recipe['price'] ?? 0).toDouble();
    final rating = double.tryParse(recipe['rating'].toString()) ?? 0.0;
    final image = fullImageUrl(recipe['image']);
    print('RECIPE IMAGE => $image');
    final isTrending = recipe['isTrending'] ?? false;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: image.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: image,

                            fit: BoxFit.cover,

                            width: double.infinity,
                            memCacheWidth: 250,
                            memCacheHeight: 250,

                            maxWidthDiskCache: 250,
                            maxHeightDiskCache: 250,

                            filterQuality: FilterQuality.low,

                            fadeInDuration: Duration.zero,

                            fadeOutDuration: Duration.zero,

                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],

                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),

                            errorWidget: (context, url, error) {
                              print('IMAGE ERROR => $url');

                              return Container(
                                color: Colors.grey.shade100,

                                child: Center(
                                  child: Icon(
                                    Icons.restaurant_menu,
                                    size: 42,
                                    color: _kBlue,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Text(
                                '🍽️',
                                style: TextStyle(fontSize: 40),
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: onSave,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_border_outlined,
                          size: 14,
                          color: isSaved ? AppColors.navy : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: isFavorite ? Colors.red : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  if (isTrending)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '🔥 Trending',
                          style: TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),

                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.navy,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                'View Recipe',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onAddToCart,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.shopping_cart_outlined,
                            size: 14,
                            color: Colors.white,
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
}
