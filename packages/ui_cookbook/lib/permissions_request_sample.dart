import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

class PermissionRequestsExample extends StatefulWidget {
  const PermissionRequestsExample({super.key, required this.call});

  final Call call;

  @override
  State<PermissionRequestsExample> createState() =>
      _PermissionRequestsExampleState();
}

class _PermissionRequestsExampleState extends State<PermissionRequestsExample> {
  bool canSpeak = false;

  Future<void> startCall() async {
    await widget.call.connect();
    await widget.call.goLive();
    canSpeak = widget.call.state.value.ownCapabilities
        .contains(CallPermission.sendAudio);
  }

  Future<void> endCall() async {
    await widget.call.stopLive();
    await widget.call.end();
  }

  @override
  void initState() {
    super.initState();
    startCall();
    widget.call.onPermissionRequest = (CoordinatorCallPermissionRequestEvent permissionRequestEvent){
      final uid = permissionRequestEvent.user.id;
      final permission = permissionRequestEvent.permissions;
      grantSpeakingPermission(uid);
    };
  }

  @override
  void dispose() {
    endCall();
    super.dispose();
  }

  Future<void> requestSpeakingPermission() async {
    await widget.call.requestPermissions([CallPermission.sendAudio]);
  }

  Future<void> grantSpeakingPermission(String userID) async {
    await widget.call.grantPermissions(
      userId: userID,
      permissions: [CallPermission.sendAudio],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Requests Example'),
        actions: [
          canSpeak
              ? IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.request_page),
                )
              : IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.mic),
                )
        ],
      ),
      body: StreamCallContainer(
        call: widget.call,
      ),
    );
  }
}
