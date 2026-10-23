import 'package:flutter/material.dart';

import '../theme.dart';

/// The pulsing `LIVE` pill used everywhere a broadcast is running.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.viewerCount, this.compact = false});

  /// Optional WebRTC-connected viewer count shown next to the label.
  final int? viewerCount;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.live,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          if (viewerCount != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.visibility, size: 12, color: Colors.white70),
            const SizedBox(width: 3),
            Text(
              '$viewerCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
