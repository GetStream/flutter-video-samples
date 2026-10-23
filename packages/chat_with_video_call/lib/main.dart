import 'package:chat_with_video_call/env/env.dart';
import 'package:chat_with_video_call/env_setup.dart';
import 'package:chat_with_video_call/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load();
  final missingEnvKeys = Env.missingEnvKeys;
  if (missingEnvKeys.isNotEmpty) {
    runApp(MissingEnvApp(missingKeys: missingEnvKeys));
    return;
  }

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
    super.key,
    required this.chatClient,
  });

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
