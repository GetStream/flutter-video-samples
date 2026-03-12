import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' hide User;
import 'package:stream_video_flutter/stream_video_flutter.dart';

import 'call_screen.dart';

/// A single-channel messaging screen with the ability to start a video call.
class ChannelScreen extends StatelessWidget {
  const ChannelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: StreamChannelHeader(
        actions: [
          IconButton(
            icon: const Icon(Icons.video_call_rounded),
            onPressed: () => _startCall(context),
          ),
        ],
      ),
      body: const Column(
        children: [
          Expanded(child: StreamMessageListView()),
          StreamMessageInput(),
        ],
      ),
    );
  }

  /// Creates a ringing video call with all channel members and sends a custom
  /// attachment so other participants can join from the chat.
  void _startCall(BuildContext context) async {
    final channel = StreamChannel.of(context).channel;
    final currentUser = StreamChat.of(context).currentUser;
    final memberIds = channel.state?.members
            .map((m) => m.userId)
            .where((id) => id != null && id != currentUser?.id)
            .cast<String>()
            .toList() ??
        [];

    try {
      final call = StreamVideo.instance.makeCall(
        callType: StreamCallType.defaultType(),
        id: '${channel.id}_${Random().nextInt(100000)}',
      );

      await call.getOrCreate(
        memberIds: memberIds,
        ringing: true,
        video: true,
      );

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CallScreen(call: call)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    }
  }
}
