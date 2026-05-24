import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AppBrandingService {
  static String currentLogo = 'assets/images/yummy logo.png';

  static Future<void> loadBranding() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/app-settings'),
      );

      final data = jsonDecode(response.body);

      final logo = data['settings']['appIcon'];

      if (logo == 'dark') {
        currentLogo = 'assets/images/logo-notification.png';
      } else {
        currentLogo = 'assets/images/logo_white.png';
      }
    } catch (e) {
      print(e);
    }
  }
}
