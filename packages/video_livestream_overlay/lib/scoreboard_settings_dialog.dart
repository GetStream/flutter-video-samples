import 'package:flutter/material.dart';

import 'scoreboard_channel.dart';

/// Shows a modal dialog that lets the user edit the scoreboard state and
/// pushes updates to the native filter via the method channel.
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

  late final TextEditingController _homeLabel;
  late final TextEditingController _awayLabel;
  late final TextEditingController _homeScore;
  late final TextEditingController _awayScore;
  late final TextEditingController _period;
  late final TextEditingController _clock;
  late bool _mirror;

  @override
  void initState() {
    super.initState();
    _homeLabel = TextEditingController(text: _config.homeLabel);
    _awayLabel = TextEditingController(text: _config.awayLabel);
    _homeScore = TextEditingController(text: _config.homeScore);
    _awayScore = TextEditingController(text: _config.awayScore);
    _period = TextEditingController(text: _config.periodLabel);
    _clock = TextEditingController(text: _config.clockLabel);
    _mirror = _config.mirror;
  }

  @override
  void dispose() {
    _homeLabel.dispose();
    _awayLabel.dispose();
    _homeScore.dispose();
    _awayScore.dispose();
    _period.dispose();
    _clock.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    _config
      ..homeLabel = _homeLabel.text
      ..awayLabel = _awayLabel.text
      ..homeScore = _homeScore.text
      ..awayScore = _awayScore.text
      ..periodLabel = _period.text
      ..clockLabel = _clock.text
      ..mirror = _mirror;

    await _channel.updateScoreboardState(
      homeLabel: _config.homeLabel,
      awayLabel: _config.awayLabel,
      homeScore: _config.homeScore,
      awayScore: _config.awayScore,
      periodLabel: _config.periodLabel,
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
                    controller: _homeLabel,
                    decoration: _fieldDecoration('Home team'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _homeScore,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration('Score'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _awayLabel,
                    decoration: _fieldDecoration('Away team'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _awayScore,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration('Score'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _period,
                    decoration: _fieldDecoration('Period'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _clock,
                    decoration: _fieldDecoration('Clock'),
                  ),
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
        FilledButton(
          onPressed: _apply,
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
