# Creator Rooms — Chat Rooms With Livestream

A creator-community sample built on the [Stream Chat Flutter SDK](https://pub.dev/packages/stream_chat_flutter) and the [Stream Video Flutter SDK](https://pub.dev/packages/stream_video_flutter). Members chat in a set of predefined rooms; **content creators can start a livestream from inside a room**, and everyone else in that room can watch it without leaving the conversation.

> [!IMPORTANT]
> This sample needs your own Stream API key and user tokens. See [Configuration](#configuration) before running it.

## Use Case

A community app where the conversation is the front door and the broadcast happens inside it — Discord-with-Go-Live, a class that streams a lesson into its own room, a fan community whose creators drop in live. Common in:

- **Creator communities** — a creator goes live in the topic room their audience already sits in
- **Cohort learning** — an instructor streams a session into the cohort's channel
- **Live shopping / drops** — a seller broadcasts into the product's discussion room

## How It Works

1. **Single identity for Chat & Video:** Both SDKs share an API key and user JWT.
2. **Creators vs. Members:** Role determines access to the **Go live** button.
3. **Preset rooms:** Room data is predefined; rooms are created automatically if missing.
4. **Uses open `livestream` channels:** Public rooms are based on Stream’s open `livestream` channel type so anyone can join/chat; use `messaging` for private/DMs.
5. **Going live updates room state** _(sample-only: client-driven, see note below)_: Going live updates the channel's live pointer so all members see which room is live.
6. **Broadcast announcement** _(sample-only: client-driven, see note below)_: A message with a custom attachment announces the livestream; viewers see a “join” card in chat.
7. **Watch inline:** Viewers join or leave the stream without leaving the room; the player stays docked above the message list.
8. **Cleanup:** Ending a stream clears the live pointer and updates old announcements to show “Stream ended.”

## Running the App

1. Open the project in your IDE.
2. Run `flutter pub get`.
3. Create `env/env.json` with your Stream credentials, see [Configuration](#configuration).
4. Run the app on a physical device or emulator. **The iOS Simulator and the Android emulator have no real camera**, so the host's preview will be blank there — run the creator on a physical device to see actual video.
   It also runs in the browser (`flutter run -d chrome`); the browser asks for camera and microphone access when a creator goes live.
5. Sign in as a creator (Alice, Carol, or Eva) on one device and as a member (Bob, David, or Frank) on another, open the same room, and tap **Go live**.

## Configuration

The sample doesn't contain any Stream credentials. It reads the API key and the user tokens from `env/env.json` when it starts:

| Key | Value |
| --- | --- |
| `STREAM_API_KEY` | Your Stream API key from the [Stream Dashboard](https://dashboard.getstream.io/) |
| `STREAM_TOKEN_ALICE_JOHNSON` | A user token for `alice_johnson` |
| `STREAM_TOKEN_BOB_SMITH` | A user token for `bob_smith` |
| `STREAM_TOKEN_CAROL_DAVIS` | A user token for `carol_davis` |
| `STREAM_TOKEN_DAVID_LEE` | A user token for `david_lee` |
| `STREAM_TOKEN_EVA_MARTINEZ` | A user token for `eva_martinez` |
| `STREAM_TOKEN_FRANK_WILSON` | A user token for `frank_wilson` |

The quickest way to create it is the generator script in the repository root. It asks for your API key and secret and signs the tokens locally. The secret is not stored:

```bash
scripts/generate_env.sh packages/chat_rooms_with_livestream
```

Alternatively, copy `env/env.example.json` to `env/env.json` and fill in the values yourself. You can generate user tokens with the [token generator](https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens).

Then run the sample as usual with `flutter run` or from your IDE. If `env/env.json` is missing values, the app shows a setup screen listing them. `env/env.json` is ignored by git, so your credentials stay out of the repository.

> [!NOTE]
> `env/env.json` is bundled with the app, and tokens created this way don't expire. That's fine for trying the sample out, but in a production app, generate tokens on your server.

## ⚠️ The Live State Is Client-Driven — Don't Ship That

All chat-side stream lifecycle logic is in [`lib/live_announcements.dart`](lib/live_announcements.dart): one function posts the live announcement, another edits it to mark the stream ended. In this demo, only the broadcaster's client updates chat when going live or stopping. If the broadcaster’s app closes or loses connection before this update, viewers may keep seeing banners for streams that have actually ended—only backend logic can really fix this.

**In production, use backend-driven updates via Stream Video webhooks** (like `call.live_started`, `call.ended`, `call.session_ended`, `call.session_participant_left`). A server-side handler, authenticated by the API secret, should update chat state—such as writing an announcement or managing a `live_call_id` on the channel—so that live state persists accurately, cannot race between clients, and does not rely on the broadcaster's device being reachable.
