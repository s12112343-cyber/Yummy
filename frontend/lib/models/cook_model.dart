// 📁 lib/models/cook_model.dart
class CookModel {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? profileImage;
  final double rating;
  final int dishes;
  final String followers;
  final String specialty;
  final String? bio;

  CookModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.profileImage,
    required this.rating,
    required this.dishes,
    required this.followers,
    required this.specialty,
    this.bio,
  });

  factory CookModel.fromJson(Map<String, dynamic> json) {
    return CookModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? 'Unknown Chef',
      email: json['email'] ?? '',
      profileImage: json['profileImage'],
      rating: (json['rating'] ?? 0).toDouble(),
      dishes: json['dishes'] ?? 0,
      followers: json['followers']?.toString() ?? '0',
      specialty: json['specialty'] ?? 'Chef',
      bio: json['bio'],
    );
  }

  int get starRating => rating.round();

  String get formattedFollowers {
    final int followersCount = int.tryParse(followers) ?? 0;
    if (followersCount >= 1000) {
      return '${(followersCount / 1000).toStringAsFixed(1)}K';
    }
    return followers;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'email': email,
      'profileImage': profileImage,
      'rating': rating,
      'dishes': dishes,
      'followers': followers,
      'specialty': specialty,
      'bio': bio,
    };
  }
}
