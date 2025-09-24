import 'package:chat_with_video_call/env/env.dart';
import 'package:chat_with_video_call/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

void main() {
  final client = StreamChatClient(
    Env.streamApiKey,
    logLevel: Level.INFO,
  );

  runApp(
    MyApp(
      chatClient: client,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    Key? key,
    required this.chatClient,
  }) : super(key: key);

  final StreamChatClient chatClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) => StreamChat(
        client: chatClient,
        child: child,
      ),
      home: LoginScreen(),
    );
  }
}
