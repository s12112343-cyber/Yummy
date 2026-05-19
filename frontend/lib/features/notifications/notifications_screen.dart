import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';

class _NotificationItem {
  final String id;
  final String type;
  final String title;
  final String body;
  final String actorName;
  final String actorImageUrl;
  final String postId;
  final bool isRead;
  final DateTime createdAt;

  const _NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.actorName,
    required this.actorImageUrl,
    required this.postId,
    required this.isRead,
    required this.createdAt,
  });

  factory _NotificationItem.fromJson(Map<String, dynamic> json) {
    return _NotificationItem(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      actorName: (json['actorName'] ?? 'User').toString(),
      actorImageUrl: (json['actorImageUrl'] ?? '').toString(),
      postId: (json['postId'] ?? '').toString(),
      isRead: json['isRead'] == true,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final AuthService _authService = AuthService();
  final DateFormat _dateFormat = DateFormat('MMM d, h:mm a');

  bool _isLoading = true;
  bool _isRefreshing = false;
  int _unreadCount = 0;
  List<_NotificationItem> _items = const [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  String _normalizeImageUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final origin = AppConfig.baseUrl.replaceFirst('/api', '');
    return trimmed.startsWith('/') ? '$origin$trimmed' : '$origin/$trimmed';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.mode_comment_rounded;
      case 'follow':
        return Icons.person_add_alt_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'like':
        return const Color(0xFFE65B7A);
      case 'comment':
        return const Color(0xFF4F8DF7);
      case 'follow':
        return const Color(0xFF2DBE7A);
      default:
        return AppColors.deepBlue;
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final response = await _authService.getNotifications();
    if (!mounted) return;

    if (response['error'] == true) {
      setState(() {
        _errorMessage = (response['message'] ?? 'Failed to load notifications')
            .toString();
        _items = const [];
        _unreadCount = 0;
        _isLoading = false;
        _isRefreshing = false;
      });
      return;
    }

    final rawList = response['notifications'] as List<dynamic>? ?? const [];
    setState(() {
      _items = rawList
          .whereType<Map>()
          .map(
            (item) =>
                _NotificationItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
      _unreadCount = (response['unreadCount'] as num?)?.toInt() ?? 0;
      _isLoading = false;
      _isRefreshing = false;
    });
  }

  Future<void> _markRead(_NotificationItem item) async {
    if (item.isRead || item.id.isEmpty) {
      return;
    }

    final response = await _authService.markNotificationAsRead(
      notificationId: item.id,
    );
    if (!mounted) return;

    if (response['error'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (response['message'] ?? 'Failed to update notification').toString(),
          ),
        ),
      );
      return;
    }

    setState(() {
      _items = _items
          .map(
            (current) => current.id == item.id
                ? _NotificationItem(
                    id: current.id,
                    type: current.type,
                    title: current.title,
                    body: current.body,
                    actorName: current.actorName,
                    actorImageUrl: current.actorImageUrl,
                    postId: current.postId,
                    isRead: true,
                    createdAt: current.createdAt,
                  )
                : current,
          )
          .toList();
      if (_unreadCount > 0) {
        _unreadCount -= 1;
      }
    });
  }

  Future<void> _markAllRead() async {
    if (_items.isEmpty || _unreadCount == 0) {
      return;
    }

    final response = await _authService.markAllNotificationsAsRead();
    if (!mounted) return;

    if (response['error'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (response['message'] ?? 'Failed to update notifications')
                .toString(),
          ),
        ),
      );
      return;
    }

    setState(() {
      _items = _items
          .map(
            (item) => _NotificationItem(
              id: item.id,
              type: item.type,
              title: item.title,
              body: item.body,
              actorName: item.actorName,
              actorImageUrl: item.actorImageUrl,
              postId: item.postId,
              isRead: true,
              createdAt: item.createdAt,
            ),
          )
          .toList();
      _unreadCount = 0;
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F6FC),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 38,
                color: AppColors.blueGray,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Likes, comments, and new followers will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.blueGray, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(_NotificationItem item) {
    final avatarUrl = _normalizeImageUrl(item.actorImageUrl);
    final color = _colorForType(item.type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: item.isRead ? Colors.white : const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isRead
              ? const Color(0xFFE4EDF7)
              : color.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF123456).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _markRead(item),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.12),
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Icon(_iconForType(item.type), color: color, size: 22)
                  : null,
            ),
            if (!item.isRead)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ),
            if (item.postId.isNotEmpty)
              Icon(
                Icons.arrow_outward_rounded,
                size: 16,
                color: AppColors.blueGray.withOpacity(0.7),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.body,
                style: const TextStyle(color: AppColors.blueGray, height: 1.35),
              ),
              const SizedBox(height: 8),
              Text(
                _dateFormat.format(item.createdAt),
                style: const TextStyle(
                  color: AppColors.blueGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FD),
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.dark,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadNotifications(refresh: true),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F2F57), Color(0xFF2C74D9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F2F57).withOpacity(0.2),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.notifications_active_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Unread: $_unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Likes, comments, and follows land here.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_isRefreshing)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    ),
                  if (_errorMessage != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ),
                    ),
                  if (_items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildNotificationCard(_items[index]),
                          childCount: _items.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
