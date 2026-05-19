import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import 'chat_screen.dart';

class UserConversationsScreen extends StatefulWidget {
  const UserConversationsScreen({super.key});

  @override
  State<UserConversationsScreen> createState() =>
      _UserConversationsScreenState();
}

class _UserConversationsScreenState extends State<UserConversationsScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _errorMessage;
  String _currentUserId = '';
  String _searchQuery = '';
  List<Map<String, dynamic>> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final userId = await _authService.getUserId();
      final token = await _authService.getToken();

      if (userId.trim().isEmpty) {
        throw Exception('User not logged in');
      }
      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing auth token');
      }

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/chat/conversations/$userId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load conversations');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (data['conversations'] as List<dynamic>?) ?? [];

      if (!mounted) return;
      setState(() {
        _currentUserId = userId;
        _conversations = list
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _loading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';

    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isNotEmpty
          ? parts.first.substring(0, 1).toUpperCase()
          : 'U';
    }

    final first = parts.first.isNotEmpty ? parts.first.substring(0, 1) : 'U';
    final second = parts[1].isNotEmpty ? parts[1].substring(0, 1) : 'U';
    return '$first$second'.toUpperCase();
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';

    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    if (isToday) return '$hour:$minute';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  void _openChat(Map<String, dynamic> conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: conversation['peerId']?.toString() ?? '',
          peerName: conversation['peerName']?.toString() ?? 'User',
          peerAvatar: conversation['peerImageUrl']?.toString(),
        ),
      ),
    ).then((_) => _loadConversations());
  }

  List<Map<String, dynamic>> get _filteredConversations {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _conversations;

    return _conversations.where((item) {
      final name = item['peerName']?.toString().toLowerCase() ?? '';
      final last = item['lastMessage']?.toString().toLowerCase() ?? '';
      return name.contains(query) || last.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _filteredConversations;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.deepBlue,
          onRefresh: _loadConversations,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(
                        totalChats: _conversations.length,
                        currentUserId: _currentUserId,
                      ),
                      const SizedBox(height: 18),
                      _SearchBar(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _StateView(
                    icon: Icons.error_outline_rounded,
                    title: 'Something went wrong',
                    subtitle: _errorMessage!,
                    buttonText: 'Try again',
                    onPressed: _loadConversations,
                  ),
                )
              else if (conversations.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _StateView(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No conversations yet',
                    subtitle: _searchQuery.isEmpty
                        ? 'Start chatting with people from your food community.'
                        : 'No chats found for "$_searchQuery".',
                    buttonText: _searchQuery.isEmpty ? null : 'Clear search',
                    onPressed: _searchQuery.isEmpty
                        ? null
                        : () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: conversations.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = conversations[index];
                      final peerName = item['peerName']?.toString() ?? 'User';
                      final imageUrl = item['peerImageUrl']?.toString() ?? '';
                      final unreadCount = item['unreadCount'] is num
                          ? (item['unreadCount'] as num).toInt()
                          : int.tryParse(
                                item['unreadCount']?.toString() ?? '',
                              ) ??
                              0;

                      return _ConversationCard(
                        peerName: peerName,
                        peerImageUrl: imageUrl,
                        initials: _getInitials(peerName),
                        lastMessage: item['lastMessage']?.toString() ?? '',
                        date: _formatDate(item['lastMessageAt']),
                        unreadCount: unreadCount,
                        onTap: () => _openChat(item),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int totalChats;
  final String currentUserId;

  const _Header({
    required this.totalChats,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.deepBlue,
                AppColors.royalBlue,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepBlue.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.forum_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chats',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                totalChats == 0
                    ? 'Stay connected with your food community'
                    : '$totalChats conversation${totalChats == 1 ? '' : 's'} in your inbox',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.deepBlue,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final String peerName;
  final String peerImageUrl;
  final String initials;
  final String lastMessage;
  final String date;
  final int unreadCount;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.peerName,
    required this.peerImageUrl,
    required this.initials,
    required this.lastMessage,
    required this.date,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: hasUnread
                  ? AppColors.deepBlue.withOpacity(0.15)
                  : const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFEAF2FF),
                    backgroundImage:
                        peerImageUrl.isNotEmpty ? NetworkImage(peerImageUrl) : null,
                    child: peerImageUrl.isEmpty
                        ? Text(
                            initials,
                            style: TextStyle(
                              color: AppColors.deepBlue,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          )
                        : null,
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        height: 12,
                        width: 12,
                        decoration: BoxDecoration(
                          color: AppColors.royalBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            peerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight:
                                  hasUnread ? FontWeight.w900 : FontWeight.w800,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        if (date.isNotEmpty)
                          Text(
                            date,
                            style: TextStyle(
                              color: hasUnread
                                  ? AppColors.deepBlue
                                  : const Color(0xFF94A3B8),
                              fontSize: 11.5,
                              fontWeight:
                                  hasUnread ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage.isEmpty
                                ? 'No messages yet'
                                : lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnread
                                  ? const Color(0xFF334155)
                                  : const Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight:
                                  hasUnread ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.deepBlue,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
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
}

class _StateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onPressed;

  const _StateView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 76,
            width: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(
              icon,
              color: AppColors.deepBlue,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (buttonText != null && onPressed != null) ...[
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonText!,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}