/// Sample app for the Stream Livestreaming tutorial, extended with a
/// scoreboard overlay burned into the publisher's video via a native video
/// filter (see [ScoreboardVideoFrameProcessor] in `AppDelegate.swift` and
/// [ScoreboardVideoFilter] in `MainActivity.kt`).
///
/// Flow:
///   - Login as one of three demo users
///   - Create a livestream (you become the host) or join one by call ID
///   - As host: toggle the scoreboard overlay and edit its state live — the
///     overlay is encoded into the outgoing video and flows through to all
///     participants and HLS/RTMP egress
///
/// To swap in your own Stream App credentials, update `app_keys.dart`.
library;

import 'package:flutter/material.dart';

import 'login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Livestream Overlay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF005FFF),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
