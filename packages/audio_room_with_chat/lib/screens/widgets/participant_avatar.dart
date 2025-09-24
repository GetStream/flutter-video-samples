import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

class ParticipantAvatar extends StatelessWidget {
  const ParticipantAvatar({
    required this.participantState,
    super.key,
  });

  final CallParticipantState participantState;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.linear,
      decoration: BoxDecoration(
        border: Border.all(
          color: participantState.isSpeaking ? Colors.green : Colors.white,
          width: 2,
        ),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(2),
      child: CircleAvatar(
        radius: 40,
        backgroundImage:
            participantState.image != null && participantState.image!.isNotEmpty
            ? NetworkImage(participantState.image!)
            : null,
        child: participantState.image == null || participantState.image!.isEmpty
            ? Text(
                participantState.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
              )
            : null,
      ),
    );
  }
}
