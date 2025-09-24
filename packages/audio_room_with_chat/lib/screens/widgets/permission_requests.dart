import 'package:flutter/material.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';

class PermissionRequests extends StatefulWidget {
  const PermissionRequests({required this.audioRoomCall, super.key});
  final Call audioRoomCall;

  @override
  State<PermissionRequests> createState() => _PermissionRequestsState();
}

class _PermissionRequestsState extends State<PermissionRequests> {
  final List<StreamCallPermissionRequestEvent> _permissionRequests = [];

  @override
  void initState() {
    super.initState();

    widget.audioRoomCall.onPermissionRequest = (permissionRequest) {
      setState(() {
        _permissionRequests.add(permissionRequest);
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    final request = _permissionRequests.first;
    final displayName = request.user.name.isNotEmpty
        ? request.user.name
        : request.user.id;
    final permissions = request.permissions.join(', ');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 18,
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                ),
              ),
              title: Text('$displayName requests'),
              subtitle: Text(permissions),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _permissionRequests.removeAt(0);
                        });
                      },
                      child: const Text(
                        'Deny',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await widget.audioRoomCall.grantPermissions(
                          userId: request.user.id,
                          permissions: request.permissions.toList(),
                        );
                        if (mounted) {
                          setState(() {
                            _permissionRequests.removeAt(0);
                          });
                        }
                      },
                      child: const Text('Allow'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
