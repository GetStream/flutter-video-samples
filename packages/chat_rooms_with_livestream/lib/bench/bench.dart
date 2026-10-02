import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' as chat;
import 'package:stream_video_flutter/stream_video_flutter.dart' as video;

import '../models/app_user.dart';
import 'load_phases.dart';
import 'native_calls.dart';
import 'rtc_digest.dart';

/// Benchmark mode: records what the app, the SDKs and the device are doing
/// once a second into a JSON-lines file, for load tests against a livestream.
///
/// Off unless the app is built with `--dart-define=STREAM_BENCH=true`. When
/// off, every entry point is a no-op and nothing is subscribed, so the sample
/// behaves exactly as documented.
///
/// Build in profile mode - debug-mode frame and CPU numbers are meaningless:
///
/// ```bash
/// flutter run --profile --dart-define-from-file=bench_env.json \
///   --dart-define=STREAM_BENCH=true
/// ```
///
/// ## File format
///
/// One JSON object per line; `t` is the line type and `ms` milliseconds since
/// recording started (monotonic, use it to align lines). Line types:
///
/// - `meta`    - first line: device, build mode, display, dart-defines.
/// - `session` - the signed-in user.
/// - `s`       - 1 Hz sample: frames, event-loop lag, memory, CPU, thermal,
///               battery, per-call state and event rates, chat event rates.
/// - `rtc`     - every SDK stats report (~2 s) per call: publisher and
///               subscriber bitrate/fps/resolution/loss/jitter/freezes as
///               deltas over the window.
/// - `mark`    - a timestamped label: app events (joined, went live, ...)
///               and load changes detected from the participant count
///               (`ramp_start`, `plateau`, `load_up`/`load_down` - see
///               [LoadPhases]). Nothing needs tapping during a run.
/// - `status`  - call status / chat connection changes.
/// - `life`    - app lifecycle changes and memory-pressure warnings.
/// - `log`     - SDK warnings and errors (rate-limited).
/// - `native`  - a platform-channel call whose round trip took at least
///               [NativeCallTimer.slowMs]: channel, method, start and duration
///               (rate-limited). Needs [BenchBinding].
/// - `stall`   - the Dart event loop was blocked for at least 100 ms: how long,
///               and the native calls running during it. On iOS and Android
///               Dart shares the main thread, so a native call listed here is
///               the first suspect.
///
/// `lib/bench/README.md` covers running a test and pulling the file off.
class Bench {
  Bench._();

  /// Mobile only: the recording is written with `dart:io`, which web lacks.
  static const enabled = bool.fromEnvironment('STREAM_BENCH') && !kIsWeb;
  static final instance = Bench._();

  static const _channel = MethodChannel('creator_rooms/bench');
  static const _sampleInterval = Duration(seconds: 1);
  static const _loopTick = Duration(milliseconds: 50);
  static const _maxLogsPerSample = 20;
  static const _maxNativePerSample = 20;
  static const _stallMs = 100;

  /// What the overlay shows. Updated once per sample.
  final overlay = ValueNotifier<BenchOverlayData?>(null);

  final _clock = Stopwatch();
  IOSink? _sink;
  File? _file;
  // An IOSink throws on writes while a flush is pending, so lines written
  // during a flush wait here.
  Future<void>? _flushing;
  final _pending = <String>[];

  final _frames = <FrameTiming>[];
  final _loopLagsMs = <double>[];
  Stopwatch? _loopWatch;
  double _frameBudgetMs = 1000 / 60;

  final _calls = <String, _CallProbe>{};
  final _channels = <String, chat.Channel>{};
  final _chatEvents = <String, int>{};
  String? _chatWs;

  final _subscriptions = <StreamSubscription<Object?>>[];
  final _timers = <Timer>[];
  _MemoryPressureObserver? _memoryObserver;

  double? _prevCpuMs;
  int? _prevCpuAtMs;
  var _sampleCount = 0;
  var _logsThisSample = 0;
  var _logsDropped = 0;
  var _nativeThisSample = 0;
  var _nativeDropped = 0;
  var _sampling = false;

  String? get filePath => _file?.path;

  /// Opens the output file and starts sampling. Call once, before `runApp`'s
  /// first frame, with the app's single chat client.
  Future<void> start({required chat.StreamChatClient chatClient}) async {
    if (!enabled || _sink != null) return;
    _clock.start();

    final dir = await _outputDir();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    _file = File('${dir.path}/bench-$stamp.jsonl');
    _sink = _file!.openWrite(mode: FileMode.append);

    final display = PlatformDispatcher.instance.displays.firstOrNull;
    if (display != null && display.refreshRate > 0) {
      _frameBudgetMs = 1000 / display.refreshRate;
    }

    _write('meta', {
      'ts': DateTime.now().toUtc().toIso8601String(),
      'build': kReleaseMode
          ? 'release'
          : kProfileMode
          ? 'profile'
          : 'debug',
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'dart': Platform.version,
      'device': await _invoke('info'),
      'display': {
        'refreshHz': display?.refreshRate,
        'w': display?.size.width,
        'h': display?.size.height,
        'dpr': display?.devicePixelRatio,
      },
      'frameBudgetMs': _round(_frameBudgetMs),
      'sampleIntervalMs': _sampleInterval.inMilliseconds,
      'defines': {
        'STREAM_API_KEY': const String.fromEnvironment('STREAM_API_KEY'),
        'STREAM_BENCH_CALL_ID': const String.fromEnvironment(
          'STREAM_BENCH_CALL_ID',
        ),
      },
    });

    SchedulerBinding.instance.addTimingsCallback(_frames.addAll);

    // Only times anything when main() installed BenchBinding.
    final nativeCalls = NativeCallTimer.instance;
    nativeCalls.now = () => _clock.elapsedMilliseconds;
    nativeCalls.onSlowCall = _onSlowNativeCall;

    _loopWatch = Stopwatch()..start();
    _timers
      ..add(Timer.periodic(_loopTick, (_) => _onLoopTick()))
      ..add(Timer.periodic(_sampleInterval, (_) => unawaited(_sample())));

    _subscriptions
      ..add(
        chatClient.on().listen(
          (e) => _chatEvents[e.type] = (_chatEvents[e.type] ?? 0) + 1,
        ),
      )
      ..add(
        chatClient.wsConnectionStatusStream.listen((s) {
          _chatWs = s.name;
          _write('status', {'source': 'chat_ws', 'status': s.name});
        }),
      );

    // Registers itself with the binding, which keeps it alive.
    AppLifecycleListener(
      onStateChange: (state) {
        _write('life', {'state': state.name});
        if (state == AppLifecycleState.paused) unawaited(_flush());
      },
    );
    _memoryObserver = _MemoryPressureObserver(
      () => _write('life', {'state': 'memory_pressure'}),
    );
    WidgetsBinding.instance.addObserver(_memoryObserver!);

    debugPrint('[bench] recording to ${_file!.path}');
  }

  /// Video client options that route SDK warnings and errors into the file.
  video.StreamVideoOptions? videoOptions() => enabled
      ? video.StreamVideoOptions(
          logPriority: video.Priority.warning,
          logHandlerFunction: _videoLog,
        )
      : null;

  /// Chat log handler that routes warnings and errors into the file.
  void chatLog(chat.LogRecord record) {
    chat.StreamChatClient.defaultLogHandler(record);
    if (record.level < chat.Level.WARNING) return;
    _log(
      'chat',
      record.level.name,
      record.loggerName,
      record.message,
      record.error,
    );
  }

  void session(AppUser user) =>
      _write('session', {'userId': user.id, 'appRole': user.role.name});

  /// Starts following [call]. [role] is `host` or `viewer`.
  void attachCall(video.Call call, {required String role}) {
    if (!enabled || _sink == null) return;
    detachCall(call);
    _calls[call.id] = _CallProbe(this, call, role)..start();
    mark('${role}_attach', {'callId': call.id});
  }

  void detachCall(video.Call call) {
    final probe = _calls.remove(call.id);
    if (probe == null) return;
    probe.stop();
    mark('${probe.role}_detach', {'callId': call.id});
  }

  /// Follows a chat channel's loaded-message and watcher counts.
  void attachChannel(chat.Channel channel) {
    if (!enabled || channel.cid == null) return;
    _channels[channel.cid!] = channel;
  }

  void detachChannel(chat.Channel channel) => _channels.remove(channel.cid);

  /// Writes a timestamped label. Also drops an instant event on the Dart
  /// timeline, so a DevTools trace recorded alongside lines up with the file.
  void mark(String label, [Map<String, Object?> data = const {}]) {
    if (!enabled || _sink == null) return;
    developer.Timeline.instantSync('bench:$label');
    _write('mark', {'label': label, ...data});
  }

  /// Flushes and opens the share sheet for the current file.
  Future<void> share() async {
    final file = _file;
    if (file == null) return;
    await _flush();
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'Benchmark recording'),
    );
  }

  // ---------------------------------------------------------------------------

  void _videoLog(
    video.Priority priority,
    String tag,
    video.MessageBuilder message, [
    Object? error,
    StackTrace? stk,
  ]) {
    if (priority.level < video.Priority.warning.level) return;
    _log('video', priority.name, tag, message(), error);
  }

  void _log(
    String sdk,
    String level,
    String tag,
    String message,
    Object? error,
  ) {
    if (_sink == null) return;
    if (_logsThisSample >= _maxLogsPerSample) {
      _logsDropped++;
      return;
    }
    _logsThisSample++;
    _write('log', {
      'sdk': sdk,
      'level': level,
      'tag': tag,
      'msg': message.length > 500 ? '${message.substring(0, 500)}…' : message,
      if (error != null) 'error': '$error',
    });
  }

  void _onSlowNativeCall(Map<String, Object?> call) {
    if (_nativeThisSample >= _maxNativePerSample) {
      _nativeDropped++;
      return;
    }
    _nativeThisSample++;
    _write('native', call);
  }

  void _onLoopTick() {
    final watch = _loopWatch!;
    final lag = watch.elapsedMicroseconds / 1000 - _loopTick.inMilliseconds;
    watch.reset();
    _loopLagsMs.add(lag < 0 ? 0 : lag);
    if (lag >= _stallMs) _onStall(lag);
  }

  /// Written as soon as the event loop runs again, so the native calls still
  /// in flight - or just finished - are the ones that overlapped the block.
  void _onStall(double lagMs) {
    final nowMs = _clock.elapsedMilliseconds;
    // The tick was due `_loopTick` after the previous one, and ran `lagMs`
    // late: the loop was blocked somewhere in that window.
    final fromMs = nowMs - lagMs.round() - _loopTick.inMilliseconds;
    _write('stall', {
      'lagMs': _round(lagMs),
      'fromMs': fromMs,
      'native': NativeCallTimer.instance.callsDuring(fromMs, nowMs),
    });
  }

  Future<void> _sample() async {
    // A slow platform-channel round trip must not stack samples up.
    if (_sampling) return;
    _sampling = true;
    try {
      _sampleCount++;
      final nowMs = _clock.elapsedMilliseconds;
      final frames = List.of(_frames);
      _frames.clear();
      final lags = List.of(_loopLagsMs);
      _loopLagsMs.clear();

      final device = await _invoke('sample', {
        // PSS walks the process's memory maps; once every 10 s is plenty.
        'pss': _sampleCount % 10 == 1,
      });
      final cpuMs = (device?['cpuTimeMs'] as num?)?.toDouble();
      double? cpuPct;
      if (cpuMs != null && _prevCpuMs != null && _prevCpuAtMs != null) {
        final wall = nowMs - _prevCpuAtMs!;
        if (wall > 0) cpuPct = _round((cpuMs - _prevCpuMs!) / wall * 100);
      }
      _prevCpuMs = cpuMs;
      _prevCpuAtMs = nowMs;
      device?.remove('cpuTimeMs');
      device?.removeWhere((_, v) => v == null);
      device?.updateAll((_, v) => v is double ? _round(v) : v);

      final calls = [for (final p in _calls.values) p.sample()];
      final chatEvents = Map.of(_chatEvents);
      _chatEvents.clear();

      final ui = _frameSummary(frames);
      final native = NativeCallTimer.instance.takeSample();
      _write('s', {
        'ui': ui,
        'loop': {
          'lagP95Ms': _round(_percentile(lags, 0.95)),
          'lagMaxMs': _round(lags.fold(0.0, (a, b) => a > b ? a : b)),
        },
        'mem': {'rssMb': _round(ProcessInfo.currentRss / 1048576)},
        'dev': {'cpuPct': cpuPct, ...?device},
        if (calls.isNotEmpty) 'calls': calls,
        'chat': {
          'ws': _chatWs,
          'events': chatEvents,
          if (_channels.isNotEmpty)
            'channels': [
              for (final c in _channels.values)
                {
                  'cid': c.cid,
                  'loaded': c.state?.messages.length,
                  'pinned': c.state?.pinnedMessages.length,
                  'watchers': c.state?.watcherCount,
                  'members': c.memberCount,
                },
            ],
        },
        if ((native['calls'] as int) > 0 || native.containsKey('inFlight'))
          'native': native,
        if (_logsDropped > 0) 'logsDropped': _logsDropped,
        if (_nativeDropped > 0) 'nativeDropped': _nativeDropped,
      });
      _logsThisSample = 0;
      _logsDropped = 0;
      _nativeThisSample = 0;
      _nativeDropped = 0;
      await _flush();

      overlay.value = BenchOverlayData(
        elapsed: Duration(milliseconds: nowMs),
        fps: ui['frames'] as int,
        jank: ui['jank'] as int,
        cpuPct: cpuPct,
        participants: calls.isEmpty ? null : calls.first['load'] as int?,
        role: calls.isEmpty ? null : calls.first['role'] as String?,
        phase: calls.isEmpty ? null : calls.first['phase'] as String?,
      );
    } finally {
      _sampling = false;
    }
  }

  Map<String, Object?> _frameSummary(List<FrameTiming> frames) {
    double ms(Duration d) => d.inMicroseconds / 1000;
    final build = frames.map((f) => ms(f.buildDuration)).toList();
    final raster = frames.map((f) => ms(f.rasterDuration)).toList();
    final total = frames.map((f) => ms(f.totalSpan)).toList();
    final budget = _frameBudgetMs;
    return {
      'frames': frames.length,
      // A frame is janky when either thread overran the vsync budget.
      'jank': frames
          .where(
            (f) =>
                ms(f.buildDuration) > budget || ms(f.rasterDuration) > budget,
          )
          .length,
      'jank4x': frames.where((f) => ms(f.totalSpan) > budget * 4).length,
      if (frames.isNotEmpty) ...{
        'buildP50': _round(_percentile(build, 0.5)),
        'buildP90': _round(_percentile(build, 0.9)),
        'buildMax': _round(_percentile(build, 1)),
        'rasterP50': _round(_percentile(raster, 0.5)),
        'rasterP90': _round(_percentile(raster, 0.9)),
        'rasterMax': _round(_percentile(raster, 1)),
        'totalP90': _round(_percentile(total, 0.9)),
        'totalMax': _round(_percentile(total, 1)),
      },
    };
  }

  void _write(String type, Map<String, Object?> data) {
    final sink = _sink;
    if (sink == null) return;
    final line = jsonEncode({
      't': type,
      'ms': _clock.elapsedMilliseconds,
      ...data,
    });
    if (_flushing != null) {
      _pending.add(line);
    } else {
      sink.writeln(line);
    }
  }

  Future<void> _flush() async {
    final sink = _sink;
    if (sink == null) return;
    if (_flushing case final flushing?) return flushing;
    final flushing = _flushing = sink.flush();
    try {
      await flushing;
    } finally {
      _flushing = null;
      _pending
        ..forEach(sink.writeln)
        ..clear();
    }
  }

  Future<Map<String, Object?>?> _invoke(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        method,
        args,
      );
      return result;
    } on PlatformException catch (_) {
      return null;
    } on MissingPluginException catch (_) {
      return null;
    }
  }

  /// Android: app-specific external storage, so `adb pull` works on a
  /// non-debuggable profile build. iOS: Documents.
  static Future<Directory> _outputDir() async {
    final base = Platform.isAndroid
        ? await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory()
        : await getApplicationDocumentsDirectory();
    return Directory('${base.path}/bench').create(recursive: true);
  }
}

/// Everything recorded about one call the device is in.
class _CallProbe {
  _CallProbe(this.bench, this.call, this.role);

  final Bench bench;
  final video.Call call;
  final String role;

  final _subscriptions = <StreamSubscription<Object?>>[];
  final _events = <String, int>{};
  final _publisher = RtcDigest();
  final _subscriber = RtcDigest();
  final _attachedAt = DateTime.now();
  final _load = LoadPhases();
  var _emits = 0;
  var _maxParticipants = 0;
  String? _status;
  bool? _backstage;
  var _firstPublishFrame = false;
  var _firstVideoFrame = false;

  void start() {
    _subscriptions
      ..add(
        call.state.valueStream.listen((state) {
          _emits++;
          final count = state.callParticipants.length;
          if (count > _maxParticipants) _maxParticipants = count;

          final status = state.status.runtimeType.toString().replaceFirst(
            'CallStatus',
            '',
          );
          if (status != _status) {
            _status = status;
            bench._write('status', {
              'source': 'call',
              'callId': call.id,
              'role': role,
              'status': status,
            });
          }
          if (state.isBackstage != _backstage) {
            final wasSet = _backstage != null;
            _backstage = state.isBackstage;
            if (wasSet || !state.isBackstage) {
              bench.mark(state.isBackstage ? 'backstage' : 'live', {
                'callId': call.id,
              });
            }
          }
        }),
      )
      ..add(
        call.callEvents.listen((event) {
          final type = event.runtimeType.toString();
          _events[type] = (_events[type] ?? 0) + 1;
        }),
      )
      ..add(call.stats.listen(_onStats));
  }

  void stop() {
    for (final s in _subscriptions) {
      unawaited(s.cancel());
    }
    _subscriptions.clear();
  }

  void _onStats(
    ({
      video.PeerConnectionStatsBundle publisherStatsBundle,
      video.PeerConnectionStatsBundle subscriberStatsBundle,
    })
    stats,
  ) {
    final pub = _publisher.digest(stats.publisherStatsBundle.raw);
    final sub = _subscriber.digest(stats.subscriberStatsBundle.raw);
    bench._write('rtc', {
      'callId': call.id,
      'role': role,
      if (pub.isNotEmpty) 'pub': pub,
      if (sub.isNotEmpty) 'sub': sub,
    });

    final sinceAttach = DateTime.now().difference(_attachedAt).inMilliseconds;
    if (!_firstPublishFrame &&
        (pub['outVideo'] as List?)?.any((v) => (v['fps'] ?? 0) > 0) == true) {
      _firstPublishFrame = true;
      bench.mark('first_publish_frame', {'sinceAttachMs': sinceAttach});
    }
    if (!_firstVideoFrame &&
        (sub['inVideo'] as List?)?.any(
              // The first report has no delta yet, so also accept fps.
              (v) => (v['framesDecodedD'] ?? 0) > 0 || (v['fps'] ?? 0) > 0,
            ) ==
            true) {
      _firstVideoFrame = true;
      bench.mark('first_video_frame', {'sinceAttachMs': sinceAttach});
    }
  }

  Map<String, Object?> sample() {
    final state = call.state.value;

    // What a UI selector pays per state emission: `otherParticipants` filters
    // the full participant list. Timed once per sample, not per emission, so
    // the benchmark does not add the cost it is measuring.
    final watch = Stopwatch()..start();
    final others = state.otherParticipants.length;
    final othersUs = watch.elapsedMicroseconds;

    // Either count can lag the other, so the larger is the load right now.
    final load = state.participantCount > state.callParticipants.length
        ? state.participantCount
        : state.callParticipants.length;
    for (final (label, data) in _load.add(load)) {
      bench.mark(label, {'callId': call.id, ...data});
    }

    final result = <String, Object?>{
      'callId': call.id,
      'role': role,
      'status': _status,
      'backstage': state.isBackstage,
      'load': load,
      'phase': _load.phase,
      // Server-side totals, independent of how many participants the client
      // actually holds in memory.
      'participantCount': state.participantCount,
      'anonymousCount': state.anonymousParticipantCount,
      // Participants materialised in client state.
      'participants': state.callParticipants.length,
      'participantsMax': _maxParticipants,
      'others': others,
      'othersUs': othersUs,
      'members': state.callMembers.length,
      'stateEmits': _emits,
      'events': Map.of(_events),
      'videoOn': state.localParticipant?.isVideoEnabled,
      'audioOn': state.localParticipant?.isAudioEnabled,
    };
    _emits = 0;
    _maxParticipants = state.callParticipants.length;
    _events.clear();
    return result;
  }
}

class _MemoryPressureObserver with WidgetsBindingObserver {
  _MemoryPressureObserver(this.onPressure);

  final VoidCallback onPressure;

  @override
  void didHaveMemoryPressure() => onPressure();
}

class BenchOverlayData {
  const BenchOverlayData({
    required this.elapsed,
    required this.fps,
    required this.jank,
    required this.cpuPct,
    required this.participants,
    required this.role,
    required this.phase,
  });

  final Duration elapsed;
  final int fps;
  final int jank;
  final double? cpuPct;
  final int? participants;
  final String? role;
  final String? phase;
}

double _percentile(List<double> values, double p) {
  if (values.isEmpty) return 0;
  final sorted = List.of(values)..sort();
  final index = ((sorted.length - 1) * p).round();
  return sorted[index];
}

double _round(double v) => (v * 100).roundToDouble() / 100;
