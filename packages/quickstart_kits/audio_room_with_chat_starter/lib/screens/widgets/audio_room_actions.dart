import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

class AudioRoomActions extends StatefulWidget {
  const AudioRoomActions({required this.audioRoomCall, super.key});

  final Call audioRoomCall;

  @override
  State<AudioRoomActions> createState() => _AudioRoomActionsState();
}

class _AudioRoomActionsState extends State<AudioRoomActions> {
  var _microphoneEnabled = false;
  var _waitingForPermission = false;

  StreamSubscription? _callEventsSubscription;

  @override
  void initState() {
    super.initState();
    _microphoneEnabled =
        widget.audioRoomCall.connectOptions.microphone.isEnabled;

    _callEventsSubscription = widget.audioRoomCall.callEvents
        .on<StreamCallPermissionsUpdatedEvent>(
          (
            event,
          ) {
            if (event.user.id != StreamVideo.instance.currentUser.id) {
              return;
            }

            if (_waitingForPermission &&
                event.ownCapabilities.contains(CallPermission.sendAudio)) {
              setState(() {
                _waitingForPermission = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Permission to speak granted. You can now enable your microphone.',
                  ),
                ),
              );
            }
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CallState>(
      initialData: widget.audioRoomCall.state.value,
      stream: widget.audioRoomCall.state.valueStream,
      builder: (context, snapshot) {
        final callState = snapshot.data;

        if (callState == null) {
          return const SizedBox.shrink();
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 20,
          children: [
            if (callState.createdByMe)
              FloatingActionButton.extended(
                heroTag: 'go-live',
                label: callState.isBackstage
                    ? const Text('Go Live')
                    : const Text('Stop Live'),
                icon: callState.isBackstage
                    ? const Icon(
                        Icons.play_arrow,
                        color: Colors.green,
                      )
                    : const Icon(
                        Icons.stop,
                        color: Colors.red,
                      ),
                onPressed: () async {
                  if (callState.isBackstage) {
                    await widget.audioRoomCall.goLive();
                    await widget.audioRoomCall.update(custom: {"live": true});
                  } else {
                    await widget.audioRoomCall.stopLive();
                    await widget.audioRoomCall.update(custom: {"live": false});
                  }
                },
              ),
            FloatingActionButton(
              heroTag: 'microphone',
              child: _microphoneEnabled
                  ? const Icon(Icons.mic)
                  : const Icon(Icons.mic_off),
              onPressed: () {
                if (_microphoneEnabled) {
                  widget.audioRoomCall.setMicrophoneEnabled(enabled: false);
                  setState(() {
                    _microphoneEnabled = false;
                  });
                } else {
                  if (!widget.audioRoomCall.hasPermission(
                    CallPermission.sendAudio,
                  )) {
                    widget.audioRoomCall.requestPermissions(
                      [CallPermission.sendAudio],
                    );

                    setState(() {
                      _waitingForPermission = true;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permission to speak requested'),
                      ),
                    );
                  } else {
                    widget.audioRoomCall.setMicrophoneEnabled(enabled: true);
                    setState(() {
                      _microphoneEnabled = true;
                    });
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _callEventsSubscription?.cancel();
    super.dispose();
  }
}
