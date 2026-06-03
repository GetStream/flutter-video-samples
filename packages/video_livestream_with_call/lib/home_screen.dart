import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'app_config.dart';
import 'host_livestream_screen.dart';
import 'viewer_livestream_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.isHost,
    required this.onLogout,
  });

  final String userId;
  final String userName;
  final bool isHost;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isStarting = false;

  Future<void> _start() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);

    try {
      final call = StreamVideo.instance.makeCall(
        callType: StreamCallType.liveStream(),
        id: AppConfig.livestreamId,
        preferences: DefaultCallPreferences(
          audioConfigurationPolicy: widget.isHost
              ? AudioConfigurationPolicy.broadcaster()
              : AudioConfigurationPolicy.viewer(),
        ),
      );

      final getOrCreateResult = widget.isHost
          ? await call.getOrCreate(
              members: [MemberRequest(userId: widget.userId, role: 'host')],
            )
          : await call.getOrCreate();

      if (getOrCreateResult.isFailure) {
        _showMessage('Failed to prepare livestream.');
        return;
      }

      if (!mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => widget.isHost
              ? HostLivestreamScreen(livestreamCall: call)
              : ViewerLivestreamScreen(livestreamCall: call),
        ),
      );
    } catch (e) {
      _showMessage('Failed to start: $e');
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Livestream With Call'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'logout') await widget.onLogout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Log out'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UserInfoCard(
                userName: widget.userName,
                userId: widget.userId,
                isHost: widget.isHost,
              ),
              const SizedBox(height: 32),
              Text(
                widget.isHost ? 'Go live' : 'Join livestream',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isHost
                    ? 'Start the livestream. Viewers can call you mid-stream — '
                          'when you accept, your mic and camera mute on the '
                          'broadcast and the call shows in a floating window '
                          'on top of the stream.'
                    : 'Watch the host. Tap "Call host" to ring them with a '
                          'separate 1:1 call. If they accept, you get a '
                          'small picture-in-picture call screen on top of '
                          'their livestream.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isStarting ? null : _start,
                  icon: _isStarting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(widget.isHost ? Icons.podcasts : Icons.live_tv),
                  label: Text(
                    widget.isHost ? 'Start livestream' : 'Watch livestream',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _HowItWorksCard(theme: theme, isHost: widget.isHost),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({
    required this.userName,
    required this.userId,
    required this.isHost,
  });

  final String userName;
  final String userId;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                userName[0].toUpperCase(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName, style: theme.textTheme.titleMedium),
                  Text(
                    userId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isHost ? Colors.redAccent : Colors.blueAccent)
                    .withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isHost ? 'HOST' : 'VIEWER',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isHost ? Colors.redAccent : Colors.blueAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.theme, required this.isHost});

  final ThemeData theme;
  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final hostSteps = [
      'Tap "Start livestream" — you go live as the host.',
      'A viewer can ring you mid-stream from the other device.',
      'Accept the ringing call to mute mic + camera in the livestream.',
      'The 1:1 call appears as a floating panel on top of the broadcast.',
      'End the 1:1 call to resume the livestream with mic + camera back on.',
    ];

    final viewerSteps = [
      'Tap "Watch livestream" once the host is live.',
      'Tap "Call host" to ring them with a separate 1:1 call.',
      'When the host accepts, you also see the call in a floating panel.',
      'Hang up to return to the regular full-screen livestream.',
    ];

    final steps = isHost ? hostSteps : viewerSteps;

    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  'How it works',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final step in steps) _bulletPoint(step, theme),
          ],
        ),
      ),
    );
  }

  Widget _bulletPoint(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white38,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
