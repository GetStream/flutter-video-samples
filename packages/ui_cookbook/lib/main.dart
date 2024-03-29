import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:ui_cookbook/samples/audio_indicator.dart';
import 'package:ui_cookbook/samples/network_quality_indicator.dart';
import 'package:ui_cookbook/samples/permissions_request_sample.dart';
import 'package:ui_cookbook/samples/reactions_sample.dart';

import 'env/env.dart';
import 'samples/participant_list.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  /// Initialize Stream Video SDK.
  StreamVideo.init(
    Env.streamVideoApiKey,
    logPriority: Priority.info,
  );

  await StreamVideo.instance.connectUser(
    const UserInfo(
      id: Env.sampleUserId00,
      role: Env.sampleUserRole00,
      name: Env.sampleUserName00,
      image: Env.sampleUserImage00,
    ),
    Env.sampleUserVideoToken00,
  );

  runApp(const UICookbook());
}

class UICookbook extends StatelessWidget {
  const UICookbook({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UI Cookbook',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});

  final _chars = 'abcdefghijklmnopqrstuvwxyz1234567890';
  final _rnd = Random();

  Future<Call> generateCall(String type, String id) async {
    final call = StreamVideo.instance.makeCall(
      type: type,
      id: id,
    );
    await call.getOrCreateCall();

    return call;
  }

  String generateAlphanumericString(int length) => String.fromCharCodes(
        Iterable.generate(
          length,
          (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UI Cookbook'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OptionButton(
            onPressed: () async {
              final call = await generateCall(
                'default',
                generateAlphanumericString(10),
              );

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) {
                    return ParticipantListScreen(
                      call: call,
                    );
                  },
                ),
              );
            },
            label: 'Participant List',
          ),
          OptionButton(
            onPressed: () async {
              final call = await generateCall(
                'audio_room',
                generateAlphanumericString(10),
              );

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) {
                    return PermissionRequestsExample(
                      call: call,
                    );
                  },
                ),
              );
            },
            label: 'Permission Requests',
          ),
          OptionButton(
            onPressed: () async {
              final call = await generateCall(
                'default',
                generateAlphanumericString(10),
              );

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) {
                    return ReactionsExample(
                      call: call,
                    );
                  },
                ),
              );
            },
            label: 'Reactions',
          ),
          OptionButton(
            onPressed: () async {
              final call = await generateCall(
                'default',
                generateAlphanumericString(10),
              );

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) {
                    return AudioIndicatorExample(
                      call: call,
                    );
                  },
                ),
              );
            },
            label: 'Audio Indicator',
          ),
          OptionButton(
            onPressed: () async {
              final call = await generateCall(
                'default',
                generateAlphanumericString(10),
              );

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) {
                    return NetworkQualityIndicatorExample(
                      call: call,
                    );
                  },
                ),
              );
            },
            label: 'Network Quality Indicator',
          ),
        ],
      ),
    );
  }
}

class OptionButton extends StatelessWidget {
  const OptionButton({super.key, required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
