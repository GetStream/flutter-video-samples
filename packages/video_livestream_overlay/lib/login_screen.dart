import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'app_keys.dart';
import 'home_screen.dart';
import 'tutorial_user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TutorialUser? selectedUser;
  final users = TutorialUser.users;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.live_tv,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Livestream Overlay',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Livestreaming with a scoreboard overlay burned into the '
                  'publisher video via a native video filter.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 48),
                Text(
                  'Login as:',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...users.map((user) {
                  final selected = selectedUser?.user.id == user.user.id;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: selected
                              ? theme.colorScheme.primary.withValues(alpha: 0.2)
                              : null,
                        ),
                        onPressed: () => setState(() => selectedUser = user),
                        child: Text(user.user.name ?? user.user.id),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selectedUser != null
                        ? () async {
                            await StreamVideo(
                              AppKeys.streamApiKey,
                              user: selectedUser!.user,
                              userToken: selectedUser!.token,
                            ).connect();

                            if (!context.mounted) return;
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const HomeScreen(),
                              ),
                            );
                          }
                        : null,
                    child: const Text('Login'),
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
