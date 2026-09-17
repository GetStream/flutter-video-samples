import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'app_config.dart';
import 'host_livestream_screen.dart';
import 'viewer_livestream_screen.dart';

/// Entry screen: prepares the livestream call *and* its chat channel, then
/// opens the host or viewer experience depending on who is logged in.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user, required this.onLogout});

  final SampleUser user;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isStarting = false;

  bool get _isHost => AppConfig.isHost(widget.user.id);

  Future<void> _start() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);

    try {
      final call = await _prepareCall();
      if (call == null) return;

      // `_prepareChannel` reads the Chat client off this context.
      if (!mounted) return;
      final channel = await _prepareChannel(call);
      if (channel == null) return;

      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _isHost
              ? HostLivestreamScreen(call: call, channel: channel)
              : ViewerLivestreamScreen(call: call, channel: channel),
        ),
      );
    } catch (e) {
      _showMessage('Failed to start: $e');
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  /// Creates (or looks up) the livestream call.
  Future<Call?> _prepareCall() async {
    final call = StreamVideo.instance.makeCall(
      callType: StreamCallType.liveStream(),
      id: AppConfig.livestreamId,
      preferences: DefaultCallPreferences(
        audioConfigurationPolicy: _isHost
            ? AudioConfigurationPolicy.broadcaster()
            : AudioConfigurationPolicy.viewer(),
      ),
    );

    // Every host is added as a member with the `host` role, not just whoever
    // happens to create the call. On the `livestream` call type only hosts may
    // publish, so a co-host who joined a call someone else created would
    // otherwise connect with their camera and mic blocked.
    final result = _isHost
        ? await call.getOrCreate(
            members: [
              for (final host in AppConfig.hosts)
                MemberRequest(userId: host.id, role: 'host'),
            ],
          )
        : await call.getOrCreate();

    if (result.isFailure) {
      _showMessage('Failed to prepare the livestream.');
      return null;
    }

    return call;
  }

  /// Creates (or looks up) the chat channel backing the livestream.
  ///
  /// The channel reuses the call id, so there is exactly one chat per
  /// livestream and no extra bookkeeping is needed to pair them up. Only the
  /// host creates it; viewers just watch it.
  Future<Channel?> _prepareChannel(Call call) async {
    final channel = StreamChat.of(context).client.channel(
      AppConfig.chatChannelType,
      id: call.id,
      extraData: const {'name': AppConfig.livestreamName},
    );

    if (_isHost) {
      final createResult = await channel.create();
      if (createResult.channel == null) {
        _showMessage('Failed to create the chat channel.');
        return null;
      }
    }

    await channel.watch();
    return channel;
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
        title: const Text('Livestream With Chat'),
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
              _UserInfoCard(user: widget.user, isHost: _isHost),
              const SizedBox(height: 32),
              Text(
                _isHost ? 'Go live' : 'Join the livestream',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isHost
                    ? 'Start broadcasting. Viewer messages and reactions show '
                          'up over your own camera preview, so you can read '
                          'the room while you stream.'
                    : 'Watch the hosts and join the conversation. '
                          'Chat is overlaid on the video, and the heart and '
                          'clap buttons send live reactions everyone sees.',
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
                      : Icon(_isHost ? Icons.podcasts : Icons.live_tv),
                  label: Text(_isHost ? 'Start livestream' : 'Watch and chat'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _HowItWorksCard(isHost: _isHost),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({required this.user, required this.isHost});

  final SampleUser user;
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
              backgroundImage: NetworkImage(user.image),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: theme.textTheme.titleMedium),
                  Text(
                    user.id,
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
  const _HowItWorksCard({required this.isHost});

  final bool isHost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hostSteps = [
      'Tap "Start livestream" — the call goes live and the chat channel is '
          'created with the same id.',
      'Viewer messages appear over your camera preview as they arrive.',
      'Hearts and claps from viewers float up over the video.',
      'Tap the chat icon to hide the overlay and see the clean feed.',
    ];

    final viewerSteps = [
      'Tap "Watch and chat" once the host is live.',
      'Messages are overlaid on the video — no separate chat screen.',
      'Send a message with the input at the bottom.',
      'Tap the heart or clap to send a reaction everyone in the call sees.',
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
                const Icon(Icons.info_outline, size: 18, color: Colors.white70),
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
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 8),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white38,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        step,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
