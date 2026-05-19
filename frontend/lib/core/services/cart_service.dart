import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartService {
  static final ValueNotifier<List<Map<String, dynamic>>> cartItems =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  static ValueNotifier<int> cartCountNotifier = ValueNotifier(0);
  static const String _cartKey = 'cart_items';
  static Future<void> increaseQty(int index) async {
    final updated = List<Map<String, dynamic>>.from(cartItems.value);

    updated[index]['quantity'] = (updated[index]['quantity'] ?? 1) + 1;

    cartItems.value = updated;

    _updateCartCount();

    await _save();
  }

  static Future<void> decreaseQty(int index) async {
    final updated = List<Map<String, dynamic>>.from(cartItems.value);

    if ((updated[index]['quantity'] ?? 1) > 1) {
      updated[index]['quantity']--;
    } else {
      updated.removeAt(index);
    }

    cartItems.value = updated;

    cartCountNotifier.value = updated.fold(
      0,
      (sum, item) => sum + ((item['quantity'] ?? 1) as int),
    );

    await _save();
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_cartKey);

    if (saved != null && saved.isNotEmpty) {
      final List decoded = jsonDecode(saved);

      cartItems.value = decoded
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      cartItems.value = [];
    }
    cartCountNotifier.value = cartItems.value.fold(
      0,
      (sum, item) => sum + ((item['quantity'] ?? 1) as int),
    );
    _updateCartCount();
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartKey, jsonEncode(cartItems.value));
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

    final index = updated.indexWhere(
      (item) => item['id'].toString() == recipe['id'].toString(),
    );

    if (index != -1) {
      updated[index]['quantity'] = (updated[index]['quantity'] ?? 1) + 1;
    } else {
      updated.add({...recipe, 'quantity': 1});
    }

    cartItems.value = updated;

    /// بدل ++
    cartCountNotifier.value = updated.fold(
      0,
      (sum, item) => sum + ((item['quantity'] ?? 1) as int),
    );

    await _save();
  }

  static Future<void> removeAt(int index) async {
    final updated = List<Map<String, dynamic>>.from(cartItems.value);

    if (index >= 0 && index < updated.length) {
      updated.removeAt(index);

      cartItems.value = updated;

      /// بدل --
      cartCountNotifier.value = updated.fold(
        0,
        (sum, item) => sum + ((item['quantity'] ?? 1) as int),
      );

      await _save();
    }
  }

  static Future<void> removeById(String id) async {
    final updated = List<Map<String, dynamic>>.from(cartItems.value);

    updated.removeWhere((item) => item['id'].toString() == id);

    cartItems.value = updated;

    _updateCartCount();

    await _save();
  }

  static Future<void> clear() async {
    cartItems.value = [];
    cartCountNotifier.value = 0;
    await _save();
  }

  static Future<void> saveCart(List<Map<String, dynamic>> items) async {
    cartItems.value = items;

    _updateCartCount();

    await _save();
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
