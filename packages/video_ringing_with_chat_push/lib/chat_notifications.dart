import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:stream_chat/stream_chat.dart' as chat;
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    hide User, CurrentPlatform;

final _localNotifications = FlutterLocalNotificationsPlugin();

/// One-time setup: creates the Android notification channel and initializes
/// the local notifications plugin.
Future<void> initLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();

  await _localNotifications.initialize(
    settings: const InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    ),
  );
}

/// Registers the current FCM token with the Stream Chat backend and
/// subscribes to token refreshes so the device stays registered.
void registerChatDevice(StreamChatClient client, {String? pushProviderName}) {
  FirebaseMessaging.instance.getToken().then((token) {
    if (token != null) {
      client.addDevice(
        token,
        chat.PushProvider.firebase,
        pushProviderName: pushProviderName,
      );
    }
  });

  FirebaseMessaging.instance.onTokenRefresh.listen((token) {
    client.addDevice(
      token,
      chat.PushProvider.firebase,
      pushProviderName: pushProviderName,
    );
  });
}

bool isChatNotification(RemoteMessage message) {
  return message.data['type'] == 'message.new';
}

bool isMissedCallNotification(RemoteMessage message) {
  return message.data['type'] == 'call.missed';
}

bool isVideoNotification(RemoteMessage message) {
  return message.data['sender'] == 'stream.video';
}

Future<void> handleMissedCallNotification(RemoteMessage message) async {
  final data = message.data;
  if (data['type'] != 'call.missed') return;

  final createdByName = data['created_by_display_name'] as String?;
  final callDisplayName = data['call_display_name'] as String?;

  await _localNotifications.show(
    id: message.hashCode,
    title: 'Missed call',
    body: 'You missed a call from ${callDisplayName ?? createdByName}',
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'missed_call',
        'Missed call',
        channelDescription: 'Missed call',
      ),
      iOS: const DarwinNotificationDetails(),
    ),
  );
}

Future<void> handleChatNotification(
  RemoteMessage message,
  StreamChatClient client,
) async {
  final data = message.data;
  if (data['type'] != 'message.new') return;

  try {
    final messageId = data['id'] as String;
    final response = await client.getMessage(messageId);
    final senderName = response.message.user?.name ?? 'Someone';

    await _localNotifications.show(
      id: messageId.hashCode,
      title: 'New message from $senderName',
      body: response.message.text ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_messages',
          'Chat Messages',
          channelDescription: 'Notifications for new chat messages',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  } catch (e) {
    debugPrint('Error showing chat notification: $e');
  }
}
