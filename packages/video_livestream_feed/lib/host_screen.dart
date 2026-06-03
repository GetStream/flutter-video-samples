import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'app_config.dart';

/// Lets the user pick a channel and start broadcasting their camera.
class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  Call? _call;
  bool _isGoingLive = false;
  bool _isLive = false;
  ChannelInfo? _selectedChannel;

  Future<void> _goLive(ChannelInfo channel) async {
    setState(() {
      _isGoingLive = true;
      _selectedChannel = channel;
    });

    try {
      final call = StreamVideo.instance.makeCall(
        callType: StreamCallType.liveStream(),
        id: channel.id,
      );

      await call.getOrCreate(
        members: [
          MemberRequest(
            userId: StreamVideo.instance.currentUser.id,
            role: 'host',
          ),
        ],
      );

      await call.join(
        connectOptions: CallConnectOptions(
          camera: TrackOption.enabled(),
          microphone: TrackOption.enabled(),
        ),
      );

      await call.goLive();

      if (mounted) {
        setState(() {
          _call = call;
          _isGoingLive = false;
          _isLive = true;
        });
      }
    } catch (e) {
      debugPrint('HostScreen: failed to go live: $e');
      if (mounted) {
        setState(() {
          _isGoingLive = false;
          _selectedChannel = null;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to go live: $e')));
      }
    }
  }

  Future<void> _endLive() async {
    try {
      await _call?.stopLive();
      await _call?.leave();
    } catch (e) {
      debugPrint('HostScreen: error ending live: $e');
    }
    if (mounted) {
      setState(() {
        _call = null;
        _isLive = false;
        _selectedChannel = null;
      });
    }
  }

  @override
  void dispose() {
    if (_isLive && _call != null) {
      _call!.stopLive();
      _call!.leave();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isGoingLive) {
      return _GoingLiveOverlay(channelName: _selectedChannel!.name);
    }

    if (_isLive && _call != null) {
      return _BroadcastScreen(
        call: _call!,
        channel: _selectedChannel!,
        onEndLive: _endLive,
      );
    }

    return _ChannelPickerScreen(onGoLive: _goLive);
  }
}

class _GoingLiveOverlay extends StatelessWidget {
  const _GoingLiveOverlay({required this.channelName});

  final String channelName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Going live on $channelName...',
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelPickerScreen extends StatelessWidget {
  const _ChannelPickerScreen({required this.onGoLive});

  final void Function(ChannelInfo channel) onGoLive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Go Live')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick a channel to broadcast on',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your camera will be shared with everyone watching this channel.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: AppConfig.channels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final channel = AppConfig.channels[index];
                    return _ChannelCard(
                      channel: channel,
                      onGoLive: () => onGoLive(channel),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel, required this.onGoLive});

  final ChannelInfo channel;
  final VoidCallback onGoLive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onGoLive,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                channel.gradient[0].withValues(alpha: 0.3),
                channel.gradient[1].withValues(alpha: 0.1),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: channel.gradient[0].withValues(alpha: 0.3),
                  child: Icon(channel.icon, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(channel.name, style: theme.textTheme.titleMedium),
                      Text(
                        channel.id,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                _GoLiveButton(gradient: channel.gradient, onPressed: onGoLive),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoLiveButton extends StatelessWidget {
  const _GoLiveButton({required this.gradient, required this.onPressed});

  final List<Color> gradient;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, size: 18, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Go Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
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

class _BroadcastScreen extends StatelessWidget {
  const _BroadcastScreen({
    required this.call,
    required this.channel,
    required this.onEndLive,
  });

  final Call call;
  final ChannelInfo channel;
  final VoidCallback onEndLive;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _BroadcastHeader(channel: channel, call: call),
          Expanded(
            child: PartialCallStateBuilder(
              call: call,
              selector: (state) => state.callParticipants
                  .where((p) => p.isVideoEnabled)
                  .toList(),
              builder: (context, hosts) {
                if (hosts.isEmpty) {
                  return const Center(
                    child: Text(
                      "Host video is not available",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  );
                }

                return StreamCallContent(
                  call: call,
                  callAppBarWidgetBuilder: (_, __) => PreferredSize(
                    preferredSize: Size.zero,
                    child: const SizedBox.shrink(),
                  ),
                  callControlsWidgetBuilder: (_, __) => const SizedBox.shrink(),
                  callParticipantsWidgetBuilder: (context, call) {
                    return StreamCallParticipants(
                      call: call,
                      participants: hosts,
                    );
                  },
                );
              },
            ),
          ),
          _BroadcastControls(call: call, onEndLive: onEndLive),
        ],
      ),
    );
  }
}

class _BroadcastHeader extends StatelessWidget {
  const _BroadcastHeader({required this.channel, required this.call});

  final ChannelInfo channel;
  final Call call;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  channel.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              PartialCallStateBuilder(
                call: call,
                selector: (state) => state.callParticipants.length,
                builder: (context, count) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BroadcastControls extends StatelessWidget {
  const _BroadcastControls({required this.call, required this.onEndLive});

  final Call call;
  final VoidCallback onEndLive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: ToggleMicrophoneOption(call: call),
              ),
              SizedBox(
                width: 52,
                height: 52,
                child: ToggleCameraOption(call: call),
              ),
              SizedBox(
                width: 52,
                height: 52,
                child: FlipCameraOption(call: call),
              ),
              SizedBox(
                width: 52,
                height: 52,
                child: Material(
                  color: Colors.red,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onEndLive,
                    child: const Center(
                      child: Icon(Icons.stop, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
