import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' hide User;
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'in_call_chat.dart';

/// Full-screen call UI powered by [StreamCallContainer] with an optional
/// in-call chat panel backed by Stream Chat.
///
/// A `livestream` chat channel is created (or reused) using the call's ID so
/// that all participants share the same conversation for the duration of the
/// call.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.call});

  final Call call;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Channel? _chatChannel;
  bool _showChat = false;

  @override
  void initState() {
    super.initState();
    _initChatChannel();
  }

  Future<void> _initChatChannel() async {
    final chatClient = StreamChat.of(context).client;
    final channel = chatClient.channel('livestream', id: widget.call.id);
    await channel.watch();
    if (mounted) setState(() => _chatChannel = channel);
  }

  @override
  void dispose() {
    _chatChannel?.stopWatching();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          StreamCallContainer(
            call: widget.call,
            callConnectOptions: CallConnectOptions(
              camera: TrackOption.enabled(),
              microphone: TrackOption.enabled(),
            ),
            onCancelCallTap: () async {
              await widget.call.reject(reason: CallRejectReason.cancel());
            },
            onCallDisconnected: (_) {
              Navigator.of(context).pop();
            },
          ),
          if (_showChat && _chatChannel != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: StreamChannel(
                channel: _chatChannel!,
                child: const InCallChat(),
              ),
            ),
        ],
      ),
      floatingActionButton: _chatChannel != null
          ? FloatingActionButton.small(
              heroTag: 'chat_toggle',
              onPressed: () => setState(() => _showChat = !_showChat),
              child: Icon(_showChat ? Icons.chat_outlined : Icons.chat),
            )
          : null,
    );
  }
}
