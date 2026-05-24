import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';

class AdminApplicationIconPage extends StatelessWidget {
  const AdminApplicationIconPage({super.key});

  Future<void> _updateLogo(BuildContext context, String logoName) async {
    try {
      final response = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/app-settings/icon'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'appIcon': logoName}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$logoName logo updated')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to update logo')));
      }
    } catch (e) {
      print(e);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Server error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildLogoCard(
              context,
              image: 'assets/images/logo_white.png',
              title: 'Classic Branding',
              logoName: 'classic',
            ),
            const SizedBox(height: 20),
            _buildLogoCard(
              context,
              image: 'assets/images/yummy logo.png',
              title: 'Dark Branding',
              logoName: 'dark',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoCard(
    BuildContext context, {
    required String image,
    required String title,
    required String logoName,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 90,
            height: 90,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FB),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Image.asset(image, fit: BoxFit.contain),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D1F4C),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Change app branding instantly',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _updateLogo(context, logoName),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF05346A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
