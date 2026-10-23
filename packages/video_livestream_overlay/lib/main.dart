/// Sample app for the Stream Livestreaming tutorial, extended with a
/// scoreboard overlay burned into the publisher's video via a native video
/// filter (see [ScoreboardVideoFrameProcessor] in `AppDelegate.swift` and
/// [ScoreboardVideoFilter] in `MainActivity.kt`).
///
/// Flow:
///   - Login as one of three demo users
///   - Create a livestream (goes live immediately) or join one by call ID
///   - As host: toggle the scoreboard overlay, update scores and control a
///     game clock — the overlay is encoded into the outgoing video and flows
///     through to all participants and HLS/RTMP egress
///
/// The Stream credentials are read from `env/env.json`, see the README.
library;

import 'package:flutter/material.dart';

import 'app_keys.dart';
import 'env_setup.dart';
import 'login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppKeys.load();
  final missingEnvKeys = AppKeys.missingEnvKeys;
  if (missingEnvKeys.isNotEmpty) {
    runApp(MissingEnvApp(missingKeys: missingEnvKeys));
    return;
  }

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
