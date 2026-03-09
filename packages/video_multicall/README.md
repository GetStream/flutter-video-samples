# Multicall Example

A showcase app demonstrating how to manage **two simultaneous video call sessions** using the [Stream Video Flutter SDK](https://pub.dev/packages/stream_video_flutter).

> [!IMPORTANT]
> The predefined API key, user credentials, and room IDs in this sample should be treated as publicly accessible demo values. If you reuse them, other people running the sample may join the same rooms and calls.

## Use Case

Users can join one room, bring a second room into the same screen, and then **switch their active mic/camera focus between them** without leaving the inactive room. This pattern is common in:

- **Expert consultation platforms** — an expert pauses a group session to take a private call
- **Support/triage workflows** — an agent switches between customer calls
- **Multi-room conferencing** — a host moves between breakout rooms

## How It Works

1. **Pick a user** — Two predefined test users (Alice & Bob) let you test on two devices
2. **Join a room** — The first room joins with mic and camera enabled, just like a normal call
3. **Join second room** — The split view keeps the other room visible and joined, but inactive
4. **Switch room** — The active room gets mic/camera and local playout, while the inactive room stays joined with local media disabled

## Running the App

1. Open the project in your IDE
2. Run `flutter pub get`
3. Deploy to **two devices** (physical devices or emulators)
4. Log in as **Alice** on one device and **Bob** on the other
5. Both join **Room Alpha** to start a call together
6. Tap **Join second room** inside the split view
7. Use **Switch room** to move the active speaking/publishing focus

## Audio Playout Note

Currently, the SDK supports global audio playout pause and resume, but does not provide a way to mute audio playback for individual calls. In this sample, we demonstrate how to use the lower-level remote track API to locally mute remote audio tracks for an inactive room. This approach may change in the future as the SDK adds more robust multi-room features and support for per-call audio playout control.

## Configuration

To use your own Stream credentials, update `lib/app_config.dart`:

- Replace `streamApiKey` with your Stream API key
- Generate new user tokens at https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens
- Update user IDs and tokens

## Dependencies

- `stream_video_flutter: ^1.2.4` — Video calling SDK with pre-built UI
- `permission_handler: ^12.0.1` — Runtime camera/microphone permissions
