import 'package:flutter/material.dart';

import 'bench.dart';

/// Small always-on-top pill shown in benchmark mode.
///
/// Shows that recording is running and the headline numbers, plus **Share** to
/// send the file off the device. Load changes are marked automatically (see
/// `LoadPhases`), so nothing needs tapping during a run. Tap the dot to
/// collapse it out of the way.
///
/// It repaints once a second, inside its own [RepaintBoundary], so its own
/// cost in the recorded frame numbers is negligible.
class BenchOverlay extends StatefulWidget {
  const BenchOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<BenchOverlay> createState() => _BenchOverlayState();
}

class _BenchOverlayState extends State<BenchOverlay> {
  var _collapsed = false;

  @override
  Widget build(BuildContext context) {
    if (!Bench.enabled) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 8,
          bottom: MediaQuery.paddingOf(context).bottom + 96,
          child: RepaintBoundary(
            child: Material(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              child: ValueListenableBuilder(
                valueListenable: Bench.instance.overlay,
                builder: (context, data, _) => _collapsed
                    ? _dot(onTap: () => setState(() => _collapsed = false))
                    : _expanded(data),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot({required VoidCallback onTap}) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: const Padding(
      padding: EdgeInsets.all(10),
      child: Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 14),
    ),
  );

  Widget _expanded(BenchOverlayData? data) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    final elapsed = data?.elapsed ?? Duration.zero;
    final clock =
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:'
        '${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 6, 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(onTap: () => setState(() => _collapsed = true)),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REC $clock  ${data?.role ?? 'no call'}'
                '${data?.participants != null ? '  ${data!.participants} ppl' : ''}',
                style: style,
              ),
              Text(
                '${data?.fps ?? 0} fps  ${data?.jank ?? 0} jank  '
                'cpu ${data?.cpuPct?.toStringAsFixed(0) ?? '-'}%  '
                '${data?.phase ?? ''}',
                style: style.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(width: 6),
          _button('Share', Bench.instance.share),
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
      minimumSize: const Size(44, 36),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    ),
    child: Text(label),
  );
}
