import '../config/app_config.dart';

String fullImageUrl(dynamic image) {
  if (image == null) return '';

  final img = image.toString().trim();

  if (img.isEmpty) return '';

  // ✅ already full url
  if (img.startsWith('http://') || img.startsWith('https://')) {
    return img;
  }

  // ✅ uploads path
  final base = AppConfig.baseUrl.replaceAll('/api', '');

  // ✅ if missing /
  if (!img.startsWith('/')) {
    return '$base/$img';
  }

  return '$base$img';
}
