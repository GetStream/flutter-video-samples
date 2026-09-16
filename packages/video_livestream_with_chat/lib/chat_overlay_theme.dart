import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Stream Chat theme tuned for drawing chat *on top of* a video.
///
/// The defaults assume chat owns the whole screen and paints its own
/// background. Over a livestream you want the opposite: no surfaces, no
/// elevation, and text light enough to stay readable on a bright frame.
///
/// Note that `inputBackgroundColor` fills both the bar behind the composer
/// *and* the rounded field inside it. Making it transparent removes the
/// opaque bar; `LivestreamChatOverlay` then draws the translucent pill
/// itself, around the whole composer.
StreamChatThemeData buildChatOverlayTheme() {
  return StreamChatThemeData(
    brightness: Brightness.dark,
    messageInputTheme: StreamMessageInputThemeData(
      elevation: 0,
      shadow: const BoxShadow(color: Colors.transparent),
      inputBackgroundColor: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      idleBorderGradient: const LinearGradient(
        colors: [Colors.transparent, Colors.transparent],
      ),
      activeBorderGradient: const LinearGradient(
        colors: [Colors.transparent, Colors.transparent],
      ),
      inputTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      actionButtonColor: Colors.white,
      actionButtonIdleColor: Colors.white70,
      sendButtonColor: Colors.white,
      sendButtonIdleColor: Colors.white54,
      expandButtonColor: Colors.white,
    ),
  );
}
