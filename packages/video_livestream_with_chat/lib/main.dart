import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'app_config.dart';
import 'chat_overlay_theme.dart';
import 'home_screen.dart';
import 'stream_clients.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // One Chat client for the whole app. The Video client is a singleton created
  // per login in `StreamClients.connectVideo`.
  final chatClient = StreamChatClient(
    AppConfig.streamApiKey,
    logLevel: Level.WARNING,
  );

  runApp(LivestreamWithChatApp(chatClient: chatClient));
}

class LivestreamWithChatApp extends StatefulWidget {
  const LivestreamWithChatApp({super.key, required this.chatClient});

  final StreamChatClient chatClient;

  @override
  State<LivestreamWithChatApp> createState() => _LivestreamWithChatAppState();
}

class _LivestreamWithChatAppState extends State<LivestreamWithChatApp> {
  SampleUser? _loggedInUser;

  Future<void> _login(SampleUser user) async {
    // The host publishes camera + mic; viewers don't, but asking once here
    // keeps the sample's login flow identical for every user.
    await [Permission.camera, Permission.microphone].request();

    await StreamClients.connectVideo(user);
    await StreamClients.connectChat(widget.chatClient, user);

    if (!mounted) return;
    setState(() => _loggedInUser = user);
  }

  Future<void> _logout() async {
    setState(() => _loggedInUser = null);
    await StreamClients.disconnect(widget.chatClient);
  }

  @override
  Widget build(BuildContext context) {
    final user = _loggedInUser;

    return MaterialApp(
      key: ValueKey(user?.id),
      title: 'Livestream With Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF005FFF),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      builder: (context, child) => StreamChat(
        client: widget.chatClient,
        streamChatThemeData: buildChatOverlayTheme(),
        child: child,
      ),
      home: user != null
          ? HomeScreen(user: user, onLogout: _logout)
          : _UserPickerScreen(onLogin: _login),
    );
  }
}

class _UserPickerScreen extends StatefulWidget {
  const _UserPickerScreen({required this.onLogin});

  final Future<void> Function(SampleUser user) onLogin;

  @override
  State<_UserPickerScreen> createState() => _UserPickerScreenState();
}

class _UserPickerScreenState extends State<_UserPickerScreen> {
  String? _loggingInUserId;

  Future<void> _login(SampleUser user) async {
    if (_loggingInUserId != null) return;
    setState(() => _loggingInUserId = user.id);

    try {
      await widget.onLogin(user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loggingInUserId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to log in: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Livestream With Chat',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Run on two or more devices.\n'
                  'Log in as a host to go live — log in as both hosts to see '
                  'them share the broadcast.\n'
                  'Log in as a viewer to watch, chat, and react.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 40),
                for (final host in AppConfig.hosts) ...[
                  _UserButton(
                    user: host,
                    label: '${host.name} (host)',
                    icon: Icons.podcasts,
                    isPrimary: true,
                    isLoading: _loggingInUserId == host.id,
                    onPressed: () => _login(host),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final viewer in AppConfig.viewers) ...[
                  _UserButton(
                    user: viewer,
                    label: '${viewer.name} (viewer)',
                    icon: Icons.visibility_outlined,
                    isPrimary: false,
                    isLoading: _loggingInUserId == viewer.id,
                    onPressed: () => _login(viewer),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserButton extends StatelessWidget {
  const _UserButton({
    required this.user,
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.isLoading,
    required this.onPressed,
  });

  final SampleUser user;
  final String label;
  final IconData icon;
  final bool isPrimary;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon);

    return SizedBox(
      width: double.infinity,
      child: isPrimary
          ? FilledButton.icon(
              icon: child,
              label: Text(label),
              onPressed: isLoading ? null : onPressed,
            )
          : FilledButton.tonalIcon(
              icon: child,
              label: Text(label),
              onPressed: isLoading ? null : onPressed,
            ),
    );
  }
}
