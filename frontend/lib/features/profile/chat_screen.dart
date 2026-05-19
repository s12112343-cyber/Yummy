import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/chat_socket_service.dart';
import '../../core/theme/app_colors.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String? peerAvatar;

  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = [];
  final Set<String> _receivedMessageIds = <String>{};

  String _currentUserId = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    try {
      if (_currentUserId.isNotEmpty) {
        ChatSocketService.clearActiveChat(_currentUserId);
      }
    } catch (e) {}
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    _currentUserId = await AuthService().getUserId();

    try {
      final token = await AuthService().getToken();
      final base = AppConfig.baseUrl;

      if (token != null && token.trim().isNotEmpty) {
        final url = '$base/chat/conversation/$_currentUserId/${widget.peerId}';

        final resp = await http.get(
          Uri.parse(url),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final list = (data['messages'] as List<dynamic>?) ?? [];

          _messages.clear();
          _receivedMessageIds.clear();

          for (var msg in list) {
            final msgMap = Map<String, dynamic>.from(msg as Map);
            final msgId = msgMap['_id']?.toString() ?? '';

            if (msgId.isNotEmpty && !_receivedMessageIds.contains(msgId)) {
              _receivedMessageIds.add(msgId);
              _messages.add({
                '_id': msgId,
                'from': msgMap['from']?.toString() ?? '',
                'to': msgMap['to']?.toString() ?? '',
                'text': msgMap['text']?.toString() ?? '',
                'read': msgMap['read'] ?? false,
                'createdAt':
                    msgMap['createdAt']?.toString() ??
                    DateTime.now().toIso8601String(),
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading server conversation: $e');
    }

    if (mounted) {
      setState(() => _loading = false);
      _scrollToBottom();
    }

    await ChatSocketService.connect(_currentUserId);

    // Tell server we're actively viewing this chat (now that _currentUserId is set)
    try {
      ChatSocketService.setActiveChat(_currentUserId, widget.peerId);
    } catch (e) {}

    ChatSocketService.onPrivateMessage((msg) async {
      final msgId = msg['_id']?.toString() ?? '';

      if (msgId.isNotEmpty && _receivedMessageIds.contains(msgId)) {
        return;
      }

      final from = msg['from']?.toString() ?? '';
      final to = msg['to']?.toString() ?? '';

      if ((from == widget.peerId && to == _currentUserId) ||
          (from == _currentUserId && to == widget.peerId)) {
        if (msgId.isNotEmpty) {
          _receivedMessageIds.add(msgId);
        }

        if (!mounted) return;

        setState(() {
          _messages.add({
            '_id': msgId.isNotEmpty ? msgId : null,
            'from': from,
            'to': to,
            'text': msg['text']?.toString() ?? '',
            'read': msg['read'] ?? false,
            'createdAt':
                msg['createdAt']?.toString() ??
                DateTime.now().toIso8601String(),
          });
        });

        _scrollToBottom();
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final msg = {
      'from': _currentUserId,
      'to': widget.peerId,
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      if (ChatSocketService.isConnected) {
        ChatSocketService.sendPrivateMessage(msg);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connection lost, trying to reconnect...'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  Future<void> _openPeerProfile() async {
    if (widget.peerId.trim().isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          viewedUserId: widget.peerId,
          viewedUserName: widget.peerName,
          viewedUserImageUrl: widget.peerAvatar,
        ),
      ),
    );
  }

  Future<void> _deleteConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete chat?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'This will delete all messages in this conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await AuthService().getToken();
      final base = AppConfig.baseUrl;

      if (token == null || token.trim().isEmpty) {
        throw Exception('Missing auth token');
      }

      final url = Uri.parse(
        '$base/chat/conversation/$_currentUserId/${widget.peerId}',
      );

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _messages.clear();
          _receivedMessageIds.clear();
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat deleted')));
      } else {
        throw Exception('Failed to delete chat');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  String _formatTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.peerAvatar?.trim() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.deepBlue,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: _openPeerProfile,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFEAF2FF),
                backgroundImage: avatar.isNotEmpty
                    ? NetworkImage(avatar)
                    : null,
                child: avatar.isEmpty
                    ? Text(
                        _initial(widget.peerName),
                        style: TextStyle(
                          color: AppColors.deepBlue,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.peerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Food community chat',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.deepBlue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              if (value == 'delete') {
                _deleteConversation();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete chat'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? _EmptyChat(peerName: widget.peerName)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMine = message['from'] == _currentUserId;
                      final isRead = message['read'] ?? false;

                      return _MessageBubble(
                        text: message['text']?.toString() ?? '',
                        time: _formatTime(message['createdAt']),
                        isMine: isMine,
                        isRead: isRead,
                      );
                    },
                  ),
          ),
          _MessageInput(controller: _controller, onSend: _sendMessage),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isMine;
  final bool isRead;

  const _MessageBubble({
    required this.text,
    required this.time,
    required this.isMine,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(22),
      topRight: const Radius.circular(22),
      bottomLeft: Radius.circular(isMine ? 22 : 6),
      bottomRight: Radius.circular(isMine ? 6 : 22),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 8),
        decoration: BoxDecoration(
          gradient: isMine
              ? LinearGradient(
                  colors: [AppColors.deepBlue, AppColors.royalBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMine ? null : Colors.white,
          borderRadius: radius,
          border: isMine ? null : Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMine ? Colors.white : const Color(0xFF111827),
                fontSize: 14.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: TextStyle(
                      color: isMine
                          ? Colors.white.withOpacity(0.72)
                          : const Color(0xFF94A3B8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (isMine) ...[
                  const SizedBox(width: 5),
                  Icon(
                    isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: isRead
                        ? const Color(0xFF7DD3FC)
                        : Colors.white.withOpacity(0.72),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _MessageInput({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FB),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Write a message...',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: AppColors.deepBlue,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onSend,
                borderRadius: BorderRadius.circular(999),
                child: const SizedBox(
                  height: 48,
                  width: 48,
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final String peerName;

  const _EmptyChat({required this.peerName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 78,
              width: 78,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.deepBlue,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No messages yet',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation with $peerName and share your food ideas.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
