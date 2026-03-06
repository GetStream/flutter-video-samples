import 'package:flutter/material.dart';
import 'package:stream_chat/stream_chat.dart' as chat;
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    hide User, CurrentPlatform;

import 'app.dart';
import 'app_config.dart';
import 'chat_notifications.dart';
import 'credential_store.dart';
import 'stream_video_init.dart';
import 'user_picker_screen.dart';

// ---------------------------------------------------------------------------
// Auto-login screen — restores a saved session on cold start
// ---------------------------------------------------------------------------

class AutoLoginScreen extends StatefulWidget {
  const AutoLoginScreen({
    super.key,
    required this.credentials,
    required this.chatClient,
    required this.onLogout,
  });

  final UserCredentials credentials;
  final StreamChatClient chatClient;
  final Future<void> Function() onLogout;

  @override
  State<AutoLoginScreen> createState() => AutoLoginScreenState();
}

class AutoLoginScreenState extends State<AutoLoginScreen> {
  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final creds = widget.credentials;

    try {
      initStreamVideo(
        userId: creds.userId,
        userName: creds.userName,
        userToken: creds.userToken,
      );

      await widget.chatClient.connectUser(
        chat.User(id: creds.userId, name: creds.userName),
        creds.userToken,
      );
      registerChatDevice(
        widget.chatClient,
        pushProviderName: AppConfig.androidPushProviderName,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RingingExampleApp(
              userId: creds.userId,
              userName: creds.userName,
              chatClient: widget.chatClient,
              onLogout: widget.onLogout,
            ),
          ),
        );
      }
    } catch (e, stk) {
      debugPrint('Auto-login failed: $e');
      debugPrint(stk.toString());

      // Fall back to the manual user picker if auto-login fails.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => UserPickerScreen(
              chatClient: widget.chatClient,
              onLogout: widget.onLogout,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
