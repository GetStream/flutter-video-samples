import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    hide User, CurrentPlatform;
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'call_screen.dart';
import 'chat_notifications.dart'
    show
        handleChatNotification,
        isChatNotification,
        isMissedCallNotification,
        handleMissedCallNotification;
import 'home_screen.dart';

/// The main app widget – shown after the user has logged in and
/// [StreamVideo] has been initialised.
class RingingExampleApp extends StatefulWidget {
  const RingingExampleApp({
    super.key,
    required this.userId,
    required this.userName,
    required this.chatClient,
    required this.onLogout,
  });

  final String userId;
  final String userName;
  final StreamChatClient chatClient;
  final Future<void> Function() onLogout;

  @override
  State<RingingExampleApp> createState() => _RingingExampleAppState();
}

class _RingingExampleAppState extends State<RingingExampleApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<dynamic>? _ringingSubscription;
  StreamSubscription<RemoteMessage>? _fcmForegroundSubscription;

  @override
  void initState() {
    super.initState();
    _observeRingingEvents();
    _observeFcmForegroundMessages();
    _tryConsumingIncomingCallFromTerminatedState();
  }

  // ── Ringing events (foreground & background on mobile) ──────────────────
  void _observeRingingEvents() {
    final streamVideo = StreamVideo.instance;

    _ringingSubscription = streamVideo.observeCoreRingingEvents(
      onCallAccepted: (call) {
        _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => CallScreen(call: call)),
        );
      },
    );
  }

  // ── FCM foreground messages ─────────────────────────────────────────────
  void _observeFcmForegroundMessages() {
    _fcmForegroundSubscription = FirebaseMessaging.onMessage.listen((message) {
      if (isChatNotification(message)) {
        handleChatNotification(message, widget.chatClient);
      } else if (isMissedCallNotification(message)) {
        handleMissedCallNotification(message);
      } else if (CurrentPlatform.isAndroid) {
        StreamVideo.instance.handleRingingFlowNotifications(
          message.data,
          handleMissedCall: false,
        );
      }
    });
  }

  // ── Android terminated-state handling ───────────────────────────────────
  void _tryConsumingIncomingCallFromTerminatedState() {
    if (!CurrentPlatform.isAndroid) return;

    // Wait until the navigator is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StreamVideo.instance.consumeAndAcceptActiveCall(
        onCallAccepted: (call) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => CallScreen(call: call)),
          );
        },
      );
    });
  }

  @override
  void dispose() {
    _ringingSubscription?.cancel();
    _fcmForegroundSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ringing Example',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF005FFF),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      builder: (context, child) =>
          StreamChat(client: widget.chatClient, child: child),
      home: HomeScreen(
        userId: widget.userId,
        userName: widget.userName,
        onLogout: widget.onLogout,
      ),
    );
  }
}
