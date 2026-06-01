import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/auth_service.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage>
    with TickerProviderStateMixin {
  List<dynamic> _users = [];
  bool _loading = true;
  String _search = '';
  String _selectedRoleFilter = 'all';
  String _error = '';

  late AnimationController _listController;
  late AnimationController _headerController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
    _loadUsers();
  }

  @override
  void dispose() {
    _listController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final token = await AuthService().getToken();
      if (token == null) throw Exception('No token found');

      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/users/all'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rawUsers = (data['users'] as List?) ?? [];
        final normalizedUsers = rawUsers.map((u) {
          if (u is Map<String, dynamic>) {
            return {...u, 'isBanned': u['isBanned'] == true};
          }
          if (u is Map) {
            final casted = Map<String, dynamic>.from(u);
            return {...casted, 'isBanned': casted['isBanned'] == true};
          }
          return u;
        }).toList();

        setState(() {
          _users = normalizedUsers;
          _loading = false;
        });
        _listController.forward(from: 0);
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ================= إضافة مستخدم جديد =================
  Future<void> _addNewUser() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final imageUrlController = TextEditingController();
    final specialtyController = TextEditingController();
    final bioController = TextEditingController();

    String selectedRole = 'admin';

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return _AnimatedDialog(
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                selectedRole == 'admin' ? 'Add New Admin' : 'Add New Chef',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepBlue,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Role Selection
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.babyBlueLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildRoleOption(
                              title: 'Admin',
                              icon: Icons.admin_panel_settings,
                              role: 'admin',
                              selectedRole: selectedRole,
                              onTap: () {
                                setStateDialog(() {
                                  selectedRole = 'admin';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildRoleOption(
                              title: 'Chef',
                              icon: Icons.restaurant,
                              role: 'chef',
                              selectedRole: selectedRole,
                              onTap: () {
                                setStateDialog(() {
                                  selectedRole = 'chef';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Common Fields
                    _buildAnimatedField(
                      controller: nameController,
                      label: 'Full Name *',
                      hint: 'Enter full name',
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 12),
                    _buildAnimatedField(
                      controller: emailController,
                      label: 'Email *',
                      hint: 'Enter email address',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    _buildAnimatedField(
                      controller: passwordController,
                      label: 'Password *',
                      hint: 'Enter password (min 6 characters)',
                      icon: Icons.lock,
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    _buildAnimatedField(
                      controller: imageUrlController,
                      label: 'Profile Image URL',
                      hint: 'https://example.com/image.jpg',
                      icon: Icons.image,
                    ),
                    const SizedBox(height: 12),

                    // Chef Specific Fields
                    if (selectedRole == 'chef') ...[
                      const Divider(),
                      const Text(
                        'Chef Details',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildAnimatedField(
                        controller: specialtyController,
                        label: 'Specialty *',
                        hint: 'e.g., Italian, Pastry, Grill',
                        icon: Icons.work,
                      ),
                      const SizedBox(height: 12),
                      _buildAnimatedField(
                        controller: bioController,
                        label: 'Bio',
                        hint: 'Short description about the chef',
                        icon: Icons.description,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Note
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.babyBlueLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.blueGray,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedRole == 'admin'
                                  ? 'Note: This will create a new Admin user'
                                  : 'Note: This will create a new Chef user with specialty',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.blueGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.blueGray),
                  ),
                ),
                _TapScaleWidget(
                  onTap: () {
                    if (nameController.text.isEmpty) {
                      _showToast('Please enter name', isError: true);
                      return;
                    }
                    if (emailController.text.isEmpty) {
                      _showToast('Please enter email', isError: true);
                      return;
                    }
                    if (passwordController.text.isEmpty) {
                      _showToast('Please enter password', isError: true);
                      return;
                    }
                    if (passwordController.text.length < 6) {
                      _showToast(
                        'Password must be at least 6 characters',
                        isError: true,
                      );
                      return;
                    }
                    if (selectedRole == 'chef' &&
                        specialtyController.text.isEmpty) {
                      _showToast(
                        'Please enter specialty for chef',
                        isError: true,
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.royalBlue, AppColors.mediumBlue],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      selectedRole == 'admin' ? 'Create Admin' : 'Create Chef',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result == true) {
      await _createUser(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        role: selectedRole,
        profileImage: imageUrlController.text.trim(),
        specialty: selectedRole == 'chef'
            ? specialtyController.text.trim()
            : null,
        bio: selectedRole == 'chef' ? bioController.text.trim() : null,
      );
    }
  }

  Widget _buildAnimatedField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    int maxLines = 1,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) => Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - opacity)),
          child: child,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.royalBlue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.babyBlueLight,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.royalBlue,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleOption({
    required String title,
    required IconData icon,
    required String role,
    required String selectedRole,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedRole == role;
    return _TapScaleWidget(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.royalBlue, AppColors.mediumBlue],
                )
              : null,
          color: isSelected ? null : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.royalBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.royalBlue,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.deepBlue,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String profileImage = '',
    String? specialty,
    String? bio,
  }) async {
    try {
      final token = await AuthService().getToken();

      final Map<String, dynamic> userData = {
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'profileImage': profileImage,
      };

      if (role == 'chef') {
        userData['specialty'] = specialty ?? '';
        userData['bio'] = bio ?? '';
      }

      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/users/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(userData),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        _showToast(
          '${role == 'admin' ? 'Admin' : 'Chef'} created successfully',
        );
        await _loadUsers();
      } else {
        final error = jsonDecode(res.body);
        _showToast(error['message'] ?? 'Failed to create user', isError: true);
      }
    } catch (e) {
      _showToast('Error creating user', isError: true);
    }
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? AppColors.red : const Color(0xFF3B6D11),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UserDetailsSheet(user: user),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'N/A';
    }
  }

  Future<void> _deleteUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => _AnimatedDialog(
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete User',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.deepBlue,
            ),
          ),
          content: const Text(
            'Are you sure you want to delete this user?\nThis action cannot be undone.',
            style: TextStyle(color: AppColors.blueGray),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.blueGray),
              ),
            ),
            _TapScaleWidget(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final token = await AuthService().getToken();
      await http.delete(
        Uri.parse('${AppConfig.baseUrl}/users/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      setState(() => _users.removeWhere((u) => u['_id'] == id));
      _showToast('User deleted successfully');
    } catch (_) {
      _showToast('Error deleting user', isError: true);
    }
  }

  Future<void> _toggleBan(String id, bool isBanned) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isBanned ? 'Unban User' : 'Ban User'),
        content: Text(
          isBanned
              ? 'Are you sure you want to unban this user?'
              : 'Are you sure you want to ban this user?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isBanned ? 'Unban' : 'Ban'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await AuthService().getToken();

      final res = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/users/$id/ban'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isBanned': !isBanned}),
      );

      print("BAN STATUS 👉 ${res.statusCode}");
      print("BAN RESPONSE 👉 ${res.body}");

      if (res.statusCode != 200) {
        _showToast('Failed to update user', isError: true);
        return;
      }

      final data = jsonDecode(res.body);
      final updatedUser = data['user'];
      final updatedBanState =
          data['isBanned'] == true ||
          (updatedUser is Map && updatedUser['isBanned'] == true);

      setState(() {
        final i = _users.indexWhere((u) => u['_id'] == id);
        if (i != -1) {
          _users[i]['isBanned'] = updatedBanState;
        }
      });

      _showToast(updatedBanState ? 'User banned' : 'User unbanned');
    } catch (e) {
      print("BAN ERROR 👉 $e");
      _showToast('Error updating user status', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredByRole = _selectedRoleFilter == 'all'
        ? _users
        : _users.where((u) => u['role'] == _selectedRoleFilter).toList();

    final filtered = filteredByRole.where((u) {
      final name = (u['name'] ?? '').toLowerCase();
      final email = (u['email'] ?? '').toLowerCase();
      final query = _search.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

    final totalUsers = _users.length;
    final activeUsers = _users.where((u) => !(u['isBanned'] ?? false)).length;
    final bannedUsers = _users.where((u) => u['isBanned'] ?? false).length;

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.scale(scale: 0.9 + 0.1 * value, child: child),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.red,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.blueGray),
            ),
            const SizedBox(height: 16),
            _TapScaleWidget(
              onTap: _loadUsers,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.royalBlue, AppColors.mediumBlue],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutBack,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: FloatingActionButton(
          onPressed: _addNewUser,
          backgroundColor: AppColors.royalBlue,
          tooltip: 'Add Staff Member',
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Animated Header
            FadeTransition(
              opacity: _headerController,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, -0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _headerController,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: Row(
                  children: [
                    const Text(
                      'Users Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepBlue,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(_users.length),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.babyBlueLight,
                              AppColors.babyBlue,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_users.length} users',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.royalBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stats Cards
            Row(
              children: [
                _buildStatCard('Total', totalUsers.toString(), Colors.blue),
                const SizedBox(width: 8),
                _buildStatCard('Active', activeUsers.toString(), Colors.green),
                const SizedBox(width: 8),
                _buildStatCard('Banned', bannedUsers.toString(), Colors.red),
              ],
            ),
            const SizedBox(height: 16),

            // Search Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      hintStyle: TextStyle(
                        color: AppColors.blueGray.withOpacity(0.6),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.blueGray,
                      ),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: AppColors.blueGray,
                              ),
                              onPressed: () => setState(() => _search = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.white,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.royalBlue,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.filter_list_rounded,
                      color: AppColors.royalBlue,
                    ),
                    onSelected: (value) =>
                        setState(() => _selectedRoleFilter = value),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'all', child: Text('All')),
                      const PopupMenuItem(value: 'user', child: Text('Users')),
                      const PopupMenuItem(value: 'chef', child: Text('Chefs')),
                      const PopupMenuItem(
                        value: 'admin',
                        child: Text('Admins'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Role Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Users', 'user'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Chefs', 'chef'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Admins', 'admin'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Users List
            Expanded(
              child: _loading
                  ? ListView.builder(
                      itemCount: 5,
                      itemBuilder: (_, i) => _buildShimmerCard(i),
                    )
                  : filtered.isEmpty
                  ? _buildEmpty()
                  : _buildUsersList(filtered),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList(List filtered) {
    return AnimatedBuilder(
      animation: _listController,
      builder: (context, child) {
        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final startTime = (i * 0.08).clamp(0.0, 0.7);
            final endTime = (startTime + 0.4).clamp(0.0, 1.0);
            final anim = CurvedAnimation(
              parent: _listController,
              curve: Interval(startTime, endTime, curve: Curves.easeOutCubic),
            );

            final user = filtered[i];

            return FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: _buildUserCard(user),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isBanned = user['isBanned'] ?? false;
    final role = user['role'] ?? 'user';
    final profileImage = user['profileImage'];

    return Dismissible(
      key: Key(user['_id']),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.red, Color(0xFFE57373)],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog(
          context: context,
          barrierColor: Colors.black38,
          builder: (ctx) => _AnimatedDialog(
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Delete User'),
              content: const Text('Are you sure you want to delete this user?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: AppColors.red),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      onDismissed: (_) => _deleteUser(user['_id']),
      child: GestureDetector(
        onTap: () => _showUserDetails(user),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.navy.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with ring
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.lightSky, AppColors.mediumBlue],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: isBanned
                        ? const Color(0xFFFCEBEB)
                        : AppColors.babyBlue,
                    backgroundImage:
                        profileImage != null &&
                            profileImage.toString().isNotEmpty
                        ? NetworkImage(
                            profileImage.toString().startsWith('http')
                                ? profileImage.toString()
                                : '${AppConfig.baseUrl.replaceAll('/api', '')}${profileImage.toString()}',
                          )
                        : null,
                    child: (profileImage == null || profileImage.isEmpty)
                        ? Text(
                            (user['name'] != null && user['name'].isNotEmpty)
                                ? (user['name'] as String)[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: isBanned
                                  ? const Color(0xFFA32D2D)
                                  : AppColors.royalBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'] ?? 'No name',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepBlue,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user['email'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.blueGray,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildStatusChip(isBanned),
                        _buildRoleChip(role),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isBanned)
                    _TapScaleWidget(
                      onTap: () => _toggleBan(user['_id'], isBanned),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.block_rounded,
                          color: Colors.orange,
                          size: 19,
                        ),
                      ),
                    ),
                  if (isBanned)
                    _TapScaleWidget(
                      onTap: () => _toggleBan(user['_id'], isBanned),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 19,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  _TapScaleWidget(
                    onTap: () => _deleteUser(user['_id']),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppColors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.red,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.blueGray),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerCard(int i) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.6),
      duration: Duration(milliseconds: 700 + i * 150),
      curve: Curves.easeInOut,
      builder: (_, value, _) => Container(
        height: 90,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200.withOpacity(value),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.babyBlueLight,
                    AppColors.babyBlue.withOpacity(0.5),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                size: 52,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _search.isNotEmpty || _selectedRoleFilter != 'all'
                  ? 'No matching users'
                  : 'No users yet',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.deepBlue,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _addNewUser,
              icon: const Icon(Icons.add),
              label: const Text('Add your first staff member'),
              style: TextButton.styleFrom(foregroundColor: AppColors.royalBlue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedRoleFilter == value;
    return _TapScaleWidget(
      onTap: () => setState(() => _selectedRoleFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.royalBlue, AppColors.mediumBlue],
                )
              : null,
          color: isSelected ? null : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.royalBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : AppColors.blueGray,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isBanned) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isBanned
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isBanned ? 'Banned' : 'Active',
        style: TextStyle(
          fontSize: 10,
          color: isBanned ? Colors.red : Colors.green,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    Color bg = AppColors.babyBlueLight;
    Color text = AppColors.royalBlue;
    if (role == 'chef') {
      bg = const Color(0xFFEAF3DE);
      text = const Color(0xFF3B6D11);
    } else if (role == 'admin') {
      bg = const Color(0xFFFAEEDA);
      text = const Color(0xFF854F0B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}

// User Details Bottom Sheet
class _UserDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> user;

  const _UserDetailsSheet({required this.user});

  @override
  State<_UserDetailsSheet> createState() => _UserDetailsSheetState();
}

class _UserDetailsSheetState extends State<_UserDetailsSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  String fixImage(String? image) {
    if (image == null || image.isEmpty) {
      return '';
    }

    if (image.startsWith('http')) {
      return image;
    }

    final server = AppConfig.baseUrl.replaceAll('/api', '');

    return '$server$image';
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isBanned = user['isBanned'] ?? false;
    final role = user['role'] ?? 'user';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.labelGray.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Avatar
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.lightSky, AppColors.mediumBlue],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: isBanned
                      ? const Color(0xFFFCEBEB)
                      : AppColors.babyBlue,
                  backgroundImage:
                      user['profileImage'] != null &&
                          user['profileImage'].toString().isNotEmpty
                      ? NetworkImage(fixImage(user['profileImage']?.toString()))
                      : null,
                  child: user['profileImage'] == null
                      ? Text(
                          (user['name'] != null && user['name'].isNotEmpty)
                              ? (user['name'] as String)[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isBanned
                                ? const Color(0xFFA32D2D)
                                : AppColors.royalBlue,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user['name'] ?? 'Unknown',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.deepBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user['email'] ?? 'No email',
            style: const TextStyle(fontSize: 14, color: AppColors.blueGray),
          ),
          const SizedBox(height: 20),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statPill(
                Icons.person_rounded,
                role.toUpperCase(),
                'Role',
                AppColors.royalBlue,
              ),
              _statPill(
                isBanned ? Icons.block_rounded : Icons.check_circle_rounded,
                isBanned ? 'Banned' : 'Active',
                'Status',
                isBanned ? AppColors.red : const Color(0xFF3B6D11),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Details
          ...([
            _detail(
              Icons.calendar_today_rounded,
              'Joined',
              _fmtDate(user['createdAt']),
            ),
            if (role == 'chef') ...[
              _detail(
                Icons.work_rounded,
                'Specialty',

                user['specialty'] is List
                    ? (user['specialty'] as List).join(', ')
                    : (user['specialty']?.toString() ?? 'N/A'),
              ),

              _detail(
                Icons.description_rounded,
                'Bio',

                user['bio'] is List
                    ? (user['bio'] as List).join(', ')
                    : (user['bio']?.toString() ?? 'No bio available'),
              ),
            ],
          ].asMap().entries.map(
            (e) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 300 + e.key * 80),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - value)),
                  child: child,
                ),
              ),
              child: e.value,
            ),
          )),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.deepBlue,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.blueGray),
          ),
        ],
      ),
    );
  }

  Widget _detail(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.babyBlueLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.royalBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.blueGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.deepBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(String? ds) {
    if (ds == null) return 'N/A';
    try {
      final d = DateTime.parse(ds);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return 'N/A';
    }
  }
}

// Helpers
class _TapScaleWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _TapScaleWidget({required this.child, required this.onTap});

  @override
  State<_TapScaleWidget> createState() => _TapScaleWidgetState();
}

class _TapScaleWidgetState extends State<_TapScaleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 110),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: Tween(
          begin: 1.0,
          end: 0.93,
        ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
        child: widget.child,
      ),
    );
  }
}

class _AnimatedDialog extends StatefulWidget {
  final Widget child;

  const _AnimatedDialog({required this.child});

  @override
  State<_AnimatedDialog> createState() => _AnimatedDialogState();
}

class _AnimatedDialogState extends State<_AnimatedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    )..forward();
    _scale = Tween(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
