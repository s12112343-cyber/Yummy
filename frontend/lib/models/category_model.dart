// lib/models/category_model.dart
import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final IconData icon;
  final String imageUrl;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    this.imageUrl = '',
  });

  // للاستخدام المحلي (بدون API)
  static const List<CategoryModel> localCategories = [
    CategoryModel(id: 'all', name: 'All', icon: Icons.grid_view_rounded),
    CategoryModel(id: 'soups', name: 'Soups', icon: Icons.kitchen_rounded),
    CategoryModel(
      id: 'bakery',
      name: 'Bakery',
      icon: Icons.bakery_dining_rounded,
    ),
    CategoryModel(
      id: 'main',
      name: 'Main',
      icon: Icons.restaurant_menu_rounded,
    ),
    CategoryModel(id: 'sweet', name: 'Sweet', icon: Icons.cake_rounded),
    CategoryModel(
      id: 'salads',
      name: 'Salads',
      icon: Icons.emoji_food_beverage_rounded,
    ),
    CategoryModel(id: 'pasta', name: 'Pasta', icon: Icons.ramen_dining_rounded),
  ];

  // من JSON (لما تجي من API)
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: _getIconFromString(json['icon'] ?? 'restaurant'),
      imageUrl: json['imageUrl'] ?? '',
    );
  }

  static IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'grid_view':
        return Icons.grid_view_rounded;
      case 'kitchen':
        return Icons.kitchen_rounded;
      case 'bakery':
        return Icons.bakery_dining_rounded;
      case 'restaurant':
        return Icons.restaurant_menu_rounded;
      case 'cake':
        return Icons.cake_rounded;
      case 'salad':
        return Icons.emoji_food_beverage_rounded;
      case 'pasta':
        return Icons.ramen_dining_rounded;
      default:
        return Icons.restaurant;
    }
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'imageUrl': imageUrl};
  }
}
