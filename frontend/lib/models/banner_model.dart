// 📁 lib/models/banner_model.dart
class BannerModel {
  final String id;
  final String image;
  final String? title;
  final String? description;
  final int order;
  final bool isActive;
  final DateTime? expiryDate;

  BannerModel({
    required this.id,
    required this.image,
    this.title,
    this.description,
    required this.order,
    required this.isActive,
    this.expiryDate,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['_id'] ?? json['id'] ?? '',
      image: json['image'] ?? '',
      title: json['title'],
      description: json['description'],
      order: json['order'] ?? 0,
      isActive: json['isActive'] ?? true,
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image': image,
      'title': title,
      'description': description,
      'order': order,
      'isActive': isActive,
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }
}
