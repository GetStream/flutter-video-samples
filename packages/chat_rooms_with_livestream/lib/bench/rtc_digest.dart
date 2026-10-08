/// Turns the SDK's raw WebRTC `getStats()` reports into per-window rates.
///
/// The raw reports are cumulative counters (bytes sent since the start, frames
/// decoded since the start, ...), which say nothing about "now" on their own.
/// [RtcDigest] keeps the previous report per stats id and emits the delta over
/// the window between two reports - bitrate, fps, loss, freezes - which is what
/// shows up as a step change when the load ramps.
///
/// Only the fields useful for a publish/subscribe quality verdict are kept; the
/// full raw dump would be several KB every two seconds.
class RtcDigest {
  final Map<String, Map<String, dynamic>> _previous = {};
  DateTime? _previousAt;

  Map<String, dynamic> digest(List<Map<String, dynamic>> raw) {
    final now = DateTime.now();
    final dtS = _previousAt == null
        ? null
        : now.difference(_previousAt!).inMicroseconds / 1e6;

    final byId = {for (final r in raw) r['id'] as String? ?? '': r};
    final out = <String, dynamic>{};

    final outboundVideo = <Map<String, dynamic>>[];
    final inboundVideo = <Map<String, dynamic>>[];
    final inboundAudio = <Map<String, dynamic>>[];
    final remoteInbound = <Map<String, dynamic>>[];
    double outboundAudioKbps = 0;
    var hasOutboundAudio = false;
    Map<String, dynamic>? videoSource;

    for (final report in raw) {
      final id = report['id'] as String? ?? '';
      final prev = _previous[id];
      final kind = report['kind'] ?? report['mediaType'];

      switch (report['type']) {
        case 'outbound-rtp' when kind == 'video':
          final frames = _delta(report, prev, 'framesEncoded');
          outboundVideo.add(
            _compact({
              'rid': report['rid'],
              'active': report['active'],
              'w': _num(report['frameWidth']),
              'h': _num(report['frameHeight']),
              'fps': _num(report['framesPerSecond']),
              'kbps': _rateKbps(report, prev, 'bytesSent', dtS),
              'targetKbps': _div(_num(report['targetBitrate']), 1000),
              'retxKbps': _rateKbps(
                report,
                prev,
                'retransmittedBytesSent',
                dtS,
              ),
              // Why the encoder is not sending more: cpu, bandwidth or none.
              'qlr': report['qualityLimitationReason'],
              'encMsPerFrame': _perFrameMs(
                report,
                prev,
                'totalEncodeTime',
                frames,
              ),
              'nack': _delta(report, prev, 'nackCount'),
              'pli': _delta(report, prev, 'pliCount'),
              'fir': _delta(report, prev, 'firCount'),
              'encoder': report['encoderImplementation'],
              // What the encoder actually produces for an SVC request: null
              // here with a requested L3T3_KEY is the single-layer failure.
              'scalabilityMode': report['scalabilityMode'],
              // Frames in this window; a steady 30 fps source with fewer
              // encoded frames is an encoder gap, the kind every viewer sees
              // as a freeze.
              'framesEncodedD': frames,
              'keyFramesD': _delta(report, prev, 'keyFramesEncoded'),
              'resChanges': _num(report['qualityLimitationResolutionChanges']),
              'qlBwSecD': _nestedDelta(
                report,
                prev,
                'qualityLimitationDurations',
                'bandwidth',
              ),
              'qlCpuSecD': _nestedDelta(
                report,
                prev,
                'qualityLimitationDurations',
                'cpu',
              ),
            }),
          );
        case 'media-source' when kind == 'video':
          // The frames the camera delivered to the encoder: the size before
          // any encoder adaptation, and the capture rate to compare with
          // framesEncodedD.
          videoSource = _compact({
            'w': _num(report['width']),
            'h': _num(report['height']),
            'fps': _num(report['framesPerSecond']),
            'framesD': _delta(report, prev, 'frames'),
          });
        case 'outbound-rtp' when kind == 'audio':
          hasOutboundAudio = true;
          outboundAudioKbps += _rateKbps(report, prev, 'bytesSent', dtS) ?? 0;
        case 'remote-inbound-rtp':
          // What the SFU reports back about our outgoing streams.
          remoteInbound.add(
            _compact({
              'kind': kind,
              'rttMs': _mul(_num(report['roundTripTime']), 1000),
              'jitterMs': _mul(_num(report['jitter']), 1000),
              'fractionLost': _num(report['fractionLost']),
              'lostD': _delta(report, prev, 'packetsLost'),
            }),
          );
        case 'inbound-rtp' when kind == 'video':
          final frames = _delta(report, prev, 'framesDecoded');
          final emitted = _delta(report, prev, 'jitterBufferEmittedCount');
          final jbDelay = _delta(report, prev, 'jitterBufferDelay');
          inboundVideo.add(
            _compact({
              'track': report['trackIdentifier'],
              'w': _num(report['frameWidth']),
              'h': _num(report['frameHeight']),
              'fps': _num(report['framesPerSecond']),
              'kbps': _rateKbps(report, prev, 'bytesReceived', dtS),
              'lossPct': _lossPct(report, prev),
              'jitterMs': _mul(_num(report['jitter']), 1000),
              'jbMs': emitted != null && emitted > 0 && jbDelay != null
                  ? _round(jbDelay / emitted * 1000)
                  : null,
              'decMsPerFrame': _perFrameMs(
                report,
                prev,
                'totalDecodeTime',
                frames,
              ),
              'framesDecodedD': frames,
              'framesDroppedD': _delta(report, prev, 'framesDropped'),
              'freezesD': _delta(report, prev, 'freezeCount'),
              'freezeSecD': _delta(report, prev, 'totalFreezesDuration'),
              'pausesD': _delta(report, prev, 'pauseCount'),
              'keyFramesD': _delta(report, prev, 'keyFramesDecoded'),
              'nack': _delta(report, prev, 'nackCount'),
              'pli': _delta(report, prev, 'pliCount'),
              'decoder': report['decoderImplementation'],
            }),
          );
        case 'inbound-rtp' when kind == 'audio':
          final samples = _delta(report, prev, 'totalSamplesReceived');
          final concealed = _delta(report, prev, 'concealedSamples');
          inboundAudio.add(
            _compact({
              'track': report['trackIdentifier'],
              'kbps': _rateKbps(report, prev, 'bytesReceived', dtS),
              'lossPct': _lossPct(report, prev),
              'jitterMs': _mul(_num(report['jitter']), 1000),
              'concealPct': samples != null && samples > 0 && concealed != null
                  ? _round(concealed / samples * 100)
                  : null,
            }),
          );
      }
    }

    final pair = _selectedPair(raw, byId);
    if (pair != null) {
      out['pair'] = _compact({
        'rttMs': _mul(_num(pair['currentRoundTripTime']), 1000),
        'availOutKbps': _div(_num(pair['availableOutgoingBitrate']), 1000),
        'availInKbps': _div(_num(pair['availableIncomingBitrate']), 1000),
        'sentKbps': _rateKbps(pair, _previous[pair['id']], 'bytesSent', dtS),
        'recvKbps': _rateKbps(
          pair,
          _previous[pair['id']],
          'bytesReceived',
          dtS,
        ),
      });
    }
    if (outboundVideo.isNotEmpty) out['outVideo'] = outboundVideo;
    if (videoSource != null && videoSource.isNotEmpty) out['src'] = videoSource;
    if (hasOutboundAudio) out['outAudioKbps'] = _round(outboundAudioKbps);
    if (remoteInbound.isNotEmpty) out['remote'] = remoteInbound;
    if (inboundVideo.isNotEmpty) out['inVideo'] = inboundVideo;
    if (inboundAudio.isNotEmpty) out['inAudio'] = inboundAudio;

    _previous
      ..clear()
      ..addAll(byId);
    _previousAt = now;
    return out;
  }

  void reset() {
    _previous.clear();
    _previousAt = null;
  }

  static Map<String, dynamic>? _selectedPair(
    List<Map<String, dynamic>> raw,
    Map<String, Map<String, dynamic>> byId,
  ) {
    for (final r in raw) {
      if (r['type'] == 'transport' && r['selectedCandidatePairId'] != null) {
        final pair = byId[r['selectedCandidatePairId']];
        if (pair != null) return pair;
      }
    }
    for (final r in raw) {
      if (r['type'] == 'candidate-pair' &&
          r['state'] == 'succeeded' &&
          (r['nominated'] == true || r['nominated'] == 'true')) {
        return r;
      }
    }
    return null;
  }

  static double? _lossPct(
    Map<String, dynamic> report,
    Map<String, dynamic>? prev,
  ) {
    final lost = _delta(report, prev, 'packetsLost');
    final received = _delta(report, prev, 'packetsReceived');
    if (lost == null || received == null) return null;
    final total = lost + received;
    return total > 0 ? _round(lost / total * 100) : 0;
  }

  static double? _perFrameMs(
    Map<String, dynamic> report,
    Map<String, dynamic>? prev,
    String totalTimeKey,
    double? frames,
  ) {
    final time = _delta(report, prev, totalTimeKey);
    if (time == null || frames == null || frames <= 0) return null;
    return _round(time / frames * 1000);
  }

  static double? _rateKbps(
    Map<String, dynamic> report,
    Map<String, dynamic>? prev,
    String bytesKey,
    double? dtS,
  ) {
    final bytes = _delta(report, prev, bytesKey);
    if (bytes == null || dtS == null || dtS <= 0) return null;
    return _round(bytes * 8 / 1000 / dtS);
  }

  /// Delta of one entry of a nested map such as `qualityLimitationDurations`.
  static double? _nestedDelta(
    Map<String, dynamic> report,
    Map<String, dynamic>? prev,
    String mapKey,
    String key,
  ) {
    final now = report[mapKey];
    final before = prev?[mapKey];
    if (now is! Map || before is! Map) return null;
    final a = _num(now[key]);
    final b = _num(before[key]);
    if (a == null || b == null) return null;
    return _round(a - b);
  }

  static double? _delta(
    Map<String, dynamic> report,
    Map<String, dynamic>? prev,
    String key,
  ) {
    final now = _num(report[key]);
    final before = prev == null ? null : _num(prev[key]);
    if (now == null || before == null) return null;
    return _round(now - before);
  }
}

/// Stats values arrive as num on one platform and String on another.
double? _num(Object? value) => switch (value) {
  num v => v.toDouble(),
  String v => double.tryParse(v),
  _ => null,
};

double? _mul(double? v, double by) => v == null ? null : _round(v * by);
double? _div(double? v, double by) => v == null ? null : _round(v / by);
double _round(double v) => (v * 100).roundToDouble() / 100;

Map<String, dynamic> _compact(Map<String, dynamic> map) =>
    map..removeWhere((_, v) => v == null);
