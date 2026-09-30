import 'dart:async';
import 'dart:ui' as ui;

import 'package:chat_rooms_with_livestream/bench/native_calls.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replies to each call only when the test completes it.
class _FakeMessenger implements BinaryMessenger {
  final pending = <String, Completer<ByteData?>>{};

  @override
  Future<ByteData?>? send(String channel, ByteData? message) {
    final method = const StandardMethodCodec().decodeMethodCall(message).method;
    return (pending[method] = Completer<ByteData?>()).future;
  }

  void reply(String method) => pending.remove(method)!.complete(null);

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {}

  @override
  // ignore: deprecated_member_use
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? data,
    ui.PlatformMessageResponseCallback? callback,
  ) async {}
}

ByteData _call(String method) =>
    const StandardMethodCodec().encodeMethodCall(MethodCall(method));

void main() {
  late int nowMs;
  late NativeCallTimer timer;
  late _FakeMessenger fake;
  late BinaryMessenger messenger;
  late List<Map<String, Object?>> slow;

  setUp(() {
    nowMs = 0;
    slow = [];
    fake = _FakeMessenger();
    timer = NativeCallTimer.forTesting()
      ..now = (() => nowMs)
      ..onSlowCall = slow.add;
    messenger = timer.wrap(fake);
  });

  test('reports a slow call with its channel, method and duration', () async {
    final reply = messenger.send('FlutterWebRTC.Method', _call('getStats'))!;
    nowMs = 80;
    fake.reply('getStats');
    await reply;

    expect(slow, [
      {
        'channel': 'FlutterWebRTC.Method',
        'method': 'getStats',
        'startMs': 0,
        'durMs': 80,
      },
    ]);
  });

  test('does not report calls under the threshold', () async {
    final reply = messenger.send('FlutterWebRTC.Method', _call('fast'))!;
    nowMs = NativeCallTimer.slowMs - 1;
    fake.reply('fast');
    await reply;

    expect(slow, isEmpty);
    expect(timer.takeSample(), containsPair('calls', 1));
  });

  test('lists calls in flight and just finished during a stall', () async {
    final done = messenger.send('FlutterWebRTC.Method', _call('finished'))!;
    unawaited(messenger.send('FlutterWebRTC.Method', _call('blocking')));
    nowMs = 600;
    fake.reply('finished');
    await done;
    nowMs = 650;

    final calls = timer.callsDuring(0, 650);
    expect(calls, hasLength(2));
    expect(calls, contains(containsPair('method', 'finished')));
    expect(
      calls.firstWhere((c) => c['method'] == 'blocking'),
      allOf(containsPair('inFlight', true), containsPair('ageMs', 650)),
    );
  });

  test('ignores the bench channel and calls made before recording starts', () {
    timer.now = null;
    messenger.send('FlutterWebRTC.Method', _call('early'));
    timer.now = () => nowMs;
    messenger.send('creator_rooms/bench', _call('sample'));

    expect(timer.callsDuring(0, 1000), isEmpty);
  });
}
