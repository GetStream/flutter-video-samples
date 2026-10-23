# Livestream With Call Example

A showcase app demonstrating how a viewer can **call the livestream host mid-broadcast** using the [Stream Video Flutter SDK](https://pub.dev/packages/stream_video_flutter). The host accepts the 1:1 call in a floating window while staying connected to the livestream — and the broadcast resumes automatically when the call ends.

> This sample is the runnable companion to the [Multicall cookbook guide](https://getstream.io/video/docs/flutter/ui-cookbook/multicall/).

> [!IMPORTANT]
> This sample needs your own Stream API key and user tokens. See [Configuration](#configuration) before running it.

## Use Case

A creator goes live, a viewer wants to talk to them privately, and the host wants to take that conversation **without dropping the broadcast**. Common in:

- **Live shopping** — host pulls a customer "on stage" for a private question
- **Coaching / Q&A streams** — host answers a viewer 1:1 while the audience waits
- **Live podcasts** — guest is brought on via a side call before joining the main mix

## How It Works

1. **Two call types coexist.** `allowMultipleActiveCalls: true` lets the host stay in the `livestream` call while accepting a second `default` 1:1 call.
2. **Viewer rings the host.** The viewer creates a 1:1 call with `ringing: true`, listing the host as the only member.
3. **Host detects the ring.** The host listens to `StreamVideo.instance.state.incomingCall` and shows an in-app accept / decline sheet.
4. **Accept = livestream paused, call active.** On accept, the host's mic and camera are disabled in the livestream (`setMicrophoneEnabled(enabled: false)` / `setCameraEnabled(enabled: false)` on the livestream call), then the 1:1 call is `accept()`-ed and `join()`-ed.
5. **Floating panel.** The 1:1 call renders as a small picture-in-picture panel layered on top of the livestream so the host (and the viewer) can keep watching the broadcast.
6. **Hang up = livestream resumed.** Ending the 1:1 call re-enables the host's mic and camera, and the broadcast continues.

## Running the App

1. Open the project in your IDE.
2. Run `flutter pub get`.
3. Create `env/env.json` with your Stream credentials, see [Configuration](#configuration).
4. Deploy to **two devices** (physical devices or emulators).
5. Log in as **Alice (host)** on one device and **Bob (viewer)** on the other.
6. On the host device, tap **Start livestream**.
7. On the viewer device, tap **Watch livestream**, then **Call Alice Johnson**.
8. Accept the call on the host device — the broadcast keeps running while the 1:1 call appears as a floating panel.
9. Hang up to resume normal broadcasting.

## Key Files

- `lib/main.dart` — login + `StreamVideo` init with `allowMultipleActiveCalls: true`
- `lib/home_screen.dart` — landing page that creates the shared `liveStream` call
- `lib/host_livestream_screen.dart` — host UI: go live, observe `state.incomingCall`, accept the ring, mute on the livestream while the 1:1 call is active
- `lib/viewer_livestream_screen.dart` — viewer UI: `LivestreamPlayer` + button that creates the ringing 1:1 call to the host
- `lib/floating_call_panel.dart` — picture-in-picture panel rendered above the livestream while the 1:1 call is active

## Configuration

The sample doesn't contain any Stream credentials. It reads the API key and the user tokens from `env/env.json` when it starts:

| Key | Value |
| --- | --- |
| `STREAM_API_KEY` | Your Stream API key from the [Stream Dashboard](https://dashboard.getstream.io/) |
| `STREAM_TOKEN_ALICE_JOHNSON` | A user token for `alice_johnson` |
| `STREAM_TOKEN_BOB_SMITH` | A user token for `bob_smith` |
| `STREAM_TOKEN_CAROL_DAVIS` | A user token for `carol_davis` |

The quickest way to create it is the generator script in the repository root. It asks for your API key and secret and signs the tokens locally. The secret is not stored:

```bash
scripts/generate_env.sh packages/video_livestream_with_call
```

Alternatively, copy `env/env.example.json` to `env/env.json` and fill in the values yourself. You can generate user tokens with the [token generator](https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens).

Then run the sample as usual with `flutter run` or from your IDE. If `env/env.json` is missing values, the app shows a setup screen listing them. `env/env.json` is ignored by git, so your credentials stay out of the repository.

> [!NOTE]
> `env/env.json` is bundled with the app, and tokens created this way don't expire. That's fine for trying the sample out, but in a production app, generate tokens on your server.

Make sure the `default` call type in your Stream Dashboard has ringing enabled, and that **multiple active calls** are allowed for your application.

## Dependencies

- `stream_video_flutter: ^1.4.0` — Video calling SDK with pre-built UI
- `permission_handler: ^12.0.1` — Runtime camera / microphone permissions

## Notes

- This sample relies on **foreground websocket events** (`StreamVideo.instance.state.incomingCall`) to deliver the ring. To support ringing while the host's app is backgrounded or terminated, configure push notifications — see the `video_ringing_with_chat_push` sample and the [push notifications guide](https://getstream.io/video/docs/flutter/advanced/incoming-calls/push-notifications/).
- The host's livestream is **paused, not stopped**, while the 1:1 call is active. Viewers see a "host is offline" placeholder until the host resumes — they stay subscribed to the livestream call the whole time.
