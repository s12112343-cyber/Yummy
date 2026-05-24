import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

const _kPrimaryDark = Color(0xFF0A1628);

const _kBackground = Color(0xFFF8FAFC);

const _kCard = Color(0xFFFFFFFF);

const _kBorder = Color(0xFFE2E8F0);

class AdminNotificationRequestsPage extends StatefulWidget {
  const AdminNotificationRequestsPage({super.key});

  @override
  State<AdminNotificationRequestsPage> createState() =>
      _AdminNotificationRequestsPageState();
}

class _AdminNotificationRequestsPageState
    extends State<AdminNotificationRequestsPage> {
  List requests = [];

  bool loading = true;

  @override
  void initState() {
    super.initState();

    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/notification-requests/admin'),

        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          requests = (data['requests'] ?? [])
              .where((r) => r['status'] == 'pending')
              .toList();
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      print(e);

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _approveRequest(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      final res = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/notification-requests/approve/$id'),

        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification approved 🔥')),
        );

        _loadRequests();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _rejectRequest(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      final res = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/notification-requests/reject/$id'),

        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request rejected ❌')));

        _loadRequests();
      } else {
        print(res.body);
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,

      appBar: AppBar(
        backgroundColor: _kPrimaryDark,

        iconTheme: const IconThemeData(color: Colors.white),

        title: const Text(
          'Notification Requests',

          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
          ? const Center(child: Text('No requests'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),

              itemCount: requests.length,

              itemBuilder: (context, index) {
                final req = requests[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: _kCard,

                    borderRadius: BorderRadius.circular(20),

                    border: Border.all(color: _kBorder),
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        req['title'] ?? '',

                        style: const TextStyle(
                          fontSize: 18,

                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(req['message'] ?? ''),

                      const SizedBox(height: 16),

                      Text('Chef: ${req['chefName'] ?? 'Unknown'}'),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _approveRequest(req['_id']);
                              },

                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),

                              icon: const Icon(
                                Icons.check,
                                color: Colors.white,
                              ),

                              label: const Text(
                                'Approve',

                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _rejectRequest(req['_id']);
                              },

                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),

                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),

                              label: const Text(
                                'Reject',

                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
