import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

class LiveStreamSample extends StatefulWidget {
  const LiveStreamSample({
    super.key,
    required this.call,
  });

  final Call call;

  @override
  State<LiveStreamSample> createState() => _LiveStreamSampleState();
}

class _LiveStreamSampleState extends State<LiveStreamSample> {
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

  Widget _buildRender(CallState callState) {
    final participant = callState.callParticipants.first;
    return StreamVideoRenderer(
      call: widget.call,
      videoTrackType: SfuTrackType.video,
      participant: participant,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder(
        stream: widget.call.state.valueStream,
        initialData: widget.call.state.value,
        builder: (context, snapshot) {
          final callState = snapshot.data!;
          return Stack(
            children: [
              if (snapshot.hasData && !callState.isBackstage)
                _buildRender(callState),
              if (snapshot.hasData && !callState.isBackstage)
                Positioned(
                  top: 12.0,
                  left: 12.0,
                  child: Material(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    color: Colors.red,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Viewers: ${callState.callParticipants.length - 1}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (snapshot.hasData && (callState.isBackstage))
                const Material(
                  child: Center(
                    child: Text('Stream not live'),
                  ),
                ),
              if (!snapshot.hasData)
                const Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          );
        },
      ),
    );
  }
}
