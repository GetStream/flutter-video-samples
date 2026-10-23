import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'env/env.dart';
import 'env_setup.dart';
import 'screens/login_screen.dart';
import 'theme.dart';
import 'widgets/livestream_attachment_builder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Env.load();
  final missingEnvKeys = Env.missingEnvKeys;
  if (missingEnvKeys.isNotEmpty) {
    runApp(MissingEnvApp(missingKeys: missingEnvKeys));
    return;
  }

  // One chat client for the whole app, created before runApp. The Video client
  // is a singleton created at sign-in, once we know which user's token to use.
  final chatClient = StreamChatClient(
    Env.streamApiKey,
    logLevel: Level.WARNING,
  );

  runApp(CreatorRoomsApp(chatClient: chatClient));
}

class CreatorRoomsApp extends StatelessWidget {
  const CreatorRoomsApp({super.key, required this.chatClient});

  final StreamChatClient chatClient;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Creator Rooms',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) => StreamChat(
        client: chatClient,
        // Prepends the livestream join card to the default attachment builders,
        // so every message list in the app renders announcements the same way.
        configData: StreamChatConfigurationData(
          attachmentBuilders: [LivestreamAttachmentBuilder()],
        ),
        themeData: StreamChatThemeData(
          messageListViewTheme: const StreamMessageListViewThemeData(
            backgroundColor: AppColors.background,
          ),
        ),
        child: child!,
      ),
      home: const LoginScreen(),
    );
  }
}
