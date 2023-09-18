import 'dart:async';

import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

import '../env/env.dart';

/// [ParticipantListScreen] displays the user's currently on a call and displays
/// their microphone state in real-time.
///
/// This is possible using a [StreamBuilder] to listen to the ongoing
/// call's [CallState]. As the attributes of users on a call changes, it is
/// propagated via the `CallState`.
class ParticipantListScreen extends StatefulWidget {
  const ParticipantListScreen({super.key, required this.call});

  final Call call;

  @override
  State<ParticipantListScreen> createState() => _ParticipantListScreenState();
}

class _ParticipantListScreenState extends State<ParticipantListScreen> {
  StreamSubscription<CallState>? _subscription;

  @override
  void initState() {
    super.initState();
    widget.call.connect();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    widget.call.end();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Participant List'),
      ),
      body: StreamBuilder<CallState>(
        stream: widget.call.state.valueStream,
        initialData: widget.call.state.value,
        builder: (context, snapshot) {
          if (snapshot.data != null && snapshot.data!.status.isConnected) {
            final callParticipants = snapshot.data!.callParticipants;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(
                  flex: 5,
                  child: ColoredBox(color: Colors.white),
                ),
                Expanded(
                  child: ColoredBox(
                    color: Colors.black87,
                    child: StreamBuilder<CallState>(
                        stream: widget.call.state.valueStream,
                        initialData: widget.call.state.value,
                        builder: (context, snapshot) {
                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            itemBuilder: (context, index) {
                              return CallParticipantWidget(
                                callParticipantState: callParticipants[index],
                              );
                            },
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemCount: callParticipants.length,
                            scrollDirection: Axis.horizontal,
                          );
                        }),
                  ),
                ),
              ],
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}

/// Using the [CallParticipantState], we can access properties of each user on
/// the call. In this simple example, we are rendering a glowing avatar for our
/// call participants and a microphone indicator to reflect whether the user has
/// their microphone turned on or not.
///
/// For more information, see our written guide https://getstream.io/video/docs/flutter/ui-cookbook/participant-list/
class CallParticipantWidget extends StatelessWidget {
  const CallParticipantWidget({super.key, required this.callParticipantState});

  final CallParticipantState callParticipantState;

  @override
  Widget build(BuildContext context) {
    return AvatarGlow(
      animate: callParticipantState.isDominantSpeaker,
      endRadius: 56,
      glowColor: Colors.blue,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          const CircleAvatar(
            radius: 48,
            backgroundImage: NetworkImage(
              Env.sampleUserImage00,
            ),
          ),
          Icon(
            callParticipantState.isAudioEnabled
                ? Icons.mic_rounded
                : Icons.mic_off_rounded,
            color: Colors.white,
          )
        ],
      ),
    );
  }
}
