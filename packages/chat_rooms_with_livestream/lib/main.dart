import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'bench/bench.dart';
import 'bench/bench_overlay.dart';
import 'bench/native_calls.dart';
import 'env/env.dart';
import 'screens/login_screen.dart';
import 'theme.dart';
import 'widgets/livestream_attachment_builder.dart';

void main() {
  // Benchmark mode times native calls, which needs its binding to be the
  // first one created.
  if (Bench.enabled) {
    BenchBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  // One chat client for the whole app, created before runApp. The Video client
  // is a singleton created at sign-in, once we know which user's token to use.
  final chatClient = StreamChatClient(
    Env.streamApiKey,
    logLevel: Level.WARNING,
    logHandlerFunction: Bench.enabled
        ? Bench.instance.chatLog
        : StreamChatClient.defaultLogHandler,
  );

  // Benchmark mode only (`--dart-define=STREAM_BENCH=true`); a no-op otherwise.
  unawaited(Bench.instance.start(chatClient: chatClient));

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
        child: BenchOverlay(child: child!),
      ),
      home: const LoginScreen(),
    );
  }
}
