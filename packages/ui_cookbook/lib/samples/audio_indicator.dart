import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

class AudioIndicatorExample extends StatefulWidget {
  const AudioIndicatorExample({super.key, required this.call});

  final Call call;

  @override
  State<AudioIndicatorExample> createState() => _AudioIndicatorExampleState();
}

class _AudioIndicatorExampleState extends State<AudioIndicatorExample> {
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
  }

  @override
  void dispose() {
    endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Indicator Example'),
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
            callParticipantsBuilder: (
                BuildContext context,
                Call call,
                CallState callState,
                ) {
              return StreamCallParticipants(
                call: call,
                participants: callState.callParticipants,
                callParticipantBuilder: (
                    BuildContext context,
                    Call call,
                    CallParticipantState participantState,
                    ) {
                  return StreamCallParticipant(
                    call: call,
                    participant: participantState,
                    audioLevelIndicatorColor: Colors.teal,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
