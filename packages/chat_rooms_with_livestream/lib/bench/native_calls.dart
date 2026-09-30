import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// App binding for benchmark mode: routes every platform-channel call through
/// [NativeCallTimer], so the recording shows which native calls were slow and
/// which were in flight while the Dart event loop stalled.
///
/// Since Flutter 3.29 Dart runs on the platform main thread, so a native
/// handler that blocks that thread blocks Dart with it. The WebRTC fork's
/// `FlutterWebRTC.Method` channel is the main suspect, and timing it here needs
/// no change to the fork or the SDK.
///
/// Must be the first binding created: call [ensureInitialized] at the top of
/// `main`, in place of `WidgetsFlutterBinding.ensureInitialized`.
class BenchBinding extends WidgetsFlutterBinding {
  BenchBinding._();

  static void ensureInitialized() => BenchBinding._();

  @override
  BinaryMessenger createBinaryMessenger() =>
      NativeCallTimer.instance.wrap(super.createBinaryMessenger());
}

/// Times platform-channel round trips from the Dart side.
///
/// A round trip is not the same as time spent blocking the main thread: an
/// asynchronous handler (such as the fork's queued audio-session calls) replies
/// late without blocking anything. A slow call that overlaps an event-loop
/// stall is the blocking candidate. A slow call with no stall is native work
/// happening off the main thread.
class NativeCallTimer {
  NativeCallTimer._();

  /// A timer separate from [instance], for tests.
  @visibleForTesting
  NativeCallTimer.forTesting();

  static final instance = NativeCallTimer._();

  /// Round trips at least this long are reported one by one.
  static const slowMs = 50;

  /// How long completed calls are kept, to be matched against a stall that
  /// is only noticed once the event loop runs again.
  static const _keepMs = 5000;

  /// The bench's own channel: its sample call waits on the same main thread,
  /// so it would show up in every stall as noise.
  static const _ignored = {'creator_rooms/bench'};

  /// Milliseconds on the recording clock. Null until recording starts; calls
  /// made before that are not timed.
  int Function()? now;

  /// Called once per completed call of at least [slowMs].
  void Function(Map<String, Object?> call)? onSlowCall;

  /// Wraps [inner] so every call sent through it is timed by this timer.
  BinaryMessenger wrap(BinaryMessenger inner) =>
      _TimedBinaryMessenger(inner, this);

  var _nextId = 0;
  final _inFlight = <int, _NativeCall>{};
  final _recent = <_NativeCall>[];

  var _count = 0;
  var _slow = 0;
  _NativeCall? _slowest;

  _NativeCall? _begin(String channel, ByteData? message) {
    final clock = now;
    if (clock == null || _ignored.contains(channel)) return null;
    final call = _NativeCall(_nextId++, channel, message, clock());
    _inFlight[call.id] = call;
    return call;
  }

  void _end(_NativeCall call) {
    final clock = now;
    if (clock == null) return;
    _inFlight.remove(call.id);
    call.endMs = clock();
    _count++;

    final durationMs = call.durationMs!;
    if (durationMs > (_slowest?.durationMs ?? -1)) _slowest = call;
    if (durationMs >= slowMs) {
      _slow++;
      onSlowCall?.call(call.toJson());
    }

    _recent.add(call);
    final cutoff = call.endMs! - _keepMs;
    _recent.removeWhere((c) => c.endMs! < cutoff);
  }

  /// Calls that were running at some point in `[fromMs, toMs]`: still in
  /// flight, or completed inside the window.
  List<Map<String, Object?>> callsDuring(int fromMs, int toMs) => [
    for (final c in _inFlight.values)
      if (c.startMs <= toMs) c.toJson(nowMs: toMs),
    for (final c in _recent)
      if (c.startMs <= toMs && c.endMs! >= fromMs) c.toJson(),
  ];

  /// Per-sample totals, reset on read.
  Map<String, Object?> takeSample() {
    final slowest = _slowest;
    final result = <String, Object?>{
      'calls': _count,
      'slow': _slow,
      if (_inFlight.isNotEmpty) 'inFlight': _inFlight.length,
      if (slowest != null) ...{
        'maxMs': slowest.durationMs,
        'maxCall': slowest.label,
      },
    };
    _count = 0;
    _slow = 0;
    _slowest = null;
    return result;
  }
}

class _NativeCall {
  _NativeCall(this.id, this.channel, this.message, this.startMs);

  final int id;
  final String channel;
  final int startMs;
  int? endMs;

  /// Kept until the method name is needed. Decoding every call up front would
  /// add work to each one; only reported calls are decoded.
  ByteData? message;
  String? _method;

  int? get durationMs => endMs == null ? null : endMs! - startMs;

  String get label {
    final method = this.method;
    return method == null ? channel : '$channel#$method';
  }

  String? get method {
    if (_method != null || message == null) return _method;
    for (final codec in const [StandardMethodCodec(), JSONMethodCodec()]) {
      try {
        _method = codec.decodeMethodCall(message).method;
        break;
      } catch (_) {
        // Not this codec, or not a method call at all (a basic message).
      }
    }
    message = null;
    return _method;
  }

  Map<String, Object?> toJson({int? nowMs}) => {
    'channel': channel,
    if (method != null) 'method': method,
    'startMs': startMs,
    if (durationMs != null)
      'durMs': durationMs
    else ...{
      'inFlight': true,
      if (nowMs != null) 'ageMs': nowMs - startMs,
    },
  };
}

class _TimedBinaryMessenger implements BinaryMessenger {
  _TimedBinaryMessenger(this._inner, this._timer);

  final BinaryMessenger _inner;
  final NativeCallTimer _timer;

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    final call = _timer._begin(channel, message);
    final reply = _inner.send(channel, message);
    if (call == null) return reply;
    if (reply == null) {
      _timer._end(call);
      return null;
    }
    return reply.whenComplete(() => _timer._end(call));
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) =>
      _inner.setMessageHandler(channel, handler);

  @override
  // ignore: deprecated_member_use
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) =>
      // ignore: deprecated_member_use
      _inner.handlePlatformMessage(channel, data, callback);
}
