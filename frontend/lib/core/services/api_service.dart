import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../models/cook_model.dart';
import '../../models/recipe_model.dart';
import '../../models/banner_model.dart';

class ApiService {
  // جلب جميع الشيفات
  Future<List<CookModel>> getChefs() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/chefs');
      print('📡 GET: $url');

      final response = await http.get(url);
      print('📡 Status: ${response.statusCode}');
      print('📡 Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> chefs = data['data'] ?? [];
        print('✅ Found ${chefs.length} chefs');
        return chefs.map((json) => CookModel.fromJson(json)).toList();
      } else {
        print('❌ Status code error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Exception: $e');
      return [];
    }
  }

  // جلب أفضل الشيفات (مرتبة حسب التقييم)
  Future<List<CookModel>> getTopChefs({int limit = 5}) async {
    final chefs = await getChefs();
    chefs.sort((a, b) => b.rating.compareTo(a.rating));
    return chefs.take(limit).toList();
  }

  // جلب الوصفات الموصى بها
  Future<List<RecipeModel>> getRecommendedRecipes() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/meals/featured'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> recipes = data['meals'] ?? data['data'] ?? [];
        return recipes.map((json) => RecipeModel.fromJson(json)).toList();
      } else {
        return _getMockRecipes();
      }
    } catch (e) {
      return _getMockRecipes();
    }
  }

  // جلب البانرات النشطة
  Future<List<BannerModel>> getActiveBanners() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/banners'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> banners = data['banners'] ?? [];
        final now = DateTime.now();
        return banners
            .map((json) => BannerModel.fromJson(json))
            .where(
              (b) =>
                  b.isActive &&
                  (b.expiryDate == null || b.expiryDate!.isAfter(now)),
            )
            .toList();
      } else {
        return _getMockBanners();
      }
    } catch (e) {
      return _getMockBanners();
    }
  }

  // بيانات تجريبية للوصفات (في حالة فشل API)
  List<RecipeModel> _getMockRecipes() {
    return [
      RecipeModel(
        id: '1',
        name: 'Artisan Burrata Pizza',
        description:
            'Slow-fermented sourdough, organic San Marzano tomatoes, and fresh creamy burrata heart.',
        price: 18.50,
        rating: 4.9,
        image:
            'https://images.unsplash.com/photo-1604382354936-07c5d9983bd3?w=500',
        chefName: 'Chef Julian Rossi',
        chefId: '1',
        badge: 'Best Seller',
        badgeColor: const Color(0xFF005EB2),
      ),
      RecipeModel(
        id: '2',
        name: 'Miso-Glazed King Salmon',
        description:
            'Wild-caught salmon, maple-miso glaze, with a side of sesame-charred broccolini and quinoa.',
        price: 24.00,
        rating: 4.7,
        image:
            'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=500',
        chefName: 'Sarah Ohara',
        chefId: '2',
        badge: 'Healthy',
        badgeColor: const Color(0xFF2891B2),
      ),
      RecipeModel(
        id: '3',
        name: 'Rainbow Quinoa Harvest Bowl',
        description:
            'Roasted butternut squash, pomegranate jewels, whipped tahini, and sprouted microgreens.',
        price: 16.00,
        rating: 5.0,
        image:
            'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=500',
        chefName: 'Marcus Thorne',
        chefId: '3',
        badge: "Chef's Choice",
        badgeColor: const Color(0xFF005EB2),
      ),
    ];
  }

  // بيانات تجريبية للبانرات (في حالة فشل API)
  List<BannerModel> _getMockBanners() {
    return [
      BannerModel(
        id: '1',
        image:
            'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
        description: 'Exclusive Offer',
        order: 1,
        isActive: true,
      ),
    ];
  }
}
