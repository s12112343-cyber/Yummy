import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/auth_service.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  Map<String, dynamic> _admin = {};
  bool _loading = true;
  File? _pickedImage;
  bool _uploadingImage = false;

  // Controllers — بتنتقل للصفحات الفرعية
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // ── Colors ─────────────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF0F4F8);
  static const _white = Colors.white;
  static const _blue = Color(0xFF1B5BCE);
  static const _navy = Color(0xFF0D1F4C);
  static const _text = Color(0xFF0D1F4C);
  static const _sub = Color(0xFF6B7B99);
  static const _divide = Color(0xFFEAEEF5);
  static const _red = Color(0xFFE53935);
  static const _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final t = await AuthService().getToken();
      if (t == null) throw Exception();
      final r = await http.get(
        Uri.parse('${AppConfig.baseUrl}/users/profile'),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (r.statusCode == 200) {
        final u = jsonDecode(r.body)['user'] ?? {};
        setState(() {
          _admin = u;
          _nameCtrl.text = u['name'] ?? '';
          _emailCtrl.text = u['email'] ?? '';
          _phoneCtrl.text = u['phone'] ?? '';
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // رفع الصورة
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null) return;
    setState(() {
      _pickedImage = File(picked.path);
      _uploadingImage = true;
    });
    try {
      final t = await AuthService().getToken();
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.baseUrl}/users/upload-avatar'),
      );
      req.headers['Authorization'] = 'Bearer $t';
      req.files.add(await http.MultipartFile.fromPath('avatar', picked.path));
      final resp = await req.send();
      final body = await resp.stream.bytesToString();
      if (resp.statusCode == 200) {
        final d = jsonDecode(body);
        setState(() {
          _admin['profileImage'] =
              d['imageUrl'] ?? d['url'] ?? _admin['profileImage'];
          _pickedImage = null;
        });
        _toast('Photo updated!');
      } else {
        _toast('Upload failed', error: true);
        setState(() => _pickedImage = null);
      }
    } catch (_) {
      _toast('Upload error', error: true);
      setState(() => _pickedImage = null);
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: _white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: error ? _red : _green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(14),
      ),
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w700, color: _text),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: _sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _sub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: _white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final p = await SharedPreferences.getInstance();
      await p.clear();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _blue, strokeWidth: 2.5),
        ),
      );
    }

    final name = _admin['name'] ?? 'Admin';
    final email = _admin['email'] ?? '';
    final img = _admin['profileImage'];

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar: avatar + name + gear ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    // Avatar
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        GestureDetector(
                          onTap: _uploadingImage ? null : _pickImage,
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: const Color(0xFFE0F1FF),
                            backgroundImage: _pickedImage != null
                                ? FileImage(_pickedImage!) as ImageProvider
                                : (img != null && img.isNotEmpty
                                      ? NetworkImage(img)
                                      : null),
                            child:
                                (_pickedImage == null &&
                                    (img == null || img.isEmpty))
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : 'A',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: _blue,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: _white, width: 1.5),
                          ),
                          child: _uploadingImage
                              ? const Padding(
                                  padding: EdgeInsets.all(2),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    color: _white,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_rounded,
                                  color: _white,
                                  size: 10,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: const TextStyle(fontSize: 11, color: _sub),
                            ),
                        ],
                      ),
                    ),
                    // Gear icon (decorative)
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _divide),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: _sub,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Page title ─────────────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 28, 16, 4),
                child: Text(
                  'Admin Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _text,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Text(
                  'Manage your fleet authority and system preferences.',
                  style: TextStyle(fontSize: 13, color: _sub, height: 1.4),
                ),
              ),

              // ── Section cards ───────────────────────────────────────────────
              _card(
                icon: Icons.person_rounded,
                title: 'Account',
                subtitle: 'Name, Email, Phone',
                onTap: () => Navigator.push(
                  context,
                  _route(
                    _AccountPage(
                      admin: _admin,
                      nameCtrl: _nameCtrl,
                      emailCtrl: _emailCtrl,
                      phoneCtrl: _phoneCtrl,
                      onSaved: (updated) => setState(() => _admin = updated),
                    ),
                  ),
                ),
              ),
              _card(
                icon: Icons.shield_rounded,
                title: 'Security',
                subtitle: 'Password, 2FA, Sessions',
                onTap: () =>
                    Navigator.push(context, _route(const _SecurityPage())),
              ),
              _card(
                icon: Icons.notifications_rounded,
                title: 'Notifications',
                subtitle: 'Email, Push, Dispatch Alerts',
                onTap: () =>
                    Navigator.push(context, _route(const _NotificationsPage())),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),

                child: Material(
                  color: _white,

                  borderRadius: BorderRadius.circular(16),

                  child: InkWell(
                    onTap: () {
                      // 🔥 action
                    },

                    borderRadius: BorderRadius.circular(16),

                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),

                      child: Row(
                        children: [
                          // 🔥 ICON
                          Container(
                            width: 48,
                            height: 48,

                            decoration: const BoxDecoration(
                              color: _blue,
                              shape: BoxShape.circle,
                            ),

                            child: const Icon(
                              Icons.restaurant_menu_rounded,
                              color: _white,
                              size: 24,
                            ),
                          ),

                          const SizedBox(width: 16),

                          // 🔥 TEXT
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,

                              children: [
                                Text(
                                  'Application Icon',

                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _text,
                                  ),
                                ),

                                SizedBox(height: 3),

                                Text(
                                  'Manage app branding and logo',

                                  style: TextStyle(fontSize: 13, color: _sub),
                                ),
                              ],
                            ),
                          ),

                          // 🔥 ARROW
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: _sub,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _card(
                icon: Icons.settings_rounded,
                title: 'System',
                subtitle: 'Language, Dark Mode, Units',
                onTap: () =>
                    Navigator.push(context, _route(const _SystemPage())),
              ),

              const SizedBox(height: 16),

              // ── System Health ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'System Health',
                              style: TextStyle(
                                color: _white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Last diagnostic: 42m ago',
                              style: TextStyle(
                                color: _white.withOpacity(0.55),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'ALL SYSTEMS OPERATIONAL',
                                  style: TextStyle(
                                    color: Color(0xFF4CAF50),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.bar_chart_rounded,
                        color: _white.withOpacity(0.12),
                        size: 72,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Termination label ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 8),
                child: Text(
                  'TERMINATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _sub,
                    letterSpacing: 1.3,
                  ),
                ),
              ),

              // ── Logout tile ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InkWell(
                  onTap: _logout,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _red.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: _red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: _white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Logout',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _red,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Securely end your session',
                                style: TextStyle(fontSize: 12, color: _sub),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: _red.withOpacity(0.7),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Section card (مثل الصورة بالضبط)
  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // دائرة زرقاء + أيقونة
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: _blue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _white, size: 24),
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
                          fontWeight: FontWeight.w700,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 13, color: _sub),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _sub, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PageRoute _route(Widget page) => MaterialPageRoute(builder: (_) => page);
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Account Page ──────────────────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════
class _AccountPage extends StatefulWidget {
  final Map<String, dynamic> admin;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final ValueChanged<Map<String, dynamic>> onSaved;

  const _AccountPage({
    required this.admin,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.onSaved,
  });

  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
  bool _saving = false;

  static const _bg = Color(0xFFF0F4F8);
  static const _white = Colors.white;
  static const _blue = Color(0xFF1B5BCE);
  static const _text = Color(0xFF0D1F4C);
  static const _sub = Color(0xFF6B7B99);
  static const _red = Color(0xFFE53935);
  static const _green = Color(0xFF2E7D32);

  Future<void> _save() async {
    if (widget.nameCtrl.text.trim().isEmpty) {
      _toast('Name cannot be empty', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final t = await AuthService().getToken();
      final r = await http.put(
        Uri.parse('${AppConfig.baseUrl}/users/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $t',
        },
        body: jsonEncode({
          'name': widget.nameCtrl.text.trim(),
          'email': widget.emailCtrl.text.trim(),
          'phone': widget.phoneCtrl.text.trim(),
        }),
      );
      if (r.statusCode == 200) {
        final updated = jsonDecode(r.body)['user'] ?? widget.admin;
        widget.onSaved(updated);
        _toast('Profile saved');
      } else {
        _toast('Failed to save', error: true);
      }
    } catch (_) {
      _toast('Error saving', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _red : _green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(
      backgroundColor: _white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _text,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Account',
        style: TextStyle(
          color: _text,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _inputField(widget.nameCtrl, 'Full Name', Icons.person_rounded),
          const SizedBox(height: 12),
          _inputField(
            widget.emailCtrl,
            'Email',
            Icons.email_rounded,
            type: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _inputField(
            widget.phoneCtrl,
            'Phone',
            Icons.phone_rounded,
            type: TextInputType.phone,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text(_saving ? 'Saving...' : 'Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: _white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _inputField(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? type,
  }) {
    return TextField(
      controller: c,
      keyboardType: type,
      style: const TextStyle(color: _text, fontSize: 14),
      cursorColor: _blue,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _sub, fontSize: 13),
        prefixIcon: Icon(icon, color: _blue, size: 20),
        filled: true,
        fillColor: _white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEAEEF5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Security Page ─────────────────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════
class _SecurityPage extends StatefulWidget {
  const _SecurityPage();

  @override
  State<_SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<_SecurityPage> {
  final _curCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _conCtrl = TextEditingController();

  bool _showCur = false, _showNew = false, _showCon = false;
  bool _saving = false;
  bool _twoFa = false;

  static const _bg = Color(0xFFF0F4F8);
  static const _white = Colors.white;
  static const _blue = Color(0xFF1B5BCE);
  static const _text = Color(0xFF0D1F4C);
  static const _sub = Color(0xFF6B7B99);
  static const _red = Color(0xFFE53935);
  static const _green = Color(0xFF2E7D32);

  @override
  void dispose() {
    _curCtrl.dispose();
    _newCtrl.dispose();
    _conCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePw() async {
    if (_curCtrl.text.isEmpty ||
        _newCtrl.text.isEmpty ||
        _conCtrl.text.isEmpty) {
      _toast('Fill all fields', error: true);
      return;
    }
    if (_newCtrl.text != _conCtrl.text) {
      _toast('Passwords do not match', error: true);
      return;
    }
    if (_newCtrl.text.length < 6) {
      _toast('Minimum 6 characters', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final t = await AuthService().getToken();
      final r = await http.post(
        Uri.parse('${AppConfig.baseUrl}/users/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $t',
        },
        body: jsonEncode({
          'currentPassword': _curCtrl.text,
          'newPassword': _newCtrl.text,
        }),
      );
      if (r.statusCode == 200) {
        _curCtrl.clear();
        _newCtrl.clear();
        _conCtrl.clear();
        _toast('Password changed');
      } else {
        final e = jsonDecode(r.body);
        _toast(e['message'] ?? 'Incorrect password', error: true);
      }
    } catch (_) {
      _toast('Error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _red : _green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(
      backgroundColor: _white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _text,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Security',
        style: TextStyle(
          color: _text,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Change Password card
          Container(
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEAEEF5)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Change Password',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _text,
                  ),
                ),
                const SizedBox(height: 14),
                _pwField(
                  _curCtrl,
                  'Current Password',
                  _showCur,
                  () => setState(() => _showCur = !_showCur),
                ),
                const SizedBox(height: 10),
                _pwField(
                  _newCtrl,
                  'New Password',
                  _showNew,
                  () => setState(() => _showNew = !_showNew),
                ),
                const SizedBox(height: 10),
                _pwField(
                  _conCtrl,
                  'Confirm Password',
                  _showCon,
                  () => setState(() => _showCon = !_showCon),
                ),
                const SizedBox(height: 14),
                // hint
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: _blue),
                      SizedBox(width: 8),
                      Text(
                        'Minimum 6 characters required',
                        style: TextStyle(fontSize: 11, color: _blue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _changePw,
                    icon: const Icon(Icons.security_rounded, size: 18),
                    label: Text(_saving ? 'Updating...' : 'Update Password'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: _white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 2FA card
          Container(
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEAEEF5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: _blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '2-Factor Authentication',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _text,
                    ),
                  ),
                ),
                Switch(
                  value: _twoFa,
                  onChanged: (v) => setState(() => _twoFa = v),
                  activeThumbColor: _blue,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pwField(
    TextEditingController c,
    String label,
    bool show,
    VoidCallback toggle,
  ) {
    return TextField(
      controller: c,
      obscureText: !show,
      style: const TextStyle(color: _text, fontSize: 14),
      cursorColor: _blue,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _sub, fontSize: 13),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: _blue,
          size: 20,
        ),
        suffixIcon: IconButton(
          onPressed: toggle,
          icon: Icon(
            show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: _sub,
            size: 20,
          ),
        ),
        filled: true,
        fillColor: const Color(0xFFF0F4F8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEAEEF5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Notifications Page ────────────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════
class _NotificationsPage extends StatefulWidget {
  const _NotificationsPage();

  @override
  State<_NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<_NotificationsPage> {
  bool _email = true,
      _push = true,
      _orders = true,
      _chef = true,
      _reports = true;

  static const _bg = Color(0xFFF0F4F8);
  static const _white = Colors.white;
  static const _blue = Color(0xFF1B5BCE);
  static const _text = Color(0xFF0D1F4C);
  static const _sub = Color(0xFF6B7B99);
  static const _divide = Color(0xFFEAEEF5);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(
      backgroundColor: _white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _text,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Notifications',
        style: TextStyle(
          color: _text,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _divide),
        ),
        child: Column(
          children: [
            _row(
              Icons.email_rounded,
              'Email Notifications',
              'Alerts via email',
              _email,
              (v) => setState(() => _email = v),
            ),
            _divider(),
            _row(
              Icons.notifications_active_rounded,
              'Push Notifications',
              'Instant device alerts',
              _push,
              (v) => setState(() => _push = v),
            ),
            _divider(),
            _row(
              Icons.shopping_cart_rounded,
              'Order Alerts',
              'New and updated orders',
              _orders,
              (v) => setState(() => _orders = v),
            ),
            _divider(),
            _row(
              Icons.restaurant_rounded,
              'Chef Requests',
              'Chef applications',
              _chef,
              (v) => setState(() => _chef = v),
            ),
            _divider(),
            _row(
              Icons.bar_chart_rounded,
              'Report Notifications',
              'Daily report digest',
              _reports,
              (v) => setState(() => _reports = v),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _row(
    IconData icon,
    String label,
    String sub,
    bool val,
    ValueChanged<bool> onChange,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: val ? const Color(0xFFE8F0FE) : const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: val ? _blue : _sub),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _text,
                  ),
                ),
                Text(sub, style: const TextStyle(fontSize: 11, color: _sub)),
              ],
            ),
          ),
          Switch(
            value: val,
            onChanged: onChange,
            activeThumbColor: _blue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Divider(height: 1, color: const Color(0xFFEAEEF5)),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// ── System Page ───────────────────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════
class _SystemPage extends StatelessWidget {
  const _SystemPage();

  static const _bg = Color(0xFFF0F4F8);
  static const _white = Colors.white;
  static const _blue = Color(0xFF1B5BCE);
  static const _text = Color(0xFF0D1F4C);
  static const _sub = Color(0xFF6B7B99);
  static const _divide = Color(0xFFEAEEF5);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(
      backgroundColor: _white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: _text,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'System',
        style: TextStyle(
          color: _text,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _divide),
            ),
            child: Column(
              children: [
                _pref(context, Icons.language_rounded, 'Language', 'English'),
                Divider(height: 1, indent: 16, endIndent: 16, color: _divide),
                _pref(
                  context,
                  Icons.dark_mode_rounded,
                  'App Theme',
                  'Light Mode',
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: _divide),
                _pref(
                  context,
                  Icons.access_time_rounded,
                  'Timezone',
                  'UTC-5 (EST)',
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: _divide),
                _pref(
                  context,
                  Icons.date_range_rounded,
                  'Date Format',
                  'MM/DD/YYYY',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 15, color: _blue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'App Version: 1.0.0  •  Last updated: Mar 31, 2026',
                    style: TextStyle(fontSize: 11, color: _blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _pref(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: _blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _text,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: _blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: _sub, size: 18),
          ],
        ),
      ),
    );
  }
}
