# Livestream Overlay Example

A livestreaming sample app for the [Stream Video Flutter SDK](https://pub.dev/packages/stream_video_flutter) that burns a scoreboard overlay into the host's video via a **native video filter**. The overlay is encoded into the outgoing WebRTC video, so it shows up in the local preview, on every remote viewer, and in HLS/RTMP egress.

> This sample is the runnable companion to the [Video Compositing cookbook guide](https://getstream.io/video/docs/flutter/ui-cookbook/video-compositing/).

> [!IMPORTANT]
> The predefined API key, user credentials, and channel IDs in this sample should be treated as publicly accessible demo values. If you reuse them, other people running the sample may join the same livestream channels.

## Use Case

This sample combines three things:

1. **Livestreaming with the Stream Video Flutter SDK**, loosely based on the [livestreaming tutorial](https://getstream.io/video/sdk/flutter/tutorial/livestreaming/). Hosts can go live and viewers can watch.
2. **The Stream Video Filters API** (`StreamVideoEffectsManager.applyCustomEffect`), which registers a named custom effect against the publisher's local track.
3. **A native video filter** (Android `BitmapVideoFilter` + iOS `VideoFilter` from `stream_video_filters`) that draws the scoreboard on each captured frame before encoding.

Flutter pushes the state (scores, clock, mirror flag) to native over a method channel. The native filter reads a consistent snapshot once per frame. The overlay updates within one captured frame of a state change.

This is the same approach used in the Stream dogfooding app, adapted here into a minimal, standalone sample.

## How It Works

### Host flow

1. Login as one of the three demo users.
2. Tap **Create a Livestream** → Flutter creates a `liveStream` call, marks the current user as `host`, joins with camera + mic enabled, and goes live immediately.
3. Once live, tap **Show scoreboard**. This:
   - calls `StreamVideoEffectsManager.applyCustomEffect('scoreboard', ...)`
   - which invokes `ScoreboardChannel.registerScoreboardEffect()` over the method channel
   - which calls `ProcessorProvider.addProcessor("scoreboard", ...)` natively (`MainActivity.kt` / `AppDelegate.swift`)
   - and then applies the named effect to the local video track.
4. The **edit** button opens a dialog to change the home/away scores and control the game clock (start, pause, reset). Apply pushes the new scores to native via `updateScoreboardState`; the game clock is driven by a Dart-side `Timer.periodic` that pushes the formatted time to native every second.

### Viewer flow

1. Login (same users work).
2. Tap **View a Livestream** and paste the host's Call ID.
3. The viewer sees the `LivestreamPlayer` HLS view — with the scoreboard already burned into the video.

### The mirror flag

The host joins with `MirrorMode.off` on the camera (see `home_screen.dart`). This disables the render-time selfie mirror, so the overlay reads correctly on the local preview, on remote participants, and in HLS/RTMP egress. If you re-enable the local mirror, flip the scoreboard's **Mirror horizontally** switch so the pre-baked flip cancels the render-time one on your own screen (at the cost of reading backwards to remote viewers).

## Key files

| File | Purpose |
|------|---------|
| `lib/livestream_screen.dart` | Host UI with scoreboard toggle, game clock timer, and edit dialog |
| `lib/scoreboard_channel.dart` | Dart `MethodChannel` wrapper + local state mirror |
| `lib/scoreboard_settings_dialog.dart` | Modal dialog for editing scores and controlling the game clock |
| `android/.../MainActivity.kt` | Registers the method channel + `ScoreboardVideoFilterFactory` |
| `ios/Runner/AppDelegate.swift` | Registers the method channel + `ScoreboardVideoFrameProcessor` |

## Running the App

1. `flutter pub get`
2. For iOS: `cd ios && pod install`
3. `flutter run` on a physical device or emulator with a camera

To exercise the full end-to-end flow, run on two devices:

- **Device 1**: login as Alice, Create a Livestream, Show scoreboard, start the game clock
- **Device 2**: login as Bob, View a Livestream, paste the Call ID shown on Device 1

Edit the scoreboard on Device 1 and watch Device 2 pick up the changes within a frame.

## Configuration

To use your own Stream credentials, update `lib/app_keys.dart`:

- Replace `streamApiKey` with your Stream API key
- Generate new user tokens at https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens

## Dependencies

- `stream_video_flutter` — video calling SDK with pre-built UI
- `stream_video_filters` — video effects manager + native base classes for custom filters
- `permission_handler` — runtime camera / microphone permissions
