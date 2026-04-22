import 'dart:async';

import 'package:flutter/material.dart';

import 'scoreboard_channel.dart';

/// Shows a modal dialog that lets the user edit the scoreboard scores and
/// control the game clock. Pushes updates to the native filter via the method
/// channel.
Future<void> showScoreboardSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ScoreboardSettingsDialog(),
  );
}

class _ScoreboardSettingsDialog extends StatefulWidget {
  const _ScoreboardSettingsDialog();

  @override
  State<_ScoreboardSettingsDialog> createState() =>
      _ScoreboardSettingsDialogState();
}

class _ScoreboardSettingsDialogState extends State<_ScoreboardSettingsDialog> {
  final _channel = ScoreboardChannel();
  final _config = ScoreboardConfig.instance;

  late final TextEditingController _homeScore;
  late final TextEditingController _awayScore;
  late bool _mirror;

  Timer? _displayTimer;

  @override
  void initState() {
    super.initState();
    _homeScore = TextEditingController(text: _config.homeScore);
    _awayScore = TextEditingController(text: _config.awayScore);
    _mirror = _config.mirror;

    if (_config.clockRunning) {
      _startDisplayTimer();
    }
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    _homeScore.dispose();
    _awayScore.dispose();
    super.dispose();
  }

  void _startDisplayTimer() {
    _displayTimer?.cancel();
    _displayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _toggleClock() {
    setState(() {
      _config.clockRunning = !_config.clockRunning;
      if (_config.clockRunning) {
        _startDisplayTimer();
      } else {
        _displayTimer?.cancel();
      }
    });
  }

  void _resetClock() {
    setState(() {
      _config.clockRunning = false;
      _config.clockSeconds = 0;
      _displayTimer?.cancel();
    });
    _channel.updateScoreboardState(clockLabel: _config.clockLabel);
  }

  Future<void> _apply() async {
    _config
      ..homeScore = _homeScore.text
      ..awayScore = _awayScore.text
      ..mirror = _mirror;

    await _channel.updateScoreboardState(
      homeScore: _config.homeScore,
      awayScore: _config.awayScore,
      clockLabel: _config.clockLabel,
      mirror: _config.mirror,
    );

    if (mounted) Navigator.of(context).pop();
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scoreboard settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _homeScore,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration('Home score'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _awayScore,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration('Away score'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Game clock',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _config.clockLabel,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                IconButton.filled(
                  onPressed: _toggleClock,
                  icon: Icon(
                    _config.clockRunning ? Icons.pause : Icons.play_arrow,
                  ),
                  tooltip: _config.clockRunning ? 'Pause' : 'Start',
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _resetClock,
                  icon: const Icon(Icons.replay),
                  tooltip: 'Reset',
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Mirror horizontally'),
              subtitle: const Text(
                'Only needed if local preview mirroring is re-enabled',
              ),
              value: _mirror,
              onChanged: (v) => setState(() => _mirror = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _apply, child: const Text('Apply')),
      ],
    );
  }
}
