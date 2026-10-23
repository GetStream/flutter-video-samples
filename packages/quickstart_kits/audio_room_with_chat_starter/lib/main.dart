import 'package:audio_room_with_chat_starter/env/env.dart';
import 'package:audio_room_with_chat_starter/env_setup.dart';
import 'package:audio_room_with_chat_starter/screens/login_screen.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load();
  final missingEnvKeys = Env.missingEnvKeys;
  if (missingEnvKeys.isNotEmpty) {
    runApp(MissingEnvApp(missingKeys: missingEnvKeys));
    return;
  }

  /// TODO: Initialize Stream Chat SDK.

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: LoginScreen());
  }
}
