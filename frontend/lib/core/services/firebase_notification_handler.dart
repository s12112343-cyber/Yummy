import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../navigation/app_navigator.dart';
import '../../features/profile/chat_screen.dart';

/// Background message handler — called when app is in background or terminated
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 [Background] Received FCM message: ${message.messageId}');
  debugPrint('🔔 [Background] Title: ${message.notification?.title}');
  debugPrint('🔔 [Background] Body: ${message.notification?.body}');
}

/// Initialize Firebase notifications handlers
Future<void> setupFirebaseNotifications() async {
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Handle foreground messages (when app is open)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('🔔 [Foreground] Received FCM message: ${message.messageId}');
    debugPrint('🔔 [Foreground] Title: ${message.notification?.title}');
    debugPrint('🔔 [Foreground] Body: ${message.notification?.body}');
    debugPrint('🔔 [Foreground] Data: ${message.data}');
  });

  // Handle notification tap (when user clicks the notification)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('🔔 [Tap] User tapped notification: ${message.messageId}');
    debugPrint('🔔 [Tap] Title: ${message.notification?.title}');
    debugPrint('🔔 [Tap] Body: ${message.notification?.body}');
    try {
      final data = message.data;
      final type = (data['type'] ?? data['notificationType'] ?? '').toString();
      if (type == 'message') {
        final actorId = (data['actorId'] ?? data['from'] ?? '').toString();
        final actorName = (data['actorName'] ?? '').toString();
        if (actorId.isNotEmpty && appNavigatorKey.currentState != null) {
          appNavigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                peerId: actorId,
                peerName: actorName.isNotEmpty ? actorName : 'Chat',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('🔔 [Tap] navigation error: $e');
    }
  });

  // Get initial message (if app was opened from notification while closed)
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    debugPrint(
      '🔔 [Init] App opened from notification: ${initialMessage.messageId}',
    );
    try {
      final data = initialMessage.data;
      final type = (data['type'] ?? data['notificationType'] ?? '').toString();
      if (type == 'message') {
        final actorId = (data['actorId'] ?? data['from'] ?? '').toString();
        final actorName = (data['actorName'] ?? '').toString();
        if (actorId.isNotEmpty && appNavigatorKey.currentState != null) {
          appNavigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                peerId: actorId,
                peerName: actorName.isNotEmpty ? actorName : 'Chat',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('🔔 [Init] navigation error: $e');
    }
  }
}
