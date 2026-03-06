import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat/stream_chat.dart' as chat;
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    hide User, CurrentPlatform;
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';
import 'package:video_ringing_with_chat_push/firebase_options.dart';

import 'app_config.dart';
import 'auto_login_screen.dart';
import 'chat_notifications.dart';
import 'credential_store.dart';
import 'user_picker_screen.dart';

// ---------------------------------------------------------------------------
// Firebase background message handler (Android background + terminated state)
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── Chat message ──────────────────────────────────────────────────────────
  if (isChatNotification(message)) {
    try {
      await initLocalNotifications();

      final store = await CredentialStore.create();
      final creds = store.load();
      if (creds == null) return;

      final chatClient = StreamChatClient(AppConfig.streamApiKey);
      await chatClient.connectUser(
        chat.User(id: creds.userId),
        creds.userToken,
        connectWebSocket: false,
      );

      await handleChatNotification(message, chatClient);
      await chatClient.disconnectUser();
    } catch (e, stk) {
      debugPrint('Error handling background chat message: $e');
      debugPrint(stk.toString());
    }
    return;
  }

  // ── Missed call notification ─────────────────────────────────────────────
  if (isMissedCallNotification(message)) {
    try {
      await initLocalNotifications();

      final store = await CredentialStore.create();
      final creds = store.load();
      if (creds == null) return;

      await handleMissedCallNotification(message);
    } catch (e, stk) {
      debugPrint('Error handling background missed call message: $e');
      debugPrint(stk.toString());
    }
    return;
  }

  try {
    final store = await CredentialStore.create();
    final creds = store.load();
    if (creds == null) return;

    final streamVideo = StreamVideo.create(
      AppConfig.streamApiKey,
      user: User.regular(userId: creds.userId, name: creds.userName),
      userToken: creds.userToken,
      options: StreamVideoOptions(keepConnectionsAliveWhenInBackground: true),
      pushNotificationManagerProvider:
          StreamVideoPushNotificationManager.create(
            iosPushProvider: const StreamVideoPushProvider.apn(
              name: AppConfig.iosPushProviderName,
            ),
            androidPushProvider: const StreamVideoPushProvider.firebase(
              name: AppConfig.androidPushProviderName,
            ),
            pushConfiguration: const StreamVideoPushConfiguration(
              ios: IOSPushConfiguration(iconName: 'IconMask'),
            ),
            registerApnDeviceToken: true,
          ),
    )..connect();

    final subscription = streamVideo.observeCoreRingingEventsForBackground();

    streamVideo.disposeAfterResolvingRinging(
      disposingCallback: () {
        subscription.cancel();
      },
    );

    await streamVideo.handleRingingFlowNotifications(message.data);
  } catch (e, stk) {
    debugPrint('Error handling background video message: $e');
    debugPrint(stk.toString());
  }
}

// ---------------------------------------------------------------------------
// Chat client — created once at startup, lives for the app lifetime.
// ---------------------------------------------------------------------------
late final StreamChatClient _chatClient;

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  _chatClient = StreamChatClient(AppConfig.streamApiKey, logLevel: Level.INFO);

  await initLocalNotifications();

  // Check for stored credentials to enable auto-login when the app is
  // launched from a terminated state (e.g. answering an incoming call).
  final store = await CredentialStore.create();
  final savedCredentials = store.load();

  runApp(
    UserPickerApp(chatClient: _chatClient, savedCredentials: savedCredentials),
  );
}

/// Root widget that either auto-logs in with saved credentials or shows the
/// user picker screen.
class UserPickerApp extends StatefulWidget {
  const UserPickerApp({
    super.key,
    required this.chatClient,
    this.savedCredentials,
  });

  final StreamChatClient chatClient;
  final UserCredentials? savedCredentials;

  @override
  State<UserPickerApp> createState() => _UserPickerAppState();
}

class _UserPickerAppState extends State<UserPickerApp> {
  UserCredentials? _credentials;

  @override
  void initState() {
    super.initState();
    _credentials = widget.savedCredentials;
  }

  Future<void> _handleLogout() async {
    final store = await CredentialStore.create();
    await store.clear();

    // Unmount chat/video UI first so no widgets listen to channel state.
    if (mounted) {
      setState(() => _credentials = null);
    }

    // Disconnect after the frame so the channel list is no longer in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (StreamVideo.isInitialized()) {
          await StreamVideo.reset(disconnect: true);
        }
      } catch (e, stk) {
        debugPrint('Logout: StreamVideo reset failed (continuing): $e');
        debugPrint(stk.toString());
        if (StreamVideo.isInitialized()) {
          try {
            StreamVideo.reset();
          } catch (_) {}
        }
      }
      try {
        await widget.chatClient.disconnectUser();
      } catch (e, stk) {
        debugPrint('Logout: Chat disconnect failed (continuing): $e');
        debugPrint(stk.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: ValueKey(_credentials?.userId),
      title: 'Ringing Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF005FFF),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      builder: (context, child) =>
          StreamChat(client: widget.chatClient, child: child),
      home: _credentials != null
          ? AutoLoginScreen(
              credentials: _credentials!,
              chatClient: widget.chatClient,
              onLogout: _handleLogout,
            )
          : UserPickerScreen(
              chatClient: widget.chatClient,
              onLogout: _handleLogout,
            ),
    );
  }
}
