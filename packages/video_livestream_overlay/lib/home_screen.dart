import 'dart:math';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'livestream_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _createLoadingText;
  String? _viewLoadingText;

  String _generateRandomCallId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Livestream Overlay'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await StreamVideo.instance.disconnect();
              await StreamVideo.reset();

              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hello ${StreamVideo.instance.currentUser.name}!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Start a livestream with a real-time scoreboard overlay '
                'composited directly into your video frames — visible to all '
                'viewers, recordings, and RTMP restreams.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.videocam),
                  onPressed: _createLoadingText == null
                      ? _createLivestream
                      : null,
                  label: Text(_createLoadingText ?? 'Create a Livestream'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: _viewLoadingText == null ? _viewLivestream : null,
                  label: Text(_viewLoadingText ?? 'View a Livestream'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createLivestream() async {
    setState(() => _createLoadingText = 'Creating Livestream...');

    try {
      await [Permission.camera, Permission.microphone].request();

      final callId = _generateRandomCallId();

      final call = StreamVideo.instance.makeCall(
        callType: StreamCallType.liveStream(),
        id: callId,
      );

      final result = await call.getOrCreate(
        members: [
          MemberRequest(
            userId: StreamVideo.instance.currentUser.id,
            role: 'host',
          ),
        ],
      );

      if (result.isFailure) {
        _showSnack('Could not create call: $result');
        return;
      }

      // Disable the local selfie-preview mirror so burned-in filters (like the
      // scoreboard overlay) look identical in the local preview, on remote
      // participants and in HLS/RTMP egress. Without this, the local preview
      // horizontally flips the whole frame and the overlay reads backwards on
      // exactly one view.
      final connectOptions = CallConnectOptions(
        camera: TrackOption.enabled(
          constraints: const CameraConstraints(mirrorMode: MirrorMode.off),
        ),
        microphone: TrackOption.enabled(),
      );

      await call.join(connectOptions: connectOptions);
      await call.goLive();

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveStreamScreen(
            livestreamCall: call,
            callId: callId,
            isHost: true,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _createLoadingText = null);
    }
  }

  Future<void> _viewLivestream() async {
    final callId = await _showCallIdDialog();
    if (callId == null || callId.isEmpty) return;

    setState(() => _viewLoadingText = 'Joining Livestream...');

    try {
      final call = StreamVideo.instance.makeCall(
        callType: StreamCallType.liveStream(),
        id: callId,
      );

      final result = await call.getOrCreate();

      if (result.isFailure) {
        _showSnack('Could not join call: $result');
        return;
      }

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: const Text('Livestream'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  call.leave();
                  Navigator.of(context).pop();
                },
              ),
            ),
            body: LivestreamPlayer(
              call: call,
              joinBehaviour: LivestreamJoinBehaviour.autoJoinAsap,
              connectOptions: CallConnectOptions(
                camera: TrackOption.disabled(),
                microphone: TrackOption.disabled(),
              ),
              pictureInPictureConfiguration:
                  const PictureInPictureConfiguration(
                    enablePictureInPicture: true,
                  ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _viewLoadingText = null);
    }
  }

  Future<String?> _showCallIdDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Call ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Call ID from the host',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
