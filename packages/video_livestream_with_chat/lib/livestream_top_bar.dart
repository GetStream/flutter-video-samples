import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

/// The `LIVE` badge and viewer pill drawn over the top-left of the stream.
class LivestreamTopBar extends StatelessWidget {
  const LivestreamTopBar({super.key, required this.call});

  final Call call;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _LiveBadge(),
        const SizedBox(width: 8),
        _ViewerPill(call: call),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.circle, size: 7, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Live',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlapping participant avatars plus the total viewer count.
class _ViewerPill extends StatelessWidget {
  const _ViewerPill({required this.call});

  final Call call;

  @override
  Widget build(BuildContext context) {
    return PartialCallStateBuilder(
      call: call,
      selector: (state) => state.callParticipants,
      builder: (context, participants) {
        final shown = participants.take(3).toList();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (shown.isNotEmpty)
                SizedBox(
                  // Avatars overlap by 8px each, so the row is narrower than
                  // the sum of its children.
                  width: 20 + (shown.length - 1) * 12,
                  height: 20,
                  child: Stack(
                    children: [
                      for (var i = 0; i < shown.length; i++)
                        Positioned(
                          left: i * 12,
                          child: _ParticipantAvatar(participant: shown[i]),
                        ),
                    ],
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                '${participants.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  const _ParticipantAvatar({required this.participant});

  final CallParticipantState participant;

  @override
  Widget build(BuildContext context) {
    final image = participant.image;
    final name = participant.name.isNotEmpty ? participant.name : '?';

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black54),
        color: Colors.blueGrey,
        image: image != null && image.isNotEmpty
            ? DecorationImage(image: NetworkImage(image), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: image != null && image.isNotEmpty
          ? null
          : Text(
              name.characters.first.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
    );
  }
}
