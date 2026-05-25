import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class CartService {
  static final ValueNotifier<List<Map<String, dynamic>>> cartItems =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  static ValueNotifier<int> cartCountNotifier = ValueNotifier(0);
  static const String _legacyCartKey = 'cart_items';

  static String _baseUrl = AppConfig.baseUrl;

  static Future<Map<String, String>?> _buildAuthHeaders() async {
    final token = await AuthService().getToken();

    if (token == null || token.trim().isEmpty) {
      return null;
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static List<Map<String, dynamic>> _toItemList(dynamic items) {
    if (items is! List) return [];

    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static int _totalQuantity(List<Map<String, dynamic>> items) {
    return items.fold(0, (sum, item) => sum + ((item['quantity'] ?? 1) as int));
  }

  static Future<bool> _syncToServer(List<Map<String, dynamic>> items) async {
    final headers = await _buildAuthHeaders();
    if (headers == null) return false;

    try {
      final response = await http
          .put(
            Uri.parse('$_baseUrl/cart'),
            headers: headers,
            body: jsonEncode({'items': items}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        cartItems.value = _toItemList(data['items'] ?? items);
        cartCountNotifier.value = _totalQuantity(cartItems.value);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Cart sync failed: $e');
      return false;
    }
  }

  static void reset() {
    cartItems.value = [];
    cartCountNotifier.value = 0;
  }

  static Future<void> increaseQty(int index) async {
    final updated = List<Map<String, dynamic>>.from(cartItems.value);

    updated[index]['quantity'] = (updated[index]['quantity'] ?? 1) + 1;

    final previous = List<Map<String, dynamic>>.from(cartItems.value);
    cartItems.value = updated;
    _updateCartCount();

    final synced = await _syncToServer(updated);
    if (!synced) {
      cartItems.value = previous;
      _updateCartCount();
    }
  }

  static Future<void> decreaseQty(int index) async {
    final updated = List<Map<String, dynamic>>.from(cartItems.value);

    if ((updated[index]['quantity'] ?? 1) > 1) {
      updated[index]['quantity']--;
    } else {
      updated.removeAt(index);
    }

    final previous = List<Map<String, dynamic>>.from(cartItems.value);
    cartItems.value = updated;
    _updateCartCount();

    final synced = await _syncToServer(updated);
    if (!synced) {
      cartItems.value = previous;
      _updateCartCount();
    }
  }

  static Future<void> init() async {
    final headers = await _buildAuthHeaders();

    if (headers == null) {
      reset();
      return;
    }

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/cart'), headers: headers)
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        cartItems.value = _toItemList(data['items']);
        if (cartItems.value.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final legacySaved = prefs.getString(_legacyCartKey);

          if (legacySaved != null && legacySaved.isNotEmpty) {
            final List decoded = jsonDecode(legacySaved);
            final legacyItems = decoded
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

            final migrated = await _syncToServer(legacyItems);
            if (migrated) {
              cartItems.value = legacyItems;
              await prefs.remove(_legacyCartKey);
            }
          }
        }
      } else {
        cartItems.value = [];
      }
    } catch (e) {
      debugPrint('❌ Cart init failed: $e');
      cartItems.value = [];
    }

    cartCountNotifier.value = _totalQuantity(cartItems.value);
    _updateCartCount();
  }

  static void _updateCartCount() {
    int totalQty = 0;

    for (final item in cartItems.value) {
      totalQty += ((item['quantity'] ?? 1) as int);
    }

    cartCountNotifier.value = totalQty;
  }

  static Future<void> addItem(Map<String, dynamic> recipe) async {
    final updated = List<Map<String, dynamic>>.from(cartItems.value);
    final previous = List<Map<String, dynamic>>.from(cartItems.value);

    final normalized = Map<String, dynamic>.from(recipe);
    normalized['carbs'] =
        normalized['carbs'] ??
        normalized['carbohydrates'] ??
        normalized['potassium'] ??
        0;

    final incomingQty = (recipe['quantity'] is int)
        ? recipe['quantity'] as int
        : int.tryParse(recipe['quantity']?.toString() ?? '') ?? 1;

    final incomingSize = (recipe['size'] ?? '').toString();

    final index = updated.indexWhere((item) {
      final itemId = item['id']?.toString() ?? item['_id']?.toString() ?? '';
      final rId = recipe['id']?.toString() ?? recipe['_id']?.toString() ?? '';
      final itemSize = (item['size'] ?? '').toString();
      return itemId == rId && itemSize == incomingSize;
    });

    if (index != -1) {
      updated[index]['quantity'] =
          (updated[index]['quantity'] ?? 1) + incomingQty;
    } else {
      final toAdd = normalized;
      toAdd['quantity'] = incomingQty;
      updated.add(toAdd);
    }

    cartItems.value = updated;
    _updateCartCount();

    final synced = await _syncToServer(updated);
    if (!synced) {
      cartItems.value = previous;
      _updateCartCount();
    }
  }

  static Future<void> removeAt(int index) async {
    final updated = List<Map<String, dynamic>>.from(cartItems.value);
    final previous = List<Map<String, dynamic>>.from(cartItems.value);

    if (index >= 0 && index < updated.length) {
      updated.removeAt(index);

      cartItems.value = updated;

      _updateCartCount();

      final synced = await _syncToServer(updated);
      if (!synced) {
        cartItems.value = previous;
        _updateCartCount();
      }
    }
  }

  static Future<void> removeById(String id) async {
    final updated = List<Map<String, dynamic>>.from(cartItems.value);
    final previous = List<Map<String, dynamic>>.from(cartItems.value);

    updated.removeWhere((item) => item['id'].toString() == id);

    cartItems.value = updated;

    _updateCartCount();

    final synced = await _syncToServer(updated);
    if (!synced) {
      cartItems.value = previous;
      _updateCartCount();
    }
  }

  static Future<void> clear() async {
    final previous = List<Map<String, dynamic>>.from(cartItems.value);
    cartItems.value = [];
    _updateCartCount();

    final headers = await _buildAuthHeaders();
    if (headers == null) {
      reset();
      return;
    }

    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/cart'), headers: headers)
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        reset();
        return;
      }
    } catch (e) {
      debugPrint('❌ Cart clear failed: $e');
    }

    cartItems.value = previous;
    _updateCartCount();
  }

  static Future<void> saveCart(List<Map<String, dynamic>> items) async {
    final previous = List<Map<String, dynamic>>.from(cartItems.value);
    cartItems.value = items;
    _updateCartCount();

    final synced = await _syncToServer(items);
    if (!synced) {
      cartItems.value = previous;
      _updateCartCount();
    }
  }

  static int get count => cartItems.value.length;

  static double get totalPrice {
    double total = 0;

    for (final item in cartItems.value) {
      final price = (item['price'] ?? 0).toDouble();
      final qty = (item['quantity'] ?? 1);

      total += price * qty;
    }

    return total;
  }
}
