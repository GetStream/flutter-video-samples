import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

class ReactionsExample extends StatefulWidget {
  const ReactionsExample({super.key, required this.call});

  final Call call;

  @override
  State<ReactionsExample> createState() => _ReactionsExampleState();
}

class _ReactionsExampleState extends State<ReactionsExample> {
  Future<void> startCall() async {
    await widget.call.connect();
  }

  Future<void> endCall() async {
    await widget.call.end();
  }

  @override
  void initState() {
    super.initState();
    startCall();
    listenForReactions();
  }

  @override
  void dispose() {
    endCall();
    super.dispose();
  }

  Future<void> sendCallReaction() async {
    await widget.call.sendReaction(
      reactionType: 'raised-hand',
      emojiCode: ':raise-hand:',
    );
  }

  Future<void> listenForReactions() async {
    final reactions = widget.call.getCurrentReactions();
    print(reactions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Requests Example'),
        actions: [
          IconButton(
            onPressed: sendCallReaction,
            icon: const Icon(Icons.thumb_up),
          )
        ],
      ),
      body: StreamBuilder<CallState>(
        stream: widget.call.state.valueStream,
        initialData: widget.call.state.value,
        builder: (context, snapshot) {
          return StreamCallContent(
            call: widget.call,
            callState: snapshot.data!,
            callAppBarBuilder: (context, call, callState) =>
                const PreferredSize(
              preferredSize: Size.zero,
              child: SizedBox(),
            ),
          );
        },
      ),
    );
  }
}
