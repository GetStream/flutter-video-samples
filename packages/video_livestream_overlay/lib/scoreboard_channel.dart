import 'package:flutter/services.dart';

/// Bridges the Dart side of the app with the native scoreboard filter in
/// `MainActivity.kt` / `AppDelegate.swift`. The filter itself lives natively so
/// it can hook into WebRTC's `ProcessorProvider` and burn the overlay into the
/// outgoing publisher video.
class ScoreboardChannel {
  static const _platform = MethodChannel(
    'io.getstream.video_livestream_overlay.channel',
  );

  /// Registers the scoreboard filter with WebRTC's native processor provider.
  ///
  /// Must be called before applying the filter to a track via
  /// `StreamVideoEffectsManager.applyCustomEffect('scoreboard', ...)`.
  Future<void> registerScoreboardEffect() async {
    await _platform.invokeMethod('registerScoreboardEffect');
  }

  /// Pushes a (partial) update of the scoreboard state to the native filter.
  Future<void> updateScoreboardState({
    String? homeScore,
    String? awayScore,
    String? clockLabel,
    bool? mirror,
  }) async {
    final args = <String, dynamic>{};
    if (homeScore != null) args['homeScore'] = homeScore;
    if (awayScore != null) args['awayScore'] = awayScore;
    if (clockLabel != null) args['clockLabel'] = clockLabel;
    if (mirror != null) args['mirror'] = mirror;
    await _platform.invokeMethod('updateScoreboardState', args);
  }
}

/// Local Dart-side mirror of the scoreboard state owned by the native filter.
/// Held as a singleton so the settings dialog re-opens with the last applied
/// values and so the very first rendered frame (right after the filter is
/// registered) already reflects the dialog's values instead of the native
/// defaults.
class ScoreboardConfig {
  ScoreboardConfig._();
  static final ScoreboardConfig instance = ScoreboardConfig._();

  String homeScore = '0';
  String awayScore = '0';

  int clockSeconds = 0;
  bool clockRunning = false;

  /// Pre-flip the burned-in overlay horizontally.
  ///
  /// Defaults to `false` because the sample joins calls with `MirrorMode.off`
  /// on the camera, which disables the render-time selfie mirror. With both
  /// off, the overlay reads correctly on the local preview, remote
  /// participants and HLS/RTMP egress.
  ///
  /// Only enable this if you have re-enabled the local selfie mirror and want
  /// the overlay to look right on your own screen (at the cost of reading
  /// backwards to remote viewers).
  bool mirror = false;

  String get clockLabel {
    final minutes = (clockSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (clockSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
