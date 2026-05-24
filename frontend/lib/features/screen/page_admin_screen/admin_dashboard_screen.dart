import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/services/auth_service.dart';
import 'package:frontend/features/auth/login_screen.dart';
import 'admin_stats_page.dart';
import 'admin_users_page.dart';
import 'admin_chefs_page.dart';
import 'admin_banners_page.dart';
import 'admin_orders_page.dart';
import 'admin_feedback_page.dart';
import 'admin_reviews_page.dart';
import 'admin_reports_page.dart';
import 'admin_settings_page.dart';
import 'admin_application_icon.dart';
import 'admin_notification_requests_page.dart';

// ── Palette (matches screenshot) ──────────────────────────────────────────────
const _kBg = Color(0xFFF0F4F8);
const _kWhite = Colors.white;
const _kNavy = Color(0xFF0D1F4C);
const _kBlue = Color(0xFF1B5BCE);
const _kBlueBtn = Color(0xFF1565C0);
const _kBlueSft = Color(0xFFE8F0FE);
const _kText = Color(0xFF0D1F4C);
const _kSub = Color(0xFF6B7B99);
const _kDivide = Color(0xFFEAEEF5);
const _kRed = Color(0xFFE53935);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _unreadCount = 0;
  int _pendingOrders = 0;
  int _reviewsCount = 0;
  int _feedbackCount = 0;
  int _feedbackUnread = 0;
  Map<String, dynamic> _admin = {};
  bool _loadingAdmin = true;
  int _previousIndex = 0;
  int _pendingBannerRequests = 0;

  List<Map<String, dynamic>> _notifications = [];
  late AnimationController _bellCtrl;

  late List<Widget> _pages;
  static const _titles = [
    'Dashboard',
    'Users',
    'Chefs',
    'Banners',
    'Orders',
    'Reviews',
    'Reports',
    'Feedback',
    'Application icon',
    'Settings',
  ];
  static const _icons = [
    Icons.dashboard_rounded,
    Icons.people_rounded,
    Icons.restaurant_rounded,
    Icons.campaign_rounded,
    Icons.shopping_cart_rounded,
    Icons.star_rounded,
    Icons.bar_chart_rounded,
    Icons.feedback_rounded,
    Icons.apps_rounded,
    Icons.settings_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _bellCtrl = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _loadAdmin();
    _loadCounts();
    _pages = [
      const AdminStatsPage(),
      const AdminUsersPage(),
      const AdminChefsPage(),
      const AdminBannersPage(),
      const AdminOrdersPage(),
      const AdminReviewsPage(),
      const AdminReportsPage(),

      AdminFeedbackPage(
        onBack: () {
          setState(() => _selectedIndex = _previousIndex);
        },
      ),

      const AdminApplicationIconPage(),

      const AdminSettingsPage(),
    ];
  }

  @override
  void dispose() {
    _bellCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdmin() async {
    try {
      final t = await AuthService().getToken();
      if (t == null) {
        setState(() => _loadingAdmin = false);
        return;
      }
      final r = await http.get(
        Uri.parse('${AppConfig.baseUrl}/users/profile'),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (r.statusCode == 200 && mounted) {
        setState(() {
          _admin = jsonDecode(r.body)['user'] ?? {};
          _loadingAdmin = false;
        });
      } else if (mounted)
        setState(() => _loadingAdmin = false);
    } catch (_) {
      if (mounted) setState(() => _loadingAdmin = false);
    }
  }

  Future<void> _loadCounts() async {
    try {
      final t = await AuthService().getToken();
      if (t == null) return;

      final h = {'Authorization': 'Bearer $t'};

      int pendingOrders = 0;
      int reviewsCount = 0;
      int feedbackUnread = 0;
      int bannerPending = 0;

      final List<Map<String, dynamic>> newNotifications = [];

      // 🔥 ORDERS
      try {
        final r = await http.get(
          Uri.parse('${AppConfig.baseUrl}/orders/all'),
          headers: h,
        );

        if (r.statusCode == 200) {
          final orders = (jsonDecode(r.body)['orders'] ?? []) as List;

          final pending = orders
              .where((o) => o['status'] == 'pending')
              .toList();
          pendingOrders = pending.length;

          for (var order in pending) {
            newNotifications.add({
              'id': order['_id'],
              'type': 'order',
              'title': 'New Order',
              'sub': 'New pending order received',
              'time': order['createdAt'] ?? order['orderTime'],
              'icon': Icons.shopping_cart_rounded,
              'color': const Color(0xFF854F0B),
              'pageIndex': 4,
            });
          }
        }
      } catch (e) {
        print('ORDERS ERROR => $e');
      }

      // 🔥 REVIEWS
      try {
        final r = await http.get(
          Uri.parse('${AppConfig.baseUrl}/reviews/admin/all'),
          headers: h,
        );

        if (r.statusCode == 200) {
          final decoded = jsonDecode(r.body);
          List reviews = [];

          if (decoded is Map) {
            reviews = decoded['data'] ?? [];
          }

          reviewsCount = reviews.length;

          for (var review in reviews) {
            newNotifications.add({
              'id': review['_id'],

              'type': 'review',
              'title': 'New Review',
              'sub': review['comment'] ?? 'New review added',
              'time': review['createdAt'] ?? review['date'],
              'icon': Icons.star_rounded,
              'color': const Color(0xFFBA7517),
              'pageIndex': 5,
            });
          }
        }
      } catch (e) {
        print('REVIEWS ERROR => $e');
      }

      // 🔥 FEEDBACK
      try {
        final r = await http.get(
          Uri.parse('${AppConfig.baseUrl}/feedback/admin/all'),
          headers: h,
        );

        if (r.statusCode == 200) {
          final decoded = jsonDecode(r.body);
          List feedbacks = [];

          if (decoded is Map) {
            feedbacks = decoded['feedbacks'] ?? [];
          }

          final unreadFeedbacks = feedbacks
              .where((f) => (f['read'] ?? false) != true)
              .toList();

          feedbackUnread = unreadFeedbacks.length;

          for (var feedback in unreadFeedbacks) {
            newNotifications.add({
              'id': feedback['_id'],

              'type': 'feedback',
              'title': 'New Feedback',
              'sub': feedback['message'] ?? 'Customer sent feedback',
              'time': feedback['createdAt'],
              'icon': Icons.feedback_rounded,
              'color': Colors.purple,
              'pageIndex': 7,
            });
          }
        }
      } catch (e) {
        print('FEEDBACK ERROR => $e');
      }

      // 🔥 BANNER REQUESTS
      try {
        final r = await http.get(
          Uri.parse('${AppConfig.baseUrl}/banner-requests/admin'),
          headers: h,
        );

        if (r.statusCode == 200) {
          final decoded = jsonDecode(r.body);
          final requests = decoded['requests'] ?? [];

          final pendingRequests = requests
              .where((req) => req['status'] == 'pending')
              .toList();

          bannerPending = pendingRequests.length;

          for (var req in pendingRequests) {
            newNotifications.add({
              'type': 'banner_request',
              'title': 'New Banner Request',
              'sub':
                  '${req['chefName'] ?? req['chef']?['name'] ?? 'Chef'} sent a banner request',
              'time': req['createdAt'],
              'icon': Icons.campaign_rounded,
              'color': Colors.orange,
              'pageIndex': 3,
            });
          }
        }
      } catch (e) {
        print('BANNER REQUEST ERROR => $e');
      }
      //
      // 🔥 NOTIFICATION REQUESTS
      //
      try {
        final r = await http.get(
          Uri.parse('${AppConfig.baseUrl}/notification-requests/admin'),

          headers: h,
        );

        if (r.statusCode == 200) {
          final decoded = jsonDecode(r.body);

          final requests = decoded['requests'] ?? [];

          final pending = requests
              .where((req) => req['status'] == 'pending')
              .toList();

          for (var req in pending) {
            newNotifications.add({
              'id': req['_id'],

              'type': 'notification_request',

              'title': 'Notification Request',

              'sub': '${req['chefName'] ?? 'Chef'} wants to send notification',

              'time': req['createdAt'],

              'icon': Icons.notifications_active,

              'color': Colors.purple,
            });
          }
        }
      } catch (e) {
        print('NOTIFICATION REQUEST ERROR => $e');
      }
      // 🔥 الأحدث فوق
      newNotifications.sort((a, b) {
        final at =
            DateTime.tryParse(a['time']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bt =
            DateTime.tryParse(b['time']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return bt.compareTo(at);
      });

      if (!mounted) return;

      setState(() {
        _pendingOrders = pendingOrders;
        _reviewsCount = reviewsCount;
        _feedbackUnread = feedbackUnread;
        _pendingBannerRequests = bannerPending;

        _notifications = newNotifications;

        _unreadCount =
            pendingOrders + reviewsCount + feedbackUnread + bannerPending;
      });
    } catch (e) {
      print('LOAD COUNTS ERROR => $e');
    }
  }

  void _showNotifications() {
    _bellCtrl.forward(from: 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NotifSheet(
        unreadCount: _unreadCount,
        notifications: _notifications,

        onNotificationRead: () {
          setState(() {
            if (_unreadCount > 0) {
              _unreadCount--;
            }
          });
        },

        onOpenPage: (index) {
          Navigator.pop(context);

          setState(() {
            _previousIndex = _selectedIndex;
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Future<void> _doLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w700, color: _kText),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: _kSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _kSub)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: _kWhite,
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (r) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 حماية من أي index غلط
    if (_selectedIndex >= _pages.length) {
      _selectedIndex = 0;
    }

    final name = _admin['name'] ?? 'Admin';

    final img = _admin['profileImage'];

    return Scaffold(
      backgroundColor: _kBg,

      appBar: _appBar(name, img),

      drawer: _drawer(name, img),

      body: IndexedStack(index: _selectedIndex, children: _pages),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  AppBar _appBar(String name, String? img) => AppBar(
    backgroundColor: _kNavy,
    elevation: 0,
    leadingWidth: 60,
    leading: Builder(
      builder: (ctx) => GestureDetector(
        onTap: () => Scaffold.of(ctx).openDrawer(),
        child: Center(
          child: _Avatar(
            name: name,
            imageUrl: img,
            radius: 18,
            border: true,
            loadingAdmin: _loadingAdmin,
          ),
        ),
      ),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: _kWhite,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    ),
    actions: [
      Stack(
        children: [
          AnimatedBuilder(
            animation: _bellCtrl,
            builder: (_, child) => Transform.rotate(
              angle: _bellCtrl.value < 0.5
                  ? _bellCtrl.value * 0.3
                  : (1 - _bellCtrl.value) * -0.3,
              child: child,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.notifications_rounded,
                color: _kWhite,
                size: 24,
              ),
              onPressed: _showNotifications,
            ),
          ),
          if (_unreadCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: _kRed,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    color: _kWhite,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(width: 6),
    ],
  );

  // ── Drawer ─────────────────────────────────────────────────────────────────
  Widget _drawer(String name, String? img) => Drawer(
    backgroundColor: _kNavy,
    child: SafeArea(
      child: Column(
        children: [
          // Profile
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _kWhite.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: _Avatar(name: name, imageUrl: img, radius: 40),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    color: _kWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 12),
                _Badge(
                  label: name.toUpperCase(),
                  icon: Icons.admin_panel_settings_rounded,
                  color: const Color(0xFF80B0FF),
                  bg: Color(0x40346EB5),
                ),
                if (_unreadCount > 0) ...[
                  const SizedBox(height: 8),

                  _Badge(
                    label: '${_unreadCount} Notifications',

                    icon: Icons.notifications_active_rounded,

                    color: Colors.orange,

                    bg: Colors.orange.withOpacity(0.18),
                  ),
                ],
              ],
            ),
          ),

          Divider(color: _kWhite.withOpacity(0.08), height: 1),
          const SizedBox(height: 6),

          // Nav
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              itemCount: _titles.length,
              itemBuilder: (ctx, i) => _NavItem(
                icon: _icons[i],
                label: _titles[i],
                isSelected: _selectedIndex == i,
                badge: _titles[i] == 'Orders'
                    ? _pendingOrders
                    : _titles[i] == 'Reviews'
                    ? _reviewsCount
                    : _titles[i] == 'Feedback'
                    ? _feedbackUnread
                    : _titles[i] == 'Banners'
                    ? _pendingBannerRequests
                    : 0,
                onTap: () {
                  if (i >= _pages.length) {
                    return;
                  }

                  setState(() {
                    _previousIndex = _selectedIndex;

                    _selectedIndex = i;
                  });

                  Navigator.pop(ctx);
                },
              ),
            ),
          ),

          // Logout
          Builder(
            builder: (ctx) => Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
              child: _TapScale(
                onTap: () {
                  Navigator.pop(ctx);
                  _doLogout();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _kWhite.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _kWhite.withOpacity(0.12)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: Color(0xFF8FA6CC),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: Color(0xFF8FA6CC),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Drawer nav item ────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final int badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) => _TapScale(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? _kWhite.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? const Border(left: BorderSide(color: Color(0xFF60B4FF), width: 3))
            : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? _kWhite : const Color(0xFF8FA6CC),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? _kWhite : const Color(0xFF8FA6CC),
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (badge > 0)
            (label == 'Feedback'
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: _kRed,
                      shape: BoxShape.circle,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _kRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        color: _kWhite,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )),
        ],
      ),
    ),
  );
}

// ── Reusable Avatar ────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double radius;
  final bool border;
  final bool loadingAdmin;

  const _Avatar({
    required this.name,
    this.imageUrl,
    required this.radius,
    this.border = false,
    this.loadingAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar;
    if (loadingAdmin) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE0F1FF),
        child: const CircularProgressIndicator(strokeWidth: 2, color: _kBlue),
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE0F1FF),
        backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
            ? NetworkImage(imageUrl!)
            : null,
        child: imageUrl == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'A',
                style: TextStyle(
                  fontSize: radius * 0.55,
                  fontWeight: FontWeight.w700,
                  color: _kBlue,
                ),
              )
            : null,
      );
    }
    if (!border) return avatar;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _kWhite.withOpacity(0.5), width: 1.5),
      ),
      child: avatar,
    );
  }
}

// ── Small badge pill ──────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;

  const _Badge({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

// ── Notification sheet ─────────────────────────────────────────────────────────
class _NotifSheet extends StatefulWidget {
  final int unreadCount;
  final List<Map<String, dynamic>> notifications;
  final Function(int index) onOpenPage;
  final VoidCallback onNotificationRead;
  const _NotifSheet({
    required this.unreadCount,
    required this.notifications,
    required this.onOpenPage,
    required this.onNotificationRead,
  });

  @override
  State<_NotifSheet> createState() => _NotifSheetState();
}

class _NotifSheetState extends State<_NotifSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _timeAgo(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return '';

    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';

    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _kDivide,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kText,
                    ),
                  ),
                  const Spacer(),
                  if (widget.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _kBlueSft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.unreadCount} new',
                        style: const TextStyle(
                          color: _kBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _kBlueSft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: _kBlue,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: _kDivide),

            Expanded(
              child: widget.notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: _kBlueSft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.notifications_off_rounded,
                              color: _kBlue,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No notifications',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _kText,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "You're all caught up!",
                            style: TextStyle(color: _kSub, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : AnimatedBuilder(
                      animation: _ctrl,
                      builder: (_, _) => ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: widget.notifications.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final n = widget.notifications[i];

                          final color = n['color'] as Color;
                          final startTime = (i * 0.1).clamp(0.0, 0.7);

                          final anim = CurvedAnimation(
                            parent: _ctrl,
                            curve: Interval(
                              startTime,
                              (startTime + 0.4).clamp(0.0, 1.0),
                              curve: Curves.easeOutCubic,
                            ),
                          );

                          return FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.15, 0),
                                end: Offset.zero,
                              ).animate(anim),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  final id = n['id'];

                                  final type = n['type'];

                                  final pageIndex = n['pageIndex'];

                                  String? url;

                                  /// REVIEW
                                  if (type == 'review') {
                                    url =
                                        '${AppConfig.baseUrl}/reviews/read/$id';
                                  }

                                  /// FEEDBACK
                                  if (type == 'feedback') {
                                    url =
                                        '${AppConfig.baseUrl}/feedback/read/$id';
                                  }

                                  /// BANNER REQUEST
                                  if (type == 'banner_request') {
                                    url =
                                        '${AppConfig.baseUrl}/banner-requests/read/$id';
                                  }

                                  /// 🔥 notification request page
                                  if (type == 'notification_request') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const AdminNotificationRequestsPage(),
                                      ),
                                    );

                                    return;
                                  }

                                  /// 🔥 افتح الصفحة العادية
                                  if (pageIndex is int) {
                                    widget.onOpenPage(pageIndex);
                                  }
                                  try {
                                    if (url != null) {
                                      final prefs =
                                          await SharedPreferences.getInstance();

                                      final token = prefs.getString('token');

                                      await http.patch(
                                        Uri.parse(url),
                                        headers: {
                                          'Authorization': 'Bearer $token',
                                        },
                                      );
                                    }
                                  } catch (e) {
                                    print('READ NOTIFICATION ERROR => $e');
                                  }

                                  /// 🔥 حذف الإشعار محلي
                                  setState(() {
                                    widget.notifications.removeAt(i);
                                  });

                                  /// 🔥 نقص العدد
                                  widget.onNotificationRead();

                                  /// 🔥 افتح الصفحة
                                  if (pageIndex is int) {
                                    widget.onOpenPage(pageIndex);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _kWhite,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _kDivide),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(9),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Icon(
                                          n['icon'] as IconData,
                                          color: color,
                                          size: 18,
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              n['title']?.toString() ?? '',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: _kText,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              n['sub']?.toString() ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: _kSub,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Text(
                                        _timeAgo(n['time']),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: _kSub,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── TapScale helper ────────────────────────────────────────────────────────────
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TapScale({required this.child, required this.onTap});

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ctrl.forward(),
    onTapUp: (_) {
      _ctrl.reverse();
      widget.onTap();
    },
    onTapCancel: () => _ctrl.reverse(),
    child: ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: 0.95,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
      child: widget.child,
    ),
  );
}
