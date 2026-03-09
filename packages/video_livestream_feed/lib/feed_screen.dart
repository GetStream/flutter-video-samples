import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'app_config.dart';
import 'call_manager.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _callManager = CallManager();
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _callManager.switchToCall(AppConfig.channels[0].id);
  }

  @override
  void dispose() {
    _callManager.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: AppConfig.channels.length,
            onPageChanged: (index) {
              _callManager.switchToCall(AppConfig.channels[index].id);
            },
            itemBuilder: (context, index) {
              final channel = AppConfig.channels[index];
              return _LivestreamPage(
                channel: channel,
                callManager: _callManager,
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  _BackButton(onPressed: () => Navigator.of(context).pop()),
                  const Spacer(),
                  _ViewerBadge(callManager: _callManager),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single full-screen page in the feed representing one channel.
class _LivestreamPage extends StatelessWidget {
  const _LivestreamPage({required this.channel, required this.callManager});

  final ChannelInfo channel;
  final CallManager callManager;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient (visible when no video)
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: channel.gradient,
            ),
          ),
        ),
        // Video or placeholder
        ListenableBuilder(
          listenable: callManager,
          builder: (context, _) {
            final isActive = callManager.currentCallId == channel.id;
            final isConnected =
                isActive && callManager.state == CallManagerState.connected;
            final isConnecting =
                isActive && callManager.state == CallManagerState.connecting;

            if (isConnected && callManager.currentCall != null) {
              return _ActiveVideo(call: callManager.currentCall!);
            }
            if (isConnecting) {
              return const _ConnectingOverlay();
            }
            return const _OfflineOverlay();
          },
        ),
        // Bottom channel info overlay
        _ChannelInfoOverlay(channel: channel, callManager: callManager),
      ],
    );
  }
}

/// Renders the livestream video when the call is connected.
///
/// Shows [StreamCallContent] when there are remote participants (a host is
/// live), or a "No one is live" message otherwise.
class _ActiveVideo extends StatelessWidget {
  const _ActiveVideo({required this.call});

  final Call call;

  @override
  Widget build(BuildContext context) {
    return PartialCallStateBuilder(
      call: call,
      selector: (state) =>
          state.otherParticipants.where((p) => p.isVideoEnabled).isNotEmpty,
      builder: (context, hasHost) {
        if (!hasHost) {
          return const _OfflineOverlay();
        }
        return LivestreamPlayer(call: call, onCallDisconnected: (_) {});
      },
    );
  }
}

class _ConnectingOverlay extends StatelessWidget {
  const _ConnectingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black38,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Connecting...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineOverlay extends StatelessWidget {
  const _OfflineOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tv_off, size: 64, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              'No one is live',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Swipe to find an active channel',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelInfoOverlay extends StatelessWidget {
  const _ChannelInfoOverlay({required this.channel, required this.callManager});

  final ChannelInfo channel;
  final CallManager callManager;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ListenableBuilder(
                  listenable: callManager,
                  builder: (context, _) {
                    final isActive = callManager.currentCallId == channel.id;
                    final isConnected =
                        isActive &&
                        callManager.state == CallManagerState.connected;

                    if (isConnected && callManager.currentCall != null) {
                      return _LiveBadge(call: callManager.currentCall!);
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(channel.icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        channel.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  channel.id,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a "LIVE" badge with viewer count when the channel is live.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.call});

  final Call call;

  @override
  Widget build(BuildContext context) {
    return PartialCallStateBuilder(
      call: call,
      selector: (state) =>
          state.otherParticipants.where((p) => p.isVideoEnabled).isNotEmpty,
      builder: (context, hasHost) {
        if (!hasHost) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        );
      },
    );
  }
}

class _ViewerBadge extends StatelessWidget {
  const _ViewerBadge({required this.callManager});

  final CallManager callManager;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: callManager,
      builder: (context, _) {
        if (callManager.state != CallManagerState.connected ||
            callManager.currentCall == null) {
          return const SizedBox.shrink();
        }
        return PartialCallStateBuilder(
          call: callManager.currentCall!,
          selector: (state) => state.callParticipants.length,
          builder: (context, count) {
            if (count <= 1) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
