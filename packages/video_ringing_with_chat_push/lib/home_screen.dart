import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_ringing_with_chat_push/chat_notifications.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_video_flutter/stream_video_flutter.dart';
import 'package:stream_video_push_notification/stream_video_push_notification.dart';

import 'app_config.dart';
import 'call_screen.dart';
import 'channel_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.onLogout,
  });

  final String userId;
  final String userName;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  bool _isCalling = false;

  String get _otherUserId => widget.userId == AppConfig.user1Id
      ? AppConfig.user2Id
      : AppConfig.user1Id;

  String get _otherUserName => widget.userId == AppConfig.user1Id
      ? AppConfig.user2Name
      : AppConfig.user1Name;

  Future<void> _startRingingCall() async {
    if (_isCalling) return;
    setState(() => _isCalling = true);

    try {
      final call = StreamVideo.instance.makeCall(
        callType: StreamCallType.defaultType(),
        id: const Uuid().v4(),
      );

      await call.getOrCreate(
        memberIds: [_otherUserId],
        ringing: true,
        video: true,
      );

      if (mounted) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => CallScreen(call: call)));
      }
    } catch (e, stk) {
      debugPrint('Error starting ringing call: $e');
      debugPrint(stk.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start call: $e')));
      }
    } finally {
      if (mounted) setState(() => _isCalling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: [
          _CallTab(
            userId: widget.userId,
            userName: widget.userName,
            otherUserName: _otherUserName,
            otherUserId: _otherUserId,
            isCalling: _isCalling,
            onStartCall: _startRingingCall,
            onShowDeviceTokens: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _DeviceTokensScreen()),
            ),
            onLogout: widget.onLogout,
          ),
          ChannelListScreen(onLogout: widget.onLogout),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.video_call), label: 'Call'),
          NavigationDestination(icon: Icon(Icons.chat), label: 'Chat'),
        ],
      ),
    );
  }
}

class _CallTab extends StatelessWidget {
  const _CallTab({
    required this.userId,
    required this.userName,
    required this.otherUserName,
    required this.otherUserId,
    required this.isCalling,
    required this.onStartCall,
    required this.onShowDeviceTokens,
    required this.onLogout,
  });

  final String userId;
  final String userName;
  final String otherUserName;
  final String otherUserId;
  final bool isCalling;
  final VoidCallback onStartCall;
  final VoidCallback onShowDeviceTokens;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringing Example'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'logout') {
                await onLogout();
              } else if (value == 'devices') {
                onShowDeviceTokens();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'devices',
                child: ListTile(
                  leading: Icon(Icons.smartphone),
                  title: Text('Device tokens'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Log out'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    userName[0].toUpperCase(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Logged in as $userName',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  userId,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 48),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Call another user',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(otherUserName[0].toUpperCase()),
                    ),
                    title: Text(otherUserName),
                    subtitle: Text(otherUserId),
                    trailing: isCalling
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.video_call, size: 32),
                            color: Colors.green,
                            onPressed: onStartCall,
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Run this app on two devices.\n'
                  'Log in as different users and tap the call button.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: onShowDeviceTokens,
                  icon: const Icon(Icons.smartphone, size: 20),
                  label: const Text('View registered device tokens'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceTokensScreen extends StatefulWidget {
  const _DeviceTokensScreen();

  @override
  State<_DeviceTokensScreen> createState() => _DeviceTokensScreenState();
}

class _DeviceTokensScreenState extends State<_DeviceTokensScreen> {
  List<PushDevice>? _devices;
  bool _loading = true;
  bool _removing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await StreamVideo.instance.getDevices();
      final list = result.getDataOrNull() ?? [];
      if (mounted) {
        setState(() {
          _devices = list;
          _loading = false;
        });
      }
    } catch (e, stk) {
      debugPrint('Error loading devices: $e');
      debugPrint(stk.toString());
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// Removes all registered device tokens from the backend and re-registers
  /// the current device.
  Future<void> _clearAllTokensAndReregisterDevice() async {
    final devices = _devices ?? [];
    setState(() => _removing = true);
    try {
      int removed = 0;
      for (final d in devices) {
        final result = await StreamVideo.instance.removeDevice(
          pushToken: d.pushToken,
        );
        if (result.isSuccess) removed++;
      }

      final pushManager =
          StreamVideo.instance.pushNotificationManager
              as StreamVideoPushNotificationManager?;
      if (pushManager != null) {
        await pushManager.unregisterDevice();
        pushManager.registerDevice();
      }

      if (mounted) {
        final chatClient = StreamChat.of(context).client;
        registerChatDevice(
          chatClient,
          pushProviderName: AppConfig.androidPushProviderName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              removed > 0
                  ? 'Removed $removed token(s) and re-registered this device'
                  : 'Re-registered this device',
            ),
          ),
        );
        await _loadDevices();
      }
    } catch (e, stk) {
      debugPrint('Error clearing tokens and re-registering: $e');
      debugPrint(stk.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final showBottomButton = !_loading && _error == null && _devices != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Registered device tokens')),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadDevices,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _devices!.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.smartphone_outlined,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No registered devices',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Device tokens will appear here after push registration.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : _removing
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadDevices,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _devices!.length,
                      itemBuilder: (context, index) {
                        final d = _devices![index];
                        final tokenPreview = d.pushToken.length > 24
                            ? '${d.pushToken.substring(0, 24)}…'
                            : d.pushToken;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              d.voip == true
                                  ? Icons.phone_in_talk
                                  : Icons.smartphone,
                            ),
                          ),
                          title: Text(
                            tokenPreview,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          subtitle: Text(
                            '${d.pushProviderName ?? d.pushProvider.name}${d.voip == true ? ' (VoIP)' : ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (showBottomButton)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _removing
                        ? null
                        : () => _clearAllTokensAndReregisterDevice(),
                    icon: _removing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 20),
                    label: Text(
                      _removing
                          ? 'Clearing and re-registering…'
                          : 'Clear all tokens and re-register this device',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
