import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'app_config.dart';
import 'home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MulticallApp());
}

class MulticallApp extends StatefulWidget {
  const MulticallApp({super.key});

  @override
  State<MulticallApp> createState() => _MulticallAppState();
}

class _MulticallAppState extends State<MulticallApp> {
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
      options: StreamVideoOptions(
        logPriority: Priority.debug,
        allowMultipleActiveCalls: true,
      ),
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
      title: 'Multicall Example',
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
                  Icons.swap_calls,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Multicall Example',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose which user to log in as.\n'
                  'Run the app on two devices to test\n'
                  'switching between multiple call rooms.',
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
