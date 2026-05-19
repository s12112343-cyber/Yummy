// 📁 lib/models/recipe_model.dart
import 'package:flutter/material.dart';

class RecipeModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final double rating;
  final String image;
  final String chefName;
  final String chefId;
  final String? badge;
  final Color? badgeColor;

  RecipeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.rating,
    required this.image,
    required this.chefName,
    required this.chefId,
    this.badge,
    this.badgeColor,
  });

  factory RecipeModel.fromJson(Map<String, dynamic> json) {
    return RecipeModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      rating: (json['rating'] ?? 0).toDouble(),
      image: json['image'] ?? json['imageUrl'] ?? '',
      chefName: json['chefName'] ?? json['chef']['name'] ?? 'Chef',
      chefId: json['chefId'] ?? json['chef']['_id'] ?? '',
      badge: json['badge'],
      badgeColor: json['badgeColor'] != null
          ? Color(int.parse(json['badgeColor']))
          : null,
    );
  }

  int get starRating => rating.round();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'rating': rating,
      'image': image,
      'chefName': chefName,
      'chefId': chefId,
      'badge': badge,
    };
  }
}
