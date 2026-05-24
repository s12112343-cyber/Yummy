import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';

class BannerRequestsPage extends StatefulWidget {
  const BannerRequestsPage({super.key});

  @override
  State<BannerRequestsPage> createState() => _BannerRequestsPageState();
}

class _BannerRequestsPageState extends State<BannerRequestsPage> {
  bool _loading = true;

  List<dynamic> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final token = await AuthService().getToken();

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/banner-requests/admin'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = jsonDecode(res.body);

      if (mounted) {
        setState(() {
          _requests = data['requests'] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _approveRequest(String id) async {
    try {
      final token = await AuthService().getToken();

      final res = await http.put(
        Uri.parse('${AppConfig.baseUrl}/banner-requests/approve/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        _showSnack('Banner approved successfully');

        setState(() {
          _requests.removeWhere((r) => r['_id'] == id);
        });
      } else {
        _showSnack('Failed to approve banner', isError: true);
      }
    } catch (e) {
      _showSnack('Error approving banner', isError: true);
    }
  }

  Future<void> _rejectRequest(String id) async {
    try {
      final token = await AuthService().getToken();

      final res = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/banner-requests/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        _showSnack('Banner rejected');

        await _loadRequests();
      } else {
        _showSnack('Failed to reject banner', isError: true);
      }
    } catch (e) {
      _showSnack('Error rejecting banner', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? AppColors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return 'No expiry';

    try {
      final d = DateTime.parse(date);

      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.deepBlue),
        title: const Text(
          'Banner Requests',
          style: TextStyle(
            color: AppColors.deepBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (_, i) {
                final request = _requests[i];

                return _buildRequestCard(request);
              },
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.babyBlueLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.campaign_outlined,
              size: 60,
              color: AppColors.royalBlue,
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'No Banner Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.deepBlue,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Chef requests will appear here',
            style: TextStyle(color: AppColors.blueGray),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(dynamic request) {
    final chef = request['chef'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// IMAGE
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: Image.network(
              request['image'] ?? '',
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,

              errorBuilder: (_, __, ___) => Container(
                height: 200,
                color: AppColors.babyBlueLight,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 45,
                    color: AppColors.blueGray,
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// CHEF NAME
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.babyBlueLight,
                      child: Icon(Icons.person, color: AppColors.royalBlue),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        chef?['businessName'] ?? chef?['name'] ?? 'Chef',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepBlue,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                /// LINK
                if (request['link'] != null &&
                    request['link'].toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.babyBlueLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.link,
                          color: AppColors.royalBlue,
                          size: 18,
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            request['link'],
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.royalBlue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (request['link'] != null &&
                    request['link'].toString().isNotEmpty)
                  const SizedBox(height: 12),

                /// EXPIRY
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.babyBlueLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: AppColors.royalBlue,
                        size: 18,
                      ),

                      const SizedBox(width: 8),

                      Text(
                        _formatDate(request['expiryDate']),
                        style: const TextStyle(
                          color: AppColors.royalBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                /// BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveRequest(request['_id']),

                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                        ),

                        label: const Text('Approve'),

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _rejectRequest(request['_id']),

                        icon: const Icon(Icons.close, color: Colors.white),

                        label: const Text('Reject'),

                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
