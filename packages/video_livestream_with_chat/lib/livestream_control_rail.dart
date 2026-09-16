import 'package:flutter/material.dart';

/// The vertical stack of round buttons on the right edge of the stream.
class LivestreamControlRail extends StatelessWidget {
  const LivestreamControlRail({super.key, required this.buttons});

  final List<LivestreamRailButton> buttons;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final button in buttons)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: button),
      ],
    );
  }
}

class LivestreamRailButton extends StatelessWidget {
  const LivestreamRailButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// When false the button renders "off" — muted mic, hidden chat, and so on.
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: isActive
            ? Colors.black.withValues(alpha: 0.45)
            : Colors.redAccent.withValues(alpha: 0.85),
        foregroundColor: Colors.white,
      ),
    );
  }
}
