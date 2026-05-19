import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/app_config.dart';

typedef MessageCallback = void Function(Map<String, dynamic> message);

class ChatSocketService {
  static IO.Socket? socket;
  static MessageCallback? _messageCallback;
  static bool _messageListenerRegistered = false;
  static bool get isConnected => socket != null && socket!.connected;

  /// Connects to the socket server and joins a user room
  static Future<void> connect(String userId) async {
    if (isConnected) {
      try {
        socket!.emit('join', userId);
      } catch (_) {}
      return;
    }

    _messageListenerRegistered = false; // Reset on new connection

    final base = AppConfig.baseUrl.replaceFirst('/api', '');
    print('🔌 Connecting to socket at: $base');

    socket = IO.io(
      base,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket!.connect();

    // Wait for connection before returning
    await Future.delayed(Duration(milliseconds: 500));

    int attempts = 0;
    while (!socket!.connected && attempts < 10) {
      await Future.delayed(Duration(milliseconds: 200));
      attempts++;
    }

    socket!.onConnect((_) {
      print('✅ Chat socket connected');
      try {
        socket!.emit('join', userId);
        print('📍 Joined room: $userId');
      } catch (e) {
        print('⚠️ Error emitting join: $e');
      }
    });

    socket!.onDisconnect((_) {
      print('❌ Chat socket disconnected');
      _messageListenerRegistered = false;
    });

    if (socket!.connected) {
      try {
        socket!.emit('join', userId);
        print('📍 Joined room: $userId');
      } catch (e) {
        print('⚠️ Error emitting join: $e');
      }
    }
  }

  static void disconnect() {
    try {
      socket?.disconnect();
    } catch (_) {}
    socket = null;
    _messageListenerRegistered = false;
    _messageCallback = null;
  }

  /// Register a callback for incoming private messages
  /// Only one callback can be registered at a time
  static void onPrivateMessage(MessageCallback cb) {
    _messageCallback = cb;

    // Register listener only once
    if (!_messageListenerRegistered && socket != null) {
      _messageListenerRegistered = true;
      socket!.on('privateMessage', (data) {
        try {
          if (_messageCallback != null) {
            _messageCallback!(Map<String, dynamic>.from(data as Map));
          }
        } catch (e) {
          print('⚠️ privateMessage parse error: $e');
        }
      });
      print('📡 Message listener registered');
    }
  }

  static void sendPrivateMessage(Map<String, dynamic> payload) {
    try {
      socket?.emit('privateMessage', payload);
    } catch (e) {
      print('⚠️ sendPrivateMessage error: $e');
    }
  }

  /// Inform server that user is actively viewing chat with [peerId]
  static void setActiveChat(String userId, String peerId) {
    try {
      socket?.emit('activeChat', {'userId': userId, 'peerId': peerId});
    } catch (e) {
      print('⚠️ setActiveChat error: $e');
    }
  }

  /// Clear active chat state for [userId]
  static void clearActiveChat(String userId) {
    try {
      socket?.emit('clearActiveChat', userId);
    } catch (e) {
      print('⚠️ clearActiveChat error: $e');
    }
  }
}
