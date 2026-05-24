import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List notifications = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();

    loadNotifications();
  }

  Future<void> loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/notifications/my-notifications'),

        headers: {'Authorization': 'Bearer $token'},
      );

      print('NOTIFICATIONS STATUS => ${res.statusCode}');

      print('NOTIFICATIONS BODY => ${res.body}');

      final data = jsonDecode(res.body);

      setState(() {
        notifications = data['notifications'] ?? [];

        loading = false;
      });
    } catch (e) {
      print(e);

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      await http.patch(
        Uri.parse('${AppConfig.baseUrl}/notifications/read/$id'),

        headers: {'Authorization': 'Bearer $token'},
      );

      setState(() {
        notifications.removeWhere((n) => n['_id'] == id);
      });
    } catch (e) {
      print(e);
    }
  }

  IconData getIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag_rounded;

      case 'review':
        return Icons.star_rounded;

      case 'recipe_review':
        return Icons.restaurant_menu_rounded;

      case 'order_status':
        return Icons.delivery_dining_rounded;

      case 'global':
        return Icons.notifications_active;

      default:
        return Icons.notifications;
    }
  }

  Color getColor(String type) {
    switch (type) {
      case 'order':
        return Colors.orange;

      case 'review':
        return Colors.amber;

      case 'recipe_review':
        return Colors.green;

      case 'order_status':
        return Colors.blue;

      case 'global':
        return Colors.purple;

      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),

      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1628),

        title: const Text(
          'Notifications',

          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),

        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
          ? const Center(
              child: Text(
                'No notifications yet 🔔',

                style: TextStyle(fontSize: 16),
              ),
            )
          : RefreshIndicator(
              onRefresh: loadNotifications,

              child: ListView.builder(
                padding: const EdgeInsets.all(16),

                itemCount: notifications.length,

                itemBuilder: (context, index) {
                  final n = notifications[index];

                  final type = n['type'] ?? '';

                  return GestureDetector(
                    onTap: () async {
                      await markAsRead(n['_id']);
                    },

                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),

                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: Colors.white,

                        borderRadius: BorderRadius.circular(20),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.05),

                            blurRadius: 10,

                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),

                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Container(
                            width: 50,

                            height: 50,

                            decoration: BoxDecoration(
                              color: getColor(type).withOpacity(.12),

                              shape: BoxShape.circle,
                            ),

                            child: Icon(getIcon(type), color: getColor(type)),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  n['title'] ?? '',

                                  style: const TextStyle(
                                    fontSize: 16,

                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  n['body'] ?? '',

                                  style: const TextStyle(
                                    fontSize: 14,

                                    color: Colors.grey,
                                  ),
                                ),

                                const SizedBox(height: 10),

                                Text(
                                  n['actorName'] ?? '',

                                  style: const TextStyle(
                                    fontSize: 12,

                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
