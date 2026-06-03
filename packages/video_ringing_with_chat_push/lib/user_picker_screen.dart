import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stream_chat/stream_chat.dart' as chat;
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    hide User, CurrentPlatform;
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';

import 'app.dart';
import 'app_config.dart';
import 'chat_notifications.dart';
import 'credential_store.dart';
import 'stream_video_init.dart';

// ---------------------------------------------------------------------------
// Manual user picker
// ---------------------------------------------------------------------------

class UserPickerScreen extends StatelessWidget {
  const UserPickerScreen({
    super.key,
    required this.chatClient,
    required this.onLogout,
  });

  final StreamChatClient chatClient;
  final Future<void> Function() onLogout;

  Future<void> _loginAs(
    BuildContext context, {
    required String userId,
    required String userName,
    required String userToken,
  }) async {
    // Persist credentials so the background handler and cold starts can
    // restore the session.
    final store = await CredentialStore.create();
    await store.save(
      UserCredentials(userId: userId, userName: userName, userToken: userToken),
    );

    await [
      Permission.camera,
      Permission.microphone,
      Permission.notification,
      if (CurrentPlatform.isAndroid) Permission.phone,
    ].request();

    StreamVideoPushNotificationManager.ensureFullScreenIntentPermission();

    // Do not auto-show remote notifications in foreground; we only show chat
    // and missed-call via onMessage + local notifications. call.ring is handled
    // by CallKit on iOS and should not show an FCM banner.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );

    if (CurrentPlatform.isIos) {
      final apnToken = await FirebaseMessaging.instance.getAPNSToken();
      debugPrint('🔔 [APNs] token before StreamVideo init: $apnToken');
    }

    initStreamVideo(userId: userId, userName: userName, userToken: userToken);

    if (!context.mounted) return;
    await StreamChat.of(
      context,
    ).client.connectUser(chat.User(id: userId, name: userName), userToken);
    registerChatDevice(
      chatClient,
      iosPushProviderName: AppConfig.iosPushProviderName,
      androidPushProviderName: AppConfig.androidPushProviderName,
    );

    Future.delayed(const Duration(seconds: 5), () async {
      try {
        final devices = await StreamVideo.instance.getDevices();
        final list = devices.getDataOrNull() ?? [];
        debugPrint('🔔 [Devices] registered devices (${list.length}):');
        for (final d in list) {
          debugPrint(
            '   pushToken=${d.pushToken.substring(0, 16)}… '
            'provider=${d.pushProvider} '
            'providerName=${d.pushProviderName} '
            'voip=${d.voip}',
          );
        }
      } catch (e) {
        debugPrint('🔔 [Devices] error listing devices: $e');
      }
    });

    if (context.mounted) {
      final logout = onLogout;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RingingExampleApp(
            userId: userId,
            userName: userName,
            chatClient: chatClient,
            onLogout: logout,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.video_call,
                  size: 72,
                  color: Color(0xFF005FFF),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ringing Example',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose which user to log in as.\n'
                  'Run the app on two devices to test ringing.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 48),
                FilledButton.icon(
                  icon: const Icon(Icons.person),
                  label: Text('Login as ${AppConfig.user1Name}'),
                  onPressed: () => _loginAs(
                    context,
                    userId: AppConfig.user1Id,
                    userName: AppConfig.user1Name,
                    userToken: AppConfig.user1Token,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.person_outline),
                  label: Text('Login as ${AppConfig.user2Name}'),
                  onPressed: () => _loginAs(
                    context,
                    userId: AppConfig.user2Id,
                    userName: AppConfig.user2Name,
                    userToken: AppConfig.user2Token,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.person_outline),
                  label: Text('Login as ${AppConfig.user3Name}'),
                  onPressed: () => _loginAs(
                    context,
                    userId: AppConfig.user3Id,
                    userName: AppConfig.user3Name,
                    userToken: AppConfig.user3Token,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
