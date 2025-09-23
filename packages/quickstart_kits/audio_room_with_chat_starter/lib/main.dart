import 'package:audio_room_with_chat_starter/screens/login_screen.dart';
import 'package:flutter/material.dart';

void main() {
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
