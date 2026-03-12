import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'app_config.dart';
import 'home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LivestreamFeedApp());
}

class LivestreamFeedApp extends StatefulWidget {
  const LivestreamFeedApp({super.key});

  @override
  State<LivestreamFeedApp> createState() => _LivestreamFeedAppState();
}

class _LivestreamFeedAppState extends State<LivestreamFeedApp> {
  String? _loggedInUserId;

  Future<void> _loginAs({
    required String userId,
    required String userName,
    required String userToken,
  }) async {
    await [Permission.camera, Permission.microphone].request();

    if (StreamVideo.isInitialized()) {
      await StreamVideo.reset(disconnect: true);
    }

    StreamVideo(
      AppConfig.streamApiKey,
      user: User.regular(userId: userId, name: userName),
      userToken: userToken,
      options: StreamVideoOptions(logPriority: Priority.debug),
    );

    setState(() => _loggedInUserId = userId);
  }

  Future<void> _logout() async {
    setState(() => _loggedInUserId = null);

    if (StreamVideo.isInitialized()) {
      await StreamVideo.reset(disconnect: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: ValueKey(_loggedInUserId),
      title: 'Livestream Feed',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF005FFF),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: _loggedInUserId != null
          ? HomeScreen(
              userId: _loggedInUserId!,
              userName: _loggedInUserId == AppConfig.user1Id
                  ? AppConfig.user1Name
                  : AppConfig.user2Name,
              onLogout: _logout,
            )
          : _UserPickerScreen(onLogin: _loginAs),
    );
  }
}

class _UserPickerScreen extends StatelessWidget {
  const _UserPickerScreen({required this.onLogin});

  final Future<void> Function({
    required String userId,
    required String userName,
    required String userToken,
  }) onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.live_tv,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Livestream Feed',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose which user to log in as.\n'
                  'Run the app on two devices —\n'
                  'go live on one, browse the feed on the other.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.person),
                    label: Text('Login as ${AppConfig.user1Name}'),
                    onPressed: () => onLogin(
                      userId: AppConfig.user1Id,
                      userName: AppConfig.user1Name,
                      userToken: AppConfig.user1Token,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.person_outline),
                    label: Text('Login as ${AppConfig.user2Name}'),
                    onPressed: () => onLogin(
                      userId: AppConfig.user2Id,
                      userName: AppConfig.user2Name,
                      userToken: AppConfig.user2Token,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
