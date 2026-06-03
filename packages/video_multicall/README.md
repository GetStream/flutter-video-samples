# Multicall Example

A showcase app demonstrating how to manage **two simultaneous video call sessions** using the [Stream Video Flutter SDK](https://pub.dev/packages/stream_video_flutter).

> This sample is the runnable companion to the [Multicall cookbook guide](https://getstream.io/video/docs/flutter/ui-cookbook/multicall/).

> [!IMPORTANT]
> The predefined API key, user credentials, and room IDs in this sample should be treated as publicly accessible demo values. If you reuse them, other people running the sample may join the same rooms and calls.

## Use Case

Users can join one room, bring a second room into the same screen, and then **switch their active mic/camera focus between them** without leaving the inactive room. This pattern is common in:

- **Expert consultation platforms**: an expert pauses a group session to take a private call
- **Support/triage workflows**: an agent switches between customer calls
- **Multi-room conferencing**: a host moves between breakout rooms

## How It Works

1. **Pick a user**. Two predefined test users (Alice & Bob) let you test on two devices
2. **Join a room**. The first room joins with mic and camera enabled, just like a normal call
3. **Join second room**. The split view keeps the other room visible and joined, but inactive
4. **Switch room**. The active room gets mic/camera and local playout, while the inactive room stays joined with local media disabled

## Running the App

1. Open the project in your IDE
2. Run `flutter pub get`
3. Deploy to **two devices** (physical devices or emulators)
4. Log in as **Alice** on one device and **Bob** on the other
5. Both join **Room Alpha** to start a call together
6. Tap **Join second room** inside the split view
7. Use **Switch room** to move the active speaking/publishing focus

## Audio Session Handoff

Each `Call` owns its own native peer-connection factory (with its own audio device module) on iOS, Android, and macOS. When two calls coexist, both factories would otherwise contend for the device's microphone and speaker, which manifests as poor audio quality or missing audio.

The sample relies on two SDK features:

**1. `multiCallAudioPolicy` (client-wide)** controls what `setActiveCall` and `removeActiveCall` automatically suspend/resume:

```dart
StreamVideo(
  apiKey,
  user: ...,
  options: StreamVideoOptions(
    allowMultipleActiveCalls: true,
    multiCallAudioPolicy: MultiCallAudioPolicy.suspendIncoming,
  ),
);
```

The three policies:

- `suspendExisting` (default). Newest call wins. `setActiveCall(new)` suspends every prior active call. `removeActiveCall` auto-resumes the most-recently-added remaining call.
- `suspendIncoming`. First-joined call keeps focus. `setActiveCall(new)` suspends the new call (if another is already active) so it joins in the background, with no auto-resume on leave. This is what the multicall sample uses.
- `manual`. The SDK does nothing automatically. The integrator owns `suspendAudio`/`resumeAudio` entirely. Without explicit suspension, the two per-call factories will contend for mic/speaker.

**2. `Call.suspendAudio()` / `Call.resumeAudio()`** give manual control over a single call's audio. `suspendAudio` releases the mic/speaker and disables the call's audio tracks. `resumeAudio` reclaims them and restores the tracks to their prior state.

### How the sample uses these

- **Joining the second room** in the background is just `call.join()`. Because the client is configured with `MultiCallAudioPolicy.suspendIncoming`, the SDK suspends the freshly-joined call automatically. Its remote audio tracks are disabled on arrival, and the first-joined room keeps audio focus. There's no per-room subscription, pre-suspend dance, or post-join resume in the sample code.
- **Switching rooms** is a straight `suspendAudio` / `resumeAudio` pair on the outgoing and incoming calls. `suspendAudio` releases mic/speaker on the outgoing call. `resumeAudio` reclaims them on the incoming call and re-enables its audio tracks (including the ones that were disabled on arrival during the background join).
- **Leaving a call** does not need any explicit `resumeAudio`. Under `suspendIncoming` the leaving call was either the foreground call (no other call needs resuming) or a background call (the foreground call was never suspended).

## Configuration

To use your own Stream credentials, update `lib/app_config.dart`:

- Replace `streamApiKey` with your Stream API key
- Generate new user tokens at https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens
- Update user IDs and tokens

## Dependencies

- `stream_video_flutter: ^1.4.0`. Video calling SDK with pre-built UI
- `permission_handler: ^12.0.1`. Runtime camera/microphone permissions
