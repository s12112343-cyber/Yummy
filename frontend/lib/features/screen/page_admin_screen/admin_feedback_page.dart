import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/services/auth_service.dart';

class AdminFeedbackPage extends StatefulWidget {
  final VoidCallback? onBack;

  const AdminFeedbackPage({super.key, this.onBack});

  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  static const _bg = Color(0xFFF0F4F8);
  static const _white = Colors.white;
  static const _blue = Color(0xFF1B5BCE);
  static const _navy = Color(0xFF0D1F4C);
  static const _text = Color(0xFF0D1F4C);
  static const _sub = Color(0xFF6B7B99);
  static const _divide = Color(0xFFEAEEF5);
  static const _red = Color(0xFFE53935);

  bool _loading = true;
  bool _error = false;
  String _errorMessage = '';
  List<dynamic> _feedbacks = [];
  int _feedbackCount = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    setState(() {
      _loading = true;
      _error = false;
      _errorMessage = '';
    });

    try {
      final token = await AuthService().getToken();
      if (token == null || token.trim().isEmpty) {
        throw Exception('No admin token found');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/feedback/admin/all'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final feedbacks = decoded is Map ? (decoded['feedbacks'] ?? []) : [];
        setState(() {
          _feedbacks = feedbacks is List ? feedbacks : [];
          _feedbackCount = _feedbacks.length;
          _unreadCount = _feedbacks
              .where((f) => (f['read'] ?? false) != true)
              .length;
          _loading = false;
        });
      } else {
        final parsed = _parseMessage(response.body);
        setState(() {
          _error = true;
          _errorMessage = parsed.isNotEmpty
              ? parsed
              : 'Failed to load feedbacks (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = true;
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _deleteFeedback(String feedbackId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Delete feedback?',
          style: TextStyle(color: _text, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This action cannot be undone.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await AuthService().getToken();
      if (token == null || token.trim().isEmpty) {
        throw Exception('No admin token found');
      }

      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/feedback/admin/$feedbackId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _feedbacks.removeWhere(
            (item) => item['_id']?.toString() == feedbackId,
          );
          _feedbackCount = _feedbacks.length;
          _unreadCount = _feedbacks
              .where((f) => (f['read'] ?? false) != true)
              .length;
        });
      } else {
        return;
      }
    } catch (e) {
      return;
    }
  }

  Future<void> _markAsRead(String feedbackId, int index) async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.trim().isEmpty) {
        throw Exception('No admin token found');
      }

      final response = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/feedback/admin/mark-read/$feedbackId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          final item = Map<String, dynamic>.from(_feedbacks[index] as Map);
          item['read'] = true;
          _feedbacks[index] = item;
          _unreadCount = _feedbacks
              .where((f) => (f['read'] ?? false) != true)
              .length;
        });
      }
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    try {
      final token = await AuthService().getToken();
      if (token == null || token.trim().isEmpty)
        throw Exception('No admin token found');

      final response = await http.patch(
        Uri.parse('${AppConfig.baseUrl}/feedback/admin/mark-read-all'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          for (var i = 0; i < _feedbacks.length; i++) {
            final item = Map<String, dynamic>.from(_feedbacks[i] as Map);
            item['read'] = true;
            _feedbacks[i] = item;
          }
          _unreadCount = 0;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('All marked read')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _parseMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        return decoded['message'].toString();
      }
    } catch (_) {}
    return '';
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'F';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts[1].characters.first}'
        .toUpperCase();
  }

  String? _resolveAvatar(dynamic value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = Uri.tryParse(AppConfig.baseUrl);
    if (base == null) return raw;
    final authority = base.hasPort ? '${base.host}:${base.port}' : base.host;
    final origin = '${base.scheme}://$authority';
    if (raw.startsWith('/')) return '$origin$raw';
    return '$origin/$raw';
  }

  Widget _buildAvatar(Map<String, dynamic> item) {
    final avatar = _resolveAvatar(item['avatar']);
    final name = (item['name'] ?? 'Feedback').toString();
    final isRead = (item['read'] ?? false) == true;

    final avatarWidget = avatar != null
        ? CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE0F1FF),
            backgroundImage: NetworkImage(avatar),
            child: const SizedBox.shrink(),
          )
        : CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE0F1FF),
            child: Text(
              _initials(name),
              style: const TextStyle(color: _blue, fontWeight: FontWeight.w800),
            ),
          );

    // If not read, show a small red indicator dot
    if (!isRead) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          avatarWidget,
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _red,
                shape: BoxShape.circle,
                border: Border.all(color: _white, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    return avatarWidget;
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      return '$day/$month/$year';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _loading ? null : _markAllRead,
            child: const Text('Mark All Read', style: TextStyle(color: _blue)),
          ),
          IconButton(
            onPressed: _loading ? null : _loadFeedbacks,
            icon: const Icon(Icons.refresh_rounded, color: _blue),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _blue, strokeWidth: 2.5),
            )
          : _error
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: _red,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadFeedbacks,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: _white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadFeedbacks,
              color: _blue,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.all(16),
                itemCount: 1 + _feedbacks.length,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Header: two cards with total and unread counts
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4C9AFF), _blue],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$_feedbackCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4C9AFF),
                                    Color(0xFFBEE4FF),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Unread',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '$_unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
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

                  final item = Map<String, dynamic>.from(
                    _feedbacks[index - 1] as Map,
                  );
                  final feedbackId = (item['_id'] ?? '').toString();
                  final name = (item['name'] ?? 'User').toString();
                  final message = (item['message'] ?? '').toString();
                  final createdAt = _formatDate(item['createdAt']);

                  final isRead = (item['read'] ?? false) == true;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        if (feedbackId.isNotEmpty)
                          _markAsRead(feedbackId, index - 1);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _divide.withOpacity(0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildAvatar(item),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(
                                                color: _text,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          if (createdAt.isNotEmpty)
                                            Text(
                                              createdAt,
                                              style: const TextStyle(
                                                color: _sub,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        message,
                                        style: const TextStyle(
                                          color: _text,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: isRead
                                      ? null
                                      : () =>
                                            _markAsRead(feedbackId, index - 1),
                                  icon: Icon(
                                    isRead
                                        ? Icons.check_circle
                                        : Icons.check_circle_outline,
                                    color: isRead ? _blue : _sub,
                                  ),
                                  label: Text(
                                    isRead ? 'Read' : 'Mark read',
                                    style: TextStyle(
                                      color: isRead ? _blue : _sub,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: feedbackId.isEmpty
                                      ? null
                                      : () => _deleteFeedback(feedbackId),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Delete'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: _red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
