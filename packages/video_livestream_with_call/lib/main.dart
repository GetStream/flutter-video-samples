import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_noise_cancellation/noise_cancellation_audio_processor.dart';

import 'app_config.dart';
import 'home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LivestreamWithCallApp());
}

class LivestreamWithCallApp extends StatefulWidget {
  const LivestreamWithCallApp({super.key});

  @override
  State<LivestreamWithCallApp> createState() => _LivestreamWithCallAppState();
}

class _LivestreamWithCallAppState extends State<LivestreamWithCallApp> {
  String? _loggedInUserId;
  String? _loggedInUserName;

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
        audioProcessor: NoiseCancellationAudioProcessor(),
        // Required so the host can stay in the livestream and accept a
        // ringing 1:1 call at the same time.
        allowMultipleActiveCalls: true,
      ),
    );

    setState(() {
      _loggedInUserId = userId;
      _loggedInUserName = userName;
    });
  }

  Future<void> _logout() async {
    setState(() {
      _loggedInUserId = null;
      _loggedInUserName = null;
    });

    if (StreamVideo.isInitialized()) {
      await StreamVideo.reset(disconnect: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: ValueKey(_loggedInUserId),
      title: 'Livestream With Call',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF005FFF),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: _loggedInUserId != null
          ? HomeScreen(
              userId: _loggedInUserId!,
              userName: _loggedInUserName!,
              isHost: _loggedInUserId == AppConfig.hostId,
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
  })
  onLogin;

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
                Icon(Icons.live_tv, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Livestream With Call',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Run on two devices.\n'
                  'Log in as ${AppConfig.hostName} on one to go live.\n'
                  'Log in as ${AppConfig.viewerName} on the other to watch '
                  'and call the host mid-stream.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.podcasts),
                    label: Text('Login as ${AppConfig.hostName} (host)'),
                    onPressed: () => onLogin(
                      userId: AppConfig.hostId,
                      userName: AppConfig.hostName,
                      userToken: AppConfig.hostToken,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.person_outline),
                    label: Text('Login as ${AppConfig.viewerName} (viewer)'),
                    onPressed: () => onLogin(
                      userId: AppConfig.viewerId,
                      userName: AppConfig.viewerName,
                      userToken: AppConfig.viewerToken,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.person_outline),
                    label: Text('Login as ${AppConfig.viewer2Name} (viewer)'),
                    onPressed: () => onLogin(
                      userId: AppConfig.viewer2Id,
                      userName: AppConfig.viewer2Name,
                      userToken: AppConfig.viewer2Token,
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
