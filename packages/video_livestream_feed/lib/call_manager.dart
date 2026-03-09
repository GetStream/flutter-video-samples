import 'package:flutter/foundation.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

class CallManager extends ChangeNotifier {
  CallManagerState _state = CallManagerState.idle;

  Call? _currentCall;
  String? _currentCallId;
  int _version = 0;

  bool _disposed = false;

  CallManagerState get state => _state;
  Call? get currentCall => _currentCall;
  String? get currentCallId => _currentCallId;

  /// Immediately switches to [callId].
  ///
  /// Any in-flight connection is abandoned: the previous call is left and a
  /// fresh connection starts without waiting for the old one to finish.
  void switchToCall(String callId) {
    if (_currentCallId == callId && _state != CallManagerState.failure) return;

    final version = ++_version;

    final oldCall = _currentCall;
    _currentCall = null;
    _currentCallId = callId;
    _state = CallManagerState.connecting;
    _safeNotify();

    oldCall?.leave();

    _connectCall(callId, version);
  }

  Future<void> _connectCall(String callId, int version) async {
    final call = StreamVideo.instance.makeCall(
      callType: StreamCallType.liveStream(),
      id: callId,
    );

    _currentCall = call;

    try {
      final getResult = await call.getOrCreate();

      if (_isStale(version, call)) return;
      if (getResult.isFailure) {
        _fail(version);
        return;
      }

      final joinResult = await call.join(
        connectOptions: CallConnectOptions(
          camera: TrackOption.disabled(),
          microphone: TrackOption.disabled(),
        ),
      );

      if (_isStale(version, call)) return;
      if (joinResult.isFailure) {
        _fail(version);
        return;
      }
    } catch (e) {
      if (_isStale(version, call)) return;
      debugPrint('CallManager: connect failed: $e');
      _fail(version);
      return;
    }

    _state = CallManagerState.connected;
    _safeNotify();
  }

  bool _isStale(int version, Call call) {
    if (version != _version || _disposed) {
      call.leave();
      return true;
    }

    return false;
  }

  void _fail(int version) {
    if (version == _version && !_disposed) {
      _state = CallManagerState.failure;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _version++;
    _currentCall?.leave();
    super.dispose();
  }
}

enum CallManagerState { idle, connecting, connected, failure }
