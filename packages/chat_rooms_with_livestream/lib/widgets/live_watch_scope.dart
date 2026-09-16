import 'package:flutter/widgets.dart';

import '../models/live_session.dart';

/// Lets anything below the room screen ask it to start watching a livestream.
///
/// The join card is rendered by a globally registered attachment builder deep
/// inside the message list, so it has no direct handle on the room screen's
/// state. Rather than pushing a separate viewer route, it calls [watch] and the
/// room screen expands its own inline player.
class LiveWatchScope extends InheritedWidget {
  const LiveWatchScope({
    super.key,
    required this.watch,
    required this.watchedCallId,
    required super.child,
  });

  /// Starts (or re-focuses) the inline player for [session].
  final void Function(LiveSession session) watch;

  /// The call currently expanded inline, if any.
  final String? watchedCallId;

  static LiveWatchScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiveWatchScope>();

  @override
  bool updateShouldNotify(LiveWatchScope oldWidget) =>
      watchedCallId != oldWidget.watchedCallId || watch != oldWidget.watch;
}
