# Multicall Example

A showcase app demonstrating how to manage **two simultaneous video call sessions** using the [Stream Video Flutter SDK](https://pub.dev/packages/stream_video_flutter).

> This sample is the runnable companion to the [Multicall cookbook guide](https://getstream.io/video/docs/flutter/ui-cookbook/multicall/).

> [!IMPORTANT]
> This sample needs your own Stream API key and user tokens. See [Configuration](#configuration) before running it.

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
3. Create `env/env.json` with your Stream credentials, see [Configuration](#configuration)
4. Deploy to **two devices** (physical devices or emulators)
5. Log in as **Alice** on one device and **Bob** on the other
6. Both join **Room Alpha** to start a call together
7. Tap **Join second room** inside the split view
8. Use **Switch room** to move the active speaking/publishing focus

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

The sample doesn't contain any Stream credentials. It reads the API key and the user tokens from `env/env.json` when it starts:

| Key | Value |
| --- | --- |
| `STREAM_API_KEY` | Your Stream API key from the [Stream Dashboard](https://dashboard.getstream.io/) |
| `STREAM_TOKEN_ALICE_JOHNSON` | A user token for `alice_johnson` |
| `STREAM_TOKEN_BOB_SMITH` | A user token for `bob_smith` |

The quickest way to create it is the generator script in the repository root. It asks for your API key and secret and signs the tokens locally. The secret is not stored:

```bash
scripts/generate_env.sh packages/video_multicall
```

Alternatively, copy `env/env.example.json` to `env/env.json` and fill in the values yourself. You can generate user tokens with the [token generator](https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens).

Then run the sample as usual with `flutter run` or from your IDE. If `env/env.json` is missing values, the app shows a setup screen listing them. `env/env.json` is ignored by git, so your credentials stay out of the repository.

> [!NOTE]
> `env/env.json` is bundled with the app, and tokens created this way don't expire. That's fine for trying the sample out, but in a production app, generate tokens on your server.

## Dependencies

- `stream_video_flutter: ^1.4.0`. Video calling SDK with pre-built UI
- `permission_handler: ^12.0.1`. Runtime camera/microphone permissions
