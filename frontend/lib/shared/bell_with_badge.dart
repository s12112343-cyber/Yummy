import 'package:flutter/material.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_colors.dart';
import '../features/notifications/notifications_screen.dart';

class BellWithBadge extends StatefulWidget {
  final double size;
  const BellWithBadge({super.key, this.size = 24});

  @override
  State<BellWithBadge> createState() => _BellWithBadgeState();
}

class _BellWithBadgeState extends State<BellWithBadge> {
  final AuthService _auth = AuthService();
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await _auth.getNotifications();
    if (!mounted) return;
    if (res['error'] == true) return;
    setState(() {
      _unread = (res['unreadCount'] as num?)?.toInt() ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          icon: Icon(
            Icons.notifications_none_rounded,
            size: widget.size,
            color: AppColors.deepBlue,
          ),
        ),
        if (_unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
