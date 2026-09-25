/// Works out from the participant count alone when the load changes, so the
/// file carries ramp marks without anyone tapping anything on the device.
///
/// Makes no assumption about how the backend adds participants - one batch of
/// 10k, several batches, or a slow trickle all produce the same marks:
///
/// - `ramp_start` - the count starts moving (up or down) after being steady.
/// - `plateau`    - the count has held steady for [_steadyFor] samples after a
///                  ramp; carries the ramp's start/end counts and duration.
///                  It is written once steadiness is confirmed, so it lands
///                  `endedSecondsAgo` after the ramp really ended.
/// - `load_up` / `load_down` - the count crossed one of [_thresholds], so
///                  every run has comparable points ("at 5k") however it ramped.
///
/// Fed once per sample (1 Hz) with the larger of the server-side participant
/// count and the participants the client holds, since either can lag the other.
class LoadPhases {
  static const _thresholds = [
    10,
    50,
    100,
    250,
    500,
    1000,
    2000,
    3000,
    5000,
    7500,
    10000,
    15000,
    20000,
  ];

  /// Samples compared to decide whether the count is moving.
  static const _window = 5;

  /// Consecutive samples without movement before a ramp counts as finished.
  static const _steadyFor = 10;

  final _history = <int>[];
  var _ramping = false;
  var _steady = 0;
  var _rampFrom = 0;
  var _rampStartedAt = 0;
  var _lastMoveAt = 0;
  var _anchor = 0;
  var _samples = 0;
  int? _last;

  /// Current phase, for the overlay.
  String get phase => _ramping ? 'ramping' : 'steady';

  /// Returns the marks this sample produced, as (label, data) pairs.
  List<(String, Map<String, Object?>)> add(int count) {
    _samples++;
    final marks = <(String, Map<String, Object?>)>[];

    final last = _last;
    if (last != null && last != count) {
      for (final t in _thresholds) {
        if (last < t && count >= t) {
          marks.add(('load_up', {'threshold': t, 'participantCount': count}));
        } else if (last >= t && count < t) {
          marks.add(('load_down', {'threshold': t, 'participantCount': count}));
        }
      }
    }
    _last = count;

    _history.add(count);
    if (_history.length > _window + 1) _history.removeAt(0);
    final oldest = _history.first;
    final change = (count - oldest).abs();

    // Relative thresholds, so a +20 blip at 10k is noise but +20 at 30 is not.
    final moving = change >= _max(10, (oldest * 0.02).round());
    // Measured from the last movement rather than sample to sample, so a slow
    // trickle still accumulates into movement instead of reading as steady.
    final moved = (count - _anchor).abs() > _max(3, (_anchor * 0.005).round());

    if (!_ramping && moving) {
      _ramping = true;
      _steady = 0;
      _rampFrom = oldest;
      // The first sample in the window that had already left `oldest`.
      final firstMoved = _history.indexWhere((c) => c != oldest);
      _rampStartedAt = _samples - (_history.length - 1 - firstMoved);
      _lastMoveAt = _samples;
      _anchor = count;
      marks.add((
        'ramp_start',
        {
          'direction': count > oldest ? 'up' : 'down',
          'from': oldest,
          'participantCount': count,
        },
      ));
    } else if (_ramping) {
      if (moved) {
        _steady = 0;
        _lastMoveAt = _samples;
        _anchor = count;
      } else {
        _steady++;
      }
      if (_steady >= _steadyFor) {
        _ramping = false;
        marks.add((
          'plateau',
          {
            'from': _rampFrom,
            'participantCount': count,
            'rampSeconds': _lastMoveAt - _rampStartedAt + 1,
            'endedSecondsAgo': _samples - _lastMoveAt,
          },
        ));
      }
    }
    return marks;
  }

  static int _max(int a, int b) => a > b ? a : b;
}
