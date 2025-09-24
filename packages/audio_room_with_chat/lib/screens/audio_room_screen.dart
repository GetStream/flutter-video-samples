import 'package:audio_room_with_chat/screens/widgets/audio_room_actions.dart';
import 'package:audio_room_with_chat/screens/widgets/participant_avatar.dart';
import 'package:audio_room_with_chat/screens/widgets/permission_requests.dart';
import 'package:audio_room_with_chat/screens/widgets/chat_sheet.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

class AudioRoomScreen extends StatefulWidget {
  const AudioRoomScreen({
    super.key,
    required this.audioRoomCall,
    required this.chatChannel,
  });

  final Call audioRoomCall;
  final Channel chatChannel;

  @override
  State<AudioRoomScreen> createState() => _AudioRoomScreenState();
}

class _AudioRoomScreenState extends State<AudioRoomScreen> {
  late CallState _callState;

  @override
  void initState() {
    super.initState();
    widget.audioRoomCall.join();
    _callState = widget.audioRoomCall.state.value;
  }

  @override
  Widget build(BuildContext context) {
    return StreamChannel(
      channel: widget.chatChannel,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Audio Room: ${_callState.callId}'),
          leading: IconButton(
            onPressed: () async {
              await widget.audioRoomCall.leave();

              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(
              Icons.close,
            ),
          ),
        ),
        floatingActionButton: AudioRoomActions(
          audioRoomCall: widget.audioRoomCall,
        ),
        bottomSheet: ChatSheet(),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              StreamBuilder<CallState>(
                initialData: _callState,
                stream: widget.audioRoomCall.state.valueStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Something went wrong. Check logs for more details.',
                      ),
                    );
                  }

                  if (snapshot.hasData && !snapshot.hasError) {
                    var callState = snapshot.data!;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 300),
                      child: GridView.builder(
                        itemBuilder: (BuildContext context, int index) {
                          return Align(
                            widthFactor: 0.8,
                            child: ParticipantAvatar(
                              participantState:
                                  callState.callParticipants[index],
                            ),
                          );
                        },
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                            ),
                        itemCount: callState.callParticipants.length,
                      ),
                    );
                  }

                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
              ),
              if (widget.audioRoomCall.state.value.createdByMe)
                Positioned(
                  bottom: 300,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 80),
                      child: PermissionRequests(
                        audioRoomCall: widget.audioRoomCall,
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
