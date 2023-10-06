import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

class NetworkQualityIndicatorExample extends StatefulWidget {
  const NetworkQualityIndicatorExample({super.key, required this.call});

  final Call call;

  @override
  State<NetworkQualityIndicatorExample> createState() => _NetworkQualityIndicatorExampleState();
}

class _NetworkQualityIndicatorExampleState extends State<NetworkQualityIndicatorExample> {
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
        title: const Text('Network Quality Indicator Example'),
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
                    connectionLevelActiveColor: Colors.yellow,
                    connectionLevelAlignment: Alignment.bottomRight,
                    connectionLevelInactiveColor: Colors.white,
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
