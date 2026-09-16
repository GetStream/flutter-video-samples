# Creator Rooms — Chat Rooms With Livestream

A creator-community sample built on the [Stream Chat Flutter SDK](https://pub.dev/packages/stream_chat_flutter) and the [Stream Video Flutter SDK](https://pub.dev/packages/stream_video_flutter). Members chat in a set of predefined rooms; **content creators can start a livestream from inside a room**, and everyone else in that room can watch it without leaving the conversation.

> [!IMPORTANT]
> The predefined API key, user tokens, and room ids in this sample should be treated as publicly accessible demo values. If you reuse them, other people running the sample may join the same rooms and livestreams.

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
3. Run the app on a physical device or emulator. **The iOS Simulator and the Android emulator have no real camera**, so the host's preview will be blank there — run the creator on a physical device to see actual video.
4. Sign in as a creator (Alice, Carol, or Eva) on one device and as a member (Bob, David, or Frank) on another, open the same room, and tap **Go live**.

## ⚠️ The Live State Is Client-Driven — Don't Ship That

All chat-side stream lifecycle logic is in [`lib/live_announcements.dart`](lib/live_announcements.dart): one function posts the live announcement, another edits it to mark the stream ended. In this demo, only the broadcaster's client updates chat when going live or stopping. If the broadcaster’s app closes or loses connection before this update, viewers may keep seeing banners for streams that have actually ended—only backend logic can really fix this.

**In production, use backend-driven updates via Stream Video webhooks** (like `call.live_started`, `call.ended`, `call.session_ended`, `call.session_participant_left`). A server-side handler, authenticated by the API secret, should update chat state—such as writing an announcement or managing a `live_call_id` on the channel—so that live state persists accurately, cannot race between clients, and does not rely on the broadcaster's device being reachable.
