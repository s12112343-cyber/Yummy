import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'add_recipe_screen.dart';
import 'recipe_details_screen_for_chef.dart';
import 'package:frontend/features/auth/splash_screen.dart';
import 'package:frontend/features/auth/login_screen.dart';
import 'chef_banners_page.dart';
import '../../../core/services/chef_socket_service.dart';

const _kPrimaryDark = Color(0xFF0A1628);
const _kPrimaryLight = Color(0xFF3B82F6);
const _kAccent = Color(0xFF10B981);
const _kAccentOrange = Color(0xFFF59E0B);
const _kCard = Color(0xFFFFFFFF);
const _kBackground = Color(0xFFF8FAFC);
const _kText = Color(0xFF0F172A);
const _kTextSecondary = Color(0xFF64748B);
const _kTextTertiary = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kError = Color(0xFFEF4444);
const _kSuccess = Color(0xFF10B981);

String safeString(dynamic value) {
  if (value == null) return '';
  if (value is List) {
    return value.map((e) => e.toString()).join(', ');
  }
  return value.toString();
}

class ChefProfileScreen extends StatefulWidget {
  const ChefProfileScreen({super.key});

  @override
  State<ChefProfileScreen> createState() => _ChefProfileScreenState();
}

class _ChefProfileScreenState extends State<ChefProfileScreen>
    with SingleTickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════════════════
  // 📊 STATE VARIABLES
  // ═══════════════════════════════════════════════════════════════════════════
  Map<String, dynamic>? chef;
  bool loading = true;
  bool isSaving = false;
  bool isEditing = false;
  String cacheBuster = '';
  String? errorMessage;

  late TabController _tabController;

  // Recipe Section State
  List<Map<String, dynamic>> recipes = [];
  bool loadingRecipes = false;

  // Review Section State
  List<Map<String, dynamic>> reviews = [];
  bool loadingReviews = false;
  List<Map<String, dynamic>> followersList = [];
  bool loadingFollowers = false;
  // Text Controllers for Edit Mode
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();
  final TextEditingController _expCtrl = TextEditingController();
  final TextEditingController _locCtrl = TextEditingController();
  final List<String> _specialties = [];
  final TextEditingController _newSpecialtyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();

    _loadChef();

    _connectSocket(); // 🔥 أضيفي هاد
  }

  Future<void> _connectSocket() async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getString('userId');

    if (userId == null) return;

    ChefSocketService.connect(userId);

    print("SOCKET CONNECTED => $userId");
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _expCtrl.dispose();
    _locCtrl.dispose();
    _newSpecialtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFollowers() async {
    final chefId = chef?['_id'];

    if (chefId == null) return;

    setState(() => loadingFollowers = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/follow/chef-followers/$chefId'),

        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (mounted) {
          setState(() {
            followersList = List<Map<String, dynamic>>.from(
              data['followers'] ?? [],
            );

            loadingFollowers = false;
          });
        }
      } else {
        setState(() => loadingFollowers = false);
      }
    } catch (e) {
      setState(() => loadingFollowers = false);

      print(e);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📡 API CALLS (Keep all your existing API methods here)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _loadChef() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = await AuthService().getToken();

      // Also fallback to prefs if AuthService returned empty
      final effectiveToken = (token ?? '').trim().isNotEmpty
          ? token
          : prefs.getString('token');

      if (effectiveToken == null || effectiveToken.toString().trim().isEmpty) {
        if (mounted) {
          setState(() {
            loading = false;
            errorMessage = 'Please login first';
          });
        }
        return;
      }

      final url = Uri.parse('${AppConfig.baseUrl}/chefs/me');

      final res = await http
          .get(url, headers: {'Authorization': 'Bearer $effectiveToken'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        print("CHEF DATA => ${data['data']}");

        final chefData = data['data'];

        // 🔥 خزني chefId
        await prefs.setString('chefId', chefData['_id']?.toString() ?? '');

        if (mounted) {
          setState(() {
            chef = chefData;

            _nameCtrl.text = chef?['name'] ?? '';
            _bioCtrl.text = chef?['bio'] ?? '';
            _expCtrl.text = chef?['experience'] ?? '';
            _locCtrl.text = chef?['location'] ?? '';

            cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();

            final raw = chef?['specialty'];

            _specialties.clear();

            if (raw is List) {
              _specialties.addAll(List<String>.from(raw));
            } else if (raw != null) {
              _specialties.add(raw.toString());
            }

            loading = false;
            errorMessage = null;
          });
        }

        await _loadChefRecipes();
        await _loadChefReviews();
      } else {
        if (mounted) {
          setState(() {
            loading = false;
            errorMessage = 'Failed to load chef data (${res.statusCode})';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          errorMessage = 'Error: $e';
        });
      }
    }
  }

  Future<void> _deleteRecipe(String recipeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final res = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/recipes/$recipeId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        _showSuccess('Recipe deleted');

        await _loadChefRecipes();

        setState(() {});
      } else {
        _showError('Failed to delete recipe');
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _editRecipe(String recipeId, String currentName) async {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Recipe'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Recipe name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),

          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final prefs = await SharedPreferences.getInstance();

                final token = prefs.getString('token');

                final res = await http.patch(
                  Uri.parse('${AppConfig.baseUrl}/recipes/$recipeId'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({'name': controller.text}),
                );

                if (res.statusCode == 200) {
                  _showSuccess('Recipe updated');

                  await _loadChefRecipes();

                  setState(() {});
                } else {
                  _showError('Failed to update');
                }
              } catch (e) {
                _showError(e.toString());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadChefRecipes() async {
    final chefId = chef?['_id'];
    if (chefId == null) return;

    setState(() => loadingRecipes = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/recipes/chef/$chefId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        print("RECIPES DATA => ${data['data']}");
        if (mounted) {
          setState(() {
            recipes = List<Map<String, dynamic>>.from(data['data'] ?? []);
            loadingRecipes = false;
          });
        }
      } else {
        if (mounted) setState(() => loadingRecipes = false);
      }
    } catch (e) {
      if (mounted) setState(() => loadingRecipes = false);
    }
  }

  Future<void> _loadChefReviews() async {
    final chefId = chef?['_id'];

    if (chefId == null) return;

    setState(() {
      loadingReviews = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/reviews/chef/$chefId'),

        headers: {'Authorization': 'Bearer $token'},
      );

      print('REVIEWS STATUS => ${res.statusCode}');

      print('REVIEWS BODY => ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        final loadedReviews = List<Map<String, dynamic>>.from(
          data['data'] ?? [],
        );

        // ✅ حساب متوسط الريتنغ

        double avgRating = 0;

        if (loadedReviews.isNotEmpty) {
          double total = 0;

          for (var review in loadedReviews) {
            total += double.tryParse(review['rating'].toString()) ?? 0;
          }

          avgRating = total / loadedReviews.length;
        }

        if (mounted) {
          setState(() {
            reviews = loadedReviews;

            // ✅ تحديث ريتنغ الشيف

            chef?['rating'] = avgRating;

            loadingReviews = false;
          });
        }
      } else {
        setState(() {
          loadingReviews = false;
        });
      }
    } catch (e) {
      print('LOAD REVIEWS ERROR => $e');

      setState(() {
        loadingReviews = false;
      });
    }
  }

  Future<void> _saveAllChanges() async {
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final res = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/chefs/update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': _nameCtrl.text.trim(),
          'bio': _bioCtrl.text.trim(),
          'location': _locCtrl.text.trim(),
          'experience': _expCtrl.text.trim(),
          'specialty': _specialties,
        }),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            chef!['name'] = _nameCtrl.text.trim();
            chef!['bio'] = _bioCtrl.text.trim();
            chef!['location'] = _locCtrl.text.trim();
            chef!['experience'] = _expCtrl.text.trim();
            chef!['specialty'] = List.from(_specialties);
            isEditing = false;
            isSaving = false;
            cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
          });
        }
        _showSuccess("Profile updated successfully!");
      } else {
        if (mounted) setState(() => isSaving = false);
        _showError("Failed to update profile");
      }
    } catch (e) {
      if (mounted) setState(() => isSaving = false);
      _showError("Error: $e");
    }
  }

  void _addSpecialty() {
    if (_newSpecialtyCtrl.text.trim().isEmpty) return;
    setState(() {
      _specialties.add(_newSpecialtyCtrl.text.trim());
      _newSpecialtyCtrl.clear();
    });
  }

  void _removeSpecialty(String specialty) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Remove Specialty?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Are you sure you want to remove "$specialty"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _specialties.remove(specialty));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile == null) return;
    final file = File(pickedFile.path);
    if (!mounted) return;
    setState(() => isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${AppConfig.baseUrl}/chefs/image'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('image', file.path));
      final response = await request.send();

      if (response.statusCode == 200) {
        final resData = jsonDecode(await response.stream.bytesToString());
        if (mounted) {
          setState(() {
            chef!['profileImage'] = resData['imageUrl'];
            cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
            isSaving = false;
          });
        }
        _showSuccess("Profile image updated");
      } else {
        if (mounted) setState(() => isSaving = false);
        _showError("Upload failed");
      }
    } catch (e) {
      if (mounted) setState(() => isSaving = false);
      _showError("Error: $e");
    }
  }

  Future<void> _changeCoverImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile == null) return;
    final file = File(pickedFile.path);
    if (!mounted) return;
    setState(() => isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('${AppConfig.baseUrl}/chefs/cover'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('coverImage', file.path),
      );
      final response = await request.send();

      if (response.statusCode == 200) {
        final resData = jsonDecode(await response.stream.bytesToString());
        if (mounted) {
          setState(() {
            chef!['coverImage'] = resData['coverImageUrl'];
            cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
            isSaving = false;
          });
        }
        _showSuccess("Cover updated");
      } else {
        if (mounted) setState(() => isSaving = false);
        _showError("Upload failed");
      }
    } catch (e) {
      if (mounted) setState(() => isSaving = false);
      _showError("Error: $e");
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ⚙️ SETTINGS & ACCOUNT (Keep all your existing settings methods here)
  // ═══════════════════════════════════════════════════════════════════════════

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kPrimaryLight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: _kPrimaryLight,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _kText,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Divider(height: 1, thickness: 1),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildModernSettingsTile(
                      icon: Icons.email_rounded,
                      iconColor: _kPrimaryLight,
                      title: 'Change Email',
                      subtitle: chef?['email'] ?? 'update@example.com',
                      onTap: () {
                        Navigator.pop(context);
                        _showChangeEmailDialog();
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildModernSettingsTile(
                      icon: Icons.lock_rounded,
                      iconColor: _kAccentOrange,
                      title: 'Change Password',
                      subtitle: '••••••••',
                      onTap: () {
                        Navigator.pop(context);
                        _showChangePasswordDialog();
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildModernSettingsTile(
                      icon: Icons.campaign_rounded,
                      iconColor: _kAccent,
                      title: 'Add Banner',
                      subtitle: 'Send banner request to admin',
                      onTap: () {
                        Navigator.pop(context);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChefBannersPage(),
                          ),
                        );
                      },
                    ),
                    _buildModernSettingsTile(
                      icon: Icons.notifications_active_rounded,
                      iconColor: Colors.purple,
                      title: 'Send Notification',
                      subtitle: 'Request notification for users',
                      onTap: () {
                        Navigator.pop(context);

                        _showNotificationRequestDialog();
                      },
                    ),
                    const SizedBox(height: 24),
                    Container(
                      margin: const EdgeInsets.only(bottom: 32),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmLogout();
                        },
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kError,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _kText,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _kTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  void _showChangeEmailDialog() {
    final controller = TextEditingController(text: chef?['email'] ?? '');

    showDialog(
      context: context,

      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

        title: const Text(
          'Change Email',

          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        content: Column(
          mainAxisSize: MainAxisSize.min,

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Enter your new email address',

              style: TextStyle(color: _kTextSecondary),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: controller,

              keyboardType: TextInputType.emailAddress,

              decoration: InputDecoration(
                hintText: 'new@example.com',

                filled: true,

                fillColor: _kBackground,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),

                  borderSide: BorderSide.none,
                ),

                prefixIcon: const Icon(Icons.email_rounded),
              ),
            ),
          ],
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),

            child: const Text('Cancel'),
          ),

          ElevatedButton(
            onPressed: () async {
              try {
                final prefs = await SharedPreferences.getInstance();

                final token = prefs.getString('token');

                print("TOKEN => $token");

                final res = await http.patch(
                  Uri.parse('${AppConfig.baseUrl}/chefs/update-email'),

                  headers: {
                    'Authorization': 'Bearer $token',

                    'Content-Type': 'application/json',
                  },

                  body: jsonEncode({'email': controller.text.trim()}),
                );

                print("EMAIL STATUS => ${res.statusCode}");

                print("EMAIL BODY => ${res.body}");

                final data = jsonDecode(res.body);

                if (res.statusCode == 200) {
                  setState(() {
                    chef?['email'] = controller.text.trim();
                  });

                  Navigator.pop(context);

                  _showSuccess('Email updated successfully!');
                } else {
                  _showError(data['message'] ?? 'Failed to update email');
                }
              } catch (e) {
                print("EMAIL ERROR => $e");

                _showError(e.toString());
              }
            },

            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimaryLight,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();

    final newCtrl = TextEditingController();

    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,

      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

        title: const Text(
          'Change Password',

          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        content: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            TextField(
              controller: currentCtrl,

              obscureText: true,

              decoration: InputDecoration(
                hintText: 'Current password',

                filled: true,

                fillColor: _kBackground,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),

                  borderSide: BorderSide.none,
                ),

                prefixIcon: const Icon(Icons.lock_rounded),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: newCtrl,

              obscureText: true,

              decoration: InputDecoration(
                hintText: 'New password',

                filled: true,

                fillColor: _kBackground,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),

                  borderSide: BorderSide.none,
                ),

                prefixIcon: const Icon(Icons.lock_rounded),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: confirmCtrl,

              obscureText: true,

              decoration: InputDecoration(
                hintText: 'Confirm new password',

                filled: true,

                fillColor: _kBackground,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),

                  borderSide: BorderSide.none,
                ),

                prefixIcon: const Icon(Icons.lock_rounded),
              ),
            ),
          ],
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),

            child: const Text('Cancel'),
          ),

          ElevatedButton(
            onPressed: () async {
              if (currentCtrl.text.trim().isEmpty ||
                  newCtrl.text.trim().isEmpty ||
                  confirmCtrl.text.trim().isEmpty) {
                _showError('Please fill all fields');

                return;
              }

              if (newCtrl.text.trim() != confirmCtrl.text.trim()) {
                _showError('Passwords do not match');

                return;
              }

              try {
                final prefs = await SharedPreferences.getInstance();

                final token = prefs.getString('token');

                final res = await http.patch(
                  Uri.parse('${AppConfig.baseUrl}/chefs/update-password'),

                  headers: {
                    'Authorization': 'Bearer $token',

                    'Content-Type': 'application/json',
                  },

                  body: jsonEncode({
                    'currentPassword': currentCtrl.text.trim(),

                    'newPassword': newCtrl.text.trim(),
                  }),
                );

                print("PASSWORD STATUS => ${res.statusCode}");

                print("PASSWORD BODY => ${res.body}");

                final data = jsonDecode(res.body);

                if (res.statusCode == 200) {
                  // ✅ سكري dialog
                  Navigator.pop(context);

                  // ✅ امسحي البيانات
                  await prefs.clear();

                  if (!mounted) return;

                  // ✅ ارجعي لصفحة الدخول
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                } else {
                  _showError(data['message'] ?? 'Failed to update password');
                }
              } catch (e) {
                print("PASSWORD ERROR => $e");

                _showError(e.toString());
              }
            },

            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimaryLight,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        content: const Text('Are you sure you want to logout?'),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kError),

            onPressed: () async {
              Navigator.pop(context);

              final prefs = await SharedPreferences.getInstance();

              await prefs.clear();

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },

            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    showDialog(
      context: context,

      barrierDismissible: false,

      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        content: const Text('Are you sure you want to logout?'),

        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },

            child: const Text('Cancel'),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            onPressed: () async {
              Navigator.pop(context);

              // 🔥 loading
              showDialog(
                context: context,

                barrierDismissible: false,

                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

              final prefs = await SharedPreferences.getInstance();

              // ✅ امسحي كل البيانات
              await prefs.remove('token');

              await prefs.remove('userId');

              await prefs.remove('chefId');

              await prefs.remove('userName');

              await prefs.remove('userEmail');

              await prefs.remove('userRole');

              if (!mounted) return;

              Navigator.pop(context);

              // ✅ روح عاللوجن
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );

              // ✅ success message
              Future.delayed(const Duration(milliseconds: 300), () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logged out successfully 👋'),

                    behavior: SnackBarBehavior.floating,
                  ),
                );
              });
            },

            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: _kError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: _kSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon, {
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (iconColor ?? _kPrimaryLight).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? _kPrimaryLight,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPrimaryLight, _kPrimaryLight.withOpacity(0.7)],
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'C',
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCoverFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPrimaryLight.withOpacity(0.2), _kAccent.withOpacity(0.2)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          color: _kPrimaryLight,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildEditModeUI() {
    final base = AppConfig.baseUrl.replaceAll('/api', '');
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: _kPrimaryDark,
        elevation: 0,
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => setState(() => isEditing = false),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: isSaving ? null : _saveAllChanges,
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check_rounded, color: Colors.white),
              label: Text(
                isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: _kAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _changeCoverImage,
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: (chef?['coverImage'] ?? '').isNotEmpty
                          ? Image.network(
                              '${base}${chef?['coverImage']}?t=$cacheBuster',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildCoverFallback(),
                            )
                          : _buildCoverFallback(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _kPrimaryLight,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimaryLight.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Change Cover',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _changeProfileImage,
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _kCard, width: 5),
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimaryLight.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: (chef?['profileImage'] ?? '').isNotEmpty
                          ? Image.network(
                              '${base}${chef?['profileImage']}?t=$cacheBuster',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildAvatarFallback(chef?['name'] ?? 'Chef'),
                            )
                          : _buildAvatarFallback(chef?['name'] ?? 'Chef'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _kPrimaryLight,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimaryLight.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Change Photo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildModernTextField(
              controller: _nameCtrl,
              label: 'Name',
              hint: 'Enter your name',
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 20),
            _buildModernTextField(
              controller: _bioCtrl,
              label: 'Bio',
              hint: 'Tell us about yourself...',
              icon: Icons.description_rounded,
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.star_rounded, color: _kAccentOrange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Specialties',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _kText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_specialties.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _specialties
                          .map(
                            (s) => Chip(
                              label: Text(s),
                              deleteIcon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                              ),
                              onDeleted: () => _removeSpecialty(s),
                              backgroundColor: _kAccent.withOpacity(0.1),
                              labelStyle: const TextStyle(
                                color: _kAccent,
                                fontWeight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: _kAccent.withOpacity(0.3),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newSpecialtyCtrl,
                          decoration: InputDecoration(
                            hintText: 'Add specialty',
                            filled: true,
                            fillColor: _kBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: _kAccent,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _kAccent.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: _addSpecialty,
                          icon: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildModernTextField(
              controller: _expCtrl,
              label: 'Experience',
              hint: 'e.g. 5 years as head chef',
              icon: Icons.work_rounded,
            ),
            const SizedBox(height: 20),
            _buildModernTextField(
              controller: _locCtrl,
              label: 'Location',
              hint: 'e.g. New York, USA',
              icon: Icons.location_on_rounded,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
        ),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: _kCard,
            prefixIcon: Icon(icon, color: _kPrimaryLight),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _kPrimaryLight, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildRecipesTab() {
    if (loadingRecipes) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _kPrimaryLight),
            SizedBox(height: 16),
            Text(
              'Loading recipes...',
              style: TextStyle(color: _kTextSecondary),
            ),
          ],
        ),
      );
    }

    // ✅ إذا ما في وصفات
    if (recipes.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _kPrimaryLight.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.restaurant_menu_rounded,
                          size: 64,
                          color: _kPrimaryLight,
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'No Recipes Yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _kText,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Start sharing your culinary creations!',
                        style: TextStyle(color: _kTextSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 🔥 زر الإضافة تحت
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddRecipeScreen(),
                      ),
                    );

                    if (result == true) {
                      await _loadChefRecipes();
                      setState(() {});
                    }
                  },

                  icon: const Icon(Icons.add_rounded),

                  label: const Text('Add Recipe'),

                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: Colors.white,

                    padding: const EdgeInsets.symmetric(vertical: 16),

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ✅ إذا في وصفات
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),

              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.58,
                ),

                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildRecipeCard(recipes[index]),

                  childCount: recipes.length,
                ),
              ),
            ),
          ],
        ),

        // 🔥 زر ثابت تحت
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,

          child: SafeArea(
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddRecipeScreen()),
                );

                if (result == true) {
                  await _loadChefRecipes();
                  setState(() {});
                }
              },

              icon: const Icon(Icons.add_rounded),

              label: const Text('Add Recipe'),

              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccent,
                foregroundColor: Colors.white,

                padding: const EdgeInsets.symmetric(vertical: 16),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),

                elevation: 8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // 🔥 IMAGE SECTION
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),

                child:
                    recipe['image'] != null &&
                        recipe['image'].toString().isNotEmpty
                    ? Image.network(
                        recipe['image'].toString().startsWith('http')
                            ? recipe['image']
                            : '${AppConfig.baseUrl.replaceAll('/api', '')}${recipe['image']}',

                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,

                        errorBuilder: (_, __, ___) {
                          print("IMAGE ERROR => ${recipe['image']}");

                          return Container(
                            height: 150,
                            color: _kBackground,

                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                size: 40,
                                color: _kTextTertiary,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        height: 150,
                        color: _kBackground,

                        child: const Center(
                          child: Icon(
                            Icons.restaurant_menu_rounded,
                            size: 40,
                            color: _kTextTertiary,
                          ),
                        ),
                      ),
              ),

              // 🔥 VIEW + EDIT + DELETE
              Positioned(
                top: 8,
                right: 8,

                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),

                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: Row(
                    children: [
                      // 👁️ VIEW
                      IconButton(
                        icon: const Icon(
                          Icons.visibility_rounded,
                          size: 18,
                          color: Colors.white,
                        ),

                        onPressed: () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder: (_) =>
                                  RecipeDetailsScreen(recipe: recipe),
                            ),
                          );
                        },

                        padding: EdgeInsets.zero,

                        constraints: const BoxConstraints(),
                      ),

                      const SizedBox(width: 10),

                      // 🗑️ DELETE
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Colors.white,
                        ),

                        onPressed: () => _showDeleteRecipeDialog(recipe['_id']),

                        padding: EdgeInsets.zero,

                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 🔥 INFO SECTION
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // 🔥 NAME
                  Text(
                    recipe['name'] ?? 'Untitled',

                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,

                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _kText,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 🔥 DESCRIPTION
                  if (recipe['description'] != null)
                    Text(
                      recipe['description'],

                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,

                      style: const TextStyle(
                        fontSize: 12,
                        color: _kTextSecondary,
                        height: 1.4,
                      ),
                    ),

                  const Spacer(),

                  // 🔥 STATS
                  Align(
                    alignment: Alignment.centerRight,

                    child: Text(
                      '\$${recipe['price'] ?? 0}',

                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _kAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteRecipeDialog(String? recipeId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete Recipe?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteRecipe(recipeId!);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _kError),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 👨‍🍳 ABOUT TAB
  // ============================================================
  Widget _buildAboutTab() {
    final bio = chef?['bio'] ?? 'No bio yet';
    final experience = chef?['experience'] ?? 'Not specified';
    final location = chef?['location'] ?? 'Not specified';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio Section
          if (bio.isNotEmpty && bio != 'No bio yet')
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _kPrimaryLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.format_quote_rounded,
                          color: _kPrimaryLight,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'About Me',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _kText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    bio,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: _kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Specialties Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _kAccentOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: _kAccentOrange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Specialties',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _kText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_specialties.isEmpty)
                  const Text(
                    'No specialties added yet',
                    style: TextStyle(color: _kTextSecondary),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _specialties.map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _kAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kAccent.withOpacity(0.3)),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            color: _kAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(height: 1),
                ),
                _buildDetailRow(
                  icon: Icons.work_rounded,
                  iconColor: _kPrimaryLight,
                  title: 'Experience',
                  value: experience,
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  icon: Icons.location_on_rounded,
                  iconColor: _kError,
                  title: 'Location',
                  value: location,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 14, color: _kTextSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ⭐ REVIEWS TAB - Direct Display (FIXED Overflow)
  // ============================================================
  Widget _buildReviewsTab() {
    if (loadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reviews.isEmpty) {
      return const Center(child: Text('No reviews yet'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),

      itemCount: reviews.length,

      separatorBuilder: (_, __) => const SizedBox(height: 12),

      itemBuilder: (context, index) {
        final review = reviews[index];

        final user = review['userId'] ?? {};

        final rating = review['rating'] ?? 0;

        return _buildReviewCard(user, rating, review);
      },
    );
  }

  Widget _buildReviewCard(
    Map<String, dynamic> user,
    int rating,
    Map<String, dynamic> review,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _kPrimaryLight.withOpacity(0.1),
                backgroundImage:
                    user['profileImage'] != null &&
                        user['profileImage'].isNotEmpty
                    ? NetworkImage(user['profileImage'])
                    : null,
                child:
                    user['profileImage'] == null || user['profileImage'].isEmpty
                    ? Text(
                        user['name']?[0].toUpperCase() ?? 'U',
                        style: const TextStyle(
                          color: _kPrimaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'] ?? 'Unknown User',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _kText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: _kAccentOrange,
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              if (review['date'] != null)
                Text(
                  _formatDate(review['date']),
                  style: const TextStyle(fontSize: 12, color: _kTextTertiary),
                ),
            ],
          ),
          if (review['comment']?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text(
              review['comment'],
              style: const TextStyle(
                fontSize: 14,
                color: _kTextSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final parsed = DateTime.parse(date.toString());
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (e) {
      return '';
    }
  }

  // ============================================================
  // 📱 MAIN BUILD
  // ============================================================
  void _showNotificationRequestDialog() {
    final titleCtrl = TextEditingController();

    final messageCtrl = TextEditingController();

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
              'Send Notification Request',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'Notification title',

                      filled: true,

                      fillColor: _kBackground,

                      prefixIcon: const Icon(Icons.title_rounded),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),

                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: messageCtrl,

                    maxLines: 5,

                    decoration: InputDecoration(
                      hintText: 'Write your message here...',

                      filled: true,

                      fillColor: _kBackground,

                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 70),
                        child: Icon(Icons.message_rounded),
                      ),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),

                        borderSide: BorderSide.none,
                      ),
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

              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (titleCtrl.text.trim().isEmpty) {
                          _showError('Please enter title');

                          return;
                        }

                        if (messageCtrl.text.trim().isEmpty) {
                          _showError('Please enter message');

                          return;
                        }

                        setModalState(() {
                          isLoading = true;
                        });

                        try {
                          final prefs = await SharedPreferences.getInstance();

                          final token = prefs.getString('token');

                          final res = await http.post(
                            Uri.parse(
                              '${AppConfig.baseUrl}/notification-requests',
                            ),

                            headers: {
                              'Authorization': 'Bearer $token',

                              'Content-Type': 'application/json',
                            },

                            body: jsonEncode({
                              'title': titleCtrl.text.trim(),

                              'message': messageCtrl.text.trim(),

                              'chefName': chef?['name'],
                            }),
                          );

                          print('REQUEST STATUS => ${res.statusCode}');

                          print('REQUEST BODY => ${res.body}');

                          if (res.statusCode == 201 || res.statusCode == 200) {
                            if (!mounted) return;

                            Navigator.pop(context);

                            _showSuccess('Request sent to admin 🔥');
                          } else {
                            final data = jsonDecode(res.body);

                            _showError(
                              data['message'] ?? 'Failed to send request',
                            );
                          }
                        } catch (e) {
                          print(e);

                          _showError(e.toString());
                        }

                        setModalState(() {
                          isLoading = false;
                        });
                      },

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),

                label: Text(
                  isLoading ? 'Sending...' : 'Send',

                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isEditing) return _buildEditModeUI();

    if (loading) {
      return Scaffold(
        backgroundColor: _kBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _kCard,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimaryLight.withOpacity(0.2),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const CircularProgressIndicator(
                  color: _kPrimaryLight,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Loading profile...',
                style: TextStyle(
                  fontSize: 16,
                  color: _kTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (chef == null || errorMessage != null) {
      return Scaffold(
        backgroundColor: _kBackground,
        appBar: AppBar(
          backgroundColor: _kPrimaryDark,
          title: const Text(
            'Chef Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _kError.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: _kError,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  errorMessage ?? 'Error loading profile',
                  style: const TextStyle(
                    color: _kText,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please try again',
                  style: TextStyle(color: _kTextSecondary, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      loading = true;
                      errorMessage = null;
                    });
                    _loadChef();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryLight,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final base = AppConfig.baseUrl.replaceAll('/api', '');
    final name = chef?['name'] ?? 'Chef';
    final email = chef?['email'] ?? '';
    final image = chef?['profileImage'] ?? '';
    final coverImage = chef?['coverImage'] ?? '';
    final rating = (chef?['rating'] ?? 0).toDouble();
    final recipesCount = recipes.length.toString();
    return Scaffold(
      backgroundColor: _kBackground,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              automaticallyImplyLeading: false,
              expandedHeight: 200,
              pinned: true,
              backgroundColor: _kPrimaryDark,
              flexibleSpace: FlexibleSpaceBar(
                background: coverImage.isNotEmpty
                    ? Image.network(
                        '$base$coverImage?t=$cacheBuster',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildCoverFallback(),
                      )
                    : _buildCoverFallback(),
              ),
              actions: [
                const SizedBox(width: 8),

                // ✏️ EDIT
                _buildTopIcon(
                  icon: Icons.edit_rounded,
                  color: _kPrimaryLight,
                  onTap: () => setState(() => isEditing = true),
                ),

                const SizedBox(width: 8),

                // ⚙️ SETTINGS
                _buildTopIcon(
                  icon: Icons.settings_rounded,
                  color: _kAccent,
                  onTap: _openSettingsSheet,
                ),

                const SizedBox(width: 12),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(120),
                child: Column(
                  children: [
                    Transform.translate(
                      offset: const Offset(0, 50),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _kCard, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: _kPrimaryLight.withOpacity(0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: image.isNotEmpty
                              ? Image.network(
                                  '$base$image?t=$cacheBuster',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildAvatarFallback(name),
                                )
                              : _buildAvatarFallback(name),
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _kText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _kTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          rating.toStringAsFixed(1),
                          'Rating',
                          Icons.star_rounded,
                          iconColor: _kAccentOrange,
                          onTap: () => _tabController.animateTo(2),
                        ),

                        Container(width: 1, height: 50, color: _kBorder),
                        _buildStatItem(
                          recipesCount,
                          'Recipes',
                          Icons.restaurant_rounded,
                          iconColor: _kPrimaryLight,
                          onTap: () => _tabController.animateTo(0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Modern Tab Bar Design
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _kBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: _kPrimaryLight,
                      unselectedLabelColor: _kTextSecondary,
                      indicator: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      tabs: const [
                        Tab(text: '🍔 RECIPES'),
                        Tab(text: '👨‍🍳 ABOUT'),
                        Tab(text: '⭐ REVIEWS'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [_buildRecipesTab(), _buildAboutTab(), _buildReviewsTab()],
        ),
      ),
    );
  }

  Widget _buildTopIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
