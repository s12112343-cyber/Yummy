import 'package:flutter/material.dart';

import '../core/services/auth_service.dart';
import '../core/theme/app_colors.dart';
import '../features/profile/user_profile_screen.dart';
import '../features/profile/user_conversations_screen.dart';
import '../features/notifications/notifications_screen.dart';

class AppSidebar extends StatefulWidget {
  final bool closeAfterSelect;
  final Widget? filterSection;
  final Widget? hiddenUsersSection;
  final bool showProfileSection;

  const AppSidebar({
    super.key,
    this.closeAfterSelect = false,
    this.filterSection,
    this.hiddenUsersSection,
    this.showProfileSection = true,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  final AuthService _auth = AuthService();
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    final res = await _auth.getNotifications();
    if (!mounted) return;
    if (res['error'] == true) return;
    setState(() {
      _unread = (res['unreadCount'] as num?)?.toInt() ?? 0;
    });
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.blueGray,
        ),
      ),
    );
  }

  Widget _actionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = AppColors.deepBlue,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE1EBF7)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2B3440),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.blueGray,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.blueGray,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: const Color(0xFFF7FAFF),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          child: ListView(
            children: [
              if (widget.closeAfterSelect)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    splashRadius: 20,
                    color: AppColors.blueGray,
                  ),
                ),
              if (widget.showProfileSection) ...[
                _sectionTitle('Profile'),
                const SizedBox(height: 8),
                _actionTile(
                  context: context,
                  icon: Icons.person_outline,
                  title: 'My Profile',
                  subtitle: 'Open your profile page',
                  onTap: () {
                    if (widget.closeAfterSelect) Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserProfileScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
              ],
              _sectionTitle('Messages'),
              const SizedBox(height: 8),
              _actionTile(
                context: context,
                icon: Icons.forum_rounded,
                title: 'My Chats',
                subtitle: 'Open your conversations list',
                onTap: () {
                  if (widget.closeAfterSelect) Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UserConversationsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              if (widget.filterSection != null) widget.filterSection!,
              const SizedBox(height: 10),
              if (widget.filterSection != null) const SizedBox(height: 14),
              _sectionTitle('Notifications'),
              const SizedBox(height: 8),
              // Notifications tile with unread badge
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    if (widget.closeAfterSelect) Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE1EBF7)),
                    ),
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F7FD),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.notifications_none_rounded,
                                color: AppColors.deepBlue,
                                size: 19,
                              ),
                            ),
                            if (_unread > 0)
                              Positioned(
                                top: -3,
                                right: -3,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2B3440),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Open your inbox',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.blueGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.blueGray,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _sectionTitle('Privacy'),
              const SizedBox(height: 8),
              if (widget.hiddenUsersSection != null) widget.hiddenUsersSection!,
            ],
          ),
        ),
      ),
    );
  }
}
