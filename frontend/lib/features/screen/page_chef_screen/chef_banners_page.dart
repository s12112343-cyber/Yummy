import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

const _kPrimaryDark = Color(0xFF0A1628);
const _kPrimaryLight = Color(0xFF3B82F6);
const _kAccent = Color(0xFF10B981);
const _kBackground = Color(0xFFF8FAFC);
const _kCard = Color(0xFFFFFFFF);
const _kText = Color(0xFF0F172A);
const _kTextSecondary = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);
const _kError = Color(0xFFEF4444);

class ChefBannersPage extends StatefulWidget {
  const ChefBannersPage({super.key});

  @override
  State<ChefBannersPage> createState() => _ChefBannersPageState();
}

class _ChefBannersPageState extends State<ChefBannersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List banners = [];
  List requests = [];

  bool loadingBanners = true;
  bool loadingRequests = true;

  Map<String, dynamic>? chef;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _loadChefData();
  }

  Future<void> _loadChefData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final chefId = prefs.getString('chefId');

      final token = prefs.getString('token');

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/chefs/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        chef = data['data'];

        await _loadChefBanners(chefId!);

        await _loadRequests();
      }
    } catch (e) {
      print(e);
    }
  }

  /// =========================================================
  /// LOAD BANNERS
  /// =========================================================

  Future<void> _loadChefBanners(String chefId) async {
    try {
      setState(() {
        loadingBanners = true;
      });

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/banner-requests/chef/$chefId'),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          banners = data['banners'] ?? [];
          loadingBanners = false;
        });
      } else {
        setState(() {
          loadingBanners = false;
        });
      }
    } catch (e) {
      setState(() {
        loadingBanners = false;
      });

      print(e);
    }
  }

  /// =========================================================
  /// LOAD REQUESTS
  /// =========================================================

  Future<void> _loadRequests() async {
    try {
      setState(() {
        loadingRequests = true;
      });

      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/banner-requests/my-requests'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        setState(() {
          requests = data['requests'] ?? [];
          loadingRequests = false;
        });
      } else {
        setState(() {
          loadingRequests = false;
        });
      }
    } catch (e) {
      setState(() {
        loadingRequests = false;
      });

      print(e);
    }
  }

  /// =========================================================
  /// ADD BANNER REQUEST
  /// =========================================================

  Future<void> _showAddBannerDialog() async {
    final imageCtrl = TextEditingController();

    final linkCtrl = TextEditingController();

    final expiryCtrl = TextEditingController();

    bool isLoading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),

            title: const Text(
              'Add Banner',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: imageCtrl,
                    decoration: InputDecoration(
                      hintText: 'Banner image URL',
                      prefixIcon: const Icon(Icons.image_rounded),
                      filled: true,
                      fillColor: _kBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) {
                      setModalState(() {});
                    },
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: linkCtrl,
                    decoration: InputDecoration(
                      hintText: 'Optional link',
                      prefixIcon: const Icon(Icons.link_rounded),
                      filled: true,
                      fillColor: _kBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: expiryCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Expiry date',
                      prefixIcon: const Icon(Icons.calendar_today_rounded),
                      filled: true,
                      fillColor: _kBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );

                      if (date != null) {
                        expiryCtrl.text = date.toIso8601String().split('T')[0];
                      }
                    },
                  ),

                  const SizedBox(height: 18),

                  if (imageCtrl.text.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        imageCtrl.text,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return Container(
                            height: 160,
                            color: _kBackground,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),

              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (imageCtrl.text.trim().isEmpty) {
                          _showError('Please enter image URL');

                          return;
                        }

                        setModalState(() {
                          isLoading = true;
                        });

                        try {
                          final prefs = await SharedPreferences.getInstance();

                          final token = prefs.getString('token');

                          final res = await http.post(
                            Uri.parse('${AppConfig.baseUrl}/banner-requests'),
                            headers: {
                              'Authorization': 'Bearer $token',
                              'Content-Type': 'application/json',
                            },
                            body: jsonEncode({
                              'image': imageCtrl.text.trim(),
                              'link': linkCtrl.text.trim(),
                              'expiryDate': expiryCtrl.text.trim(),

                              'chefId': chef?['_id'],
                              'chefName': chef?['name'],
                              'chefEmail': chef?['email'],
                              'chefImage': chef?['profileImage'],
                              'chefLocation': chef?['location'],
                              'chefSpecialties': chef?['specialty'],
                            }),
                          );

                          if (res.statusCode == 200 || res.statusCode == 201) {
                            if (!mounted) return;

                            Navigator.pop(context);

                            _showSuccess('Banner request sent successfully');

                            _loadRequests();
                          } else {
                            final data = jsonDecode(res.body);

                            _showError(
                              data['message'] ?? 'Failed to send request',
                            );
                          }
                        } catch (e) {
                          _showError(e.toString());
                        }

                        setModalState(() {
                          isLoading = false;
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Send'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// =========================================================
  /// UI
  /// =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,

      appBar: AppBar(
        backgroundColor: _kPrimaryDark,

        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },

          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
        ),

        title: const Text(
          'Chef Banners',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),

        iconTheme: const IconThemeData(color: Colors.white),

        bottom: TabBar(
          controller: _tabController,

          labelColor: Colors.white,

          unselectedLabelColor: Colors.white70,

          indicatorColor: Colors.white,

          tabs: const [
            Tab(text: 'My Banners'),
            Tab(text: 'Requests'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.white,

        foregroundColor: _kPrimaryDark,

        onPressed: _showAddBannerDialog,

        label: const Text(
          'Add Banner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        icon: const Icon(Icons.add),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [_buildBannersTab(), _buildRequestsTab()],
      ),
    );
  }

  /// =========================================================
  /// BANNERS TAB
  /// =========================================================

  Widget _buildBannersTab() {
    if (loadingBanners) {
      return const Center(child: CircularProgressIndicator());
    }

    if (banners.isEmpty) {
      return const Center(child: Text('No banners yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: banners.length,
      itemBuilder: (context, index) {
        final banner = banners[index];

        final isExpired =
            banner['expiryDate'] != null &&
            DateTime.parse(banner['expiryDate']).isBefore(DateTime.now());

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Image.network(
                  banner['image'],
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      banner['link'] ?? '',
                      style: const TextStyle(
                        color: _kPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text('Expiry: ${banner['expiryDate'] ?? 'No expiry'}'),

                    const SizedBox(height: 12),

                    isExpired
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Expired',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// =========================================================
  /// REQUESTS TAB
  /// =========================================================

  Widget _buildRequestsTab() {
    if (loadingRequests) {
      return const Center(child: CircularProgressIndicator());
    }

    if (requests.isEmpty) {
      return const Center(child: Text('No requests yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];

        final status = request['status'];

        Color statusColor = Colors.orange;

        if (status == 'approved') {
          statusColor = Colors.green;
        }

        if (status == 'rejected') {
          statusColor = Colors.red;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  request['image'],
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['link'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toString().toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _kError));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _kAccent));
  }
}
