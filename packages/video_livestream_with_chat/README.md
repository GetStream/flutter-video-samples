# Livestream With Chat Example

A showcase app that overlays **Stream Chat on top of a live video broadcast**, combining the
[Stream Video Flutter SDK](https://pub.dev/packages/stream_video_flutter) with the
[Stream Chat Flutter SDK](https://pub.dev/packages/stream_chat_flutter). Messages, a live viewer
count, and floating heart / clap reactions all render over a full-bleed `LivestreamPlayer`.

> There is no dedicated cookbook page for this combination yet. The closest guides are
> [Watching a Livestream](https://getstream.io/video/docs/flutter/ui-cookbook/watching-a-livestream/),
> [Hosting a Livestream](https://getstream.io/video/docs/flutter/ui-cookbook/hosting-a-livestream/),
> and — for the chat-alongside-video pattern —
> [Building Audio Rooms With In-Call Chat](https://getstream.io/video/docs/flutter/ui-cookbook/audio-room-with-chat/).

> [!IMPORTANT]
> The predefined API key, user credentials, and IDs in this sample should be treated as publicly
> accessible demo values. If you reuse them, other people running the sample may join the same
> livestream and chat.

## Use Case

A creator broadcasts to an audience that talks back — the defining shape of consumer live video:

- **Live shopping** — viewers ask about a product while the host demos it
- **Creator streams** — the chat is the show as much as the video is
- **Live sports / watch parties** — reactions spike around the moments that matter
- **Town halls and AMAs** — questions arrive in chat and the host answers on stream

The interesting part is not chat itself, but chat *as an overlay*: the video stays full-bleed and
the chat has to stay readable over whatever is on screen without stealing the frame.

## How It Works

1. **One identity, two products.** A single Stream token authenticates the user against both
   SDKs — `StreamVideo(...)` and `StreamChatClient.connectUser(...)` (see `lib/stream_clients.dart`).
2. **Hosts are call members with the `host` role.** On the `livestream` call type only hosts may
   publish, so `getOrCreate` lists *every* configured host as a member — not just whoever creates
   the call. A co-host who joins a call someone else created would otherwise connect with their
   camera and mic blocked.
3. **The channel reuses the call id.** `client.channel('livestream', id: call.id)` pairs the chat
   with the broadcast, so there is exactly one chat per livestream and no extra bookkeeping. The
   built-in `livestream` channel type is open to anyone and skips per-member read state, which is
   what a high-traffic broadcast chat wants.
4. **The player gives up its controls.** `LivestreamPlayer` keeps its backstage, ended and
   reconnecting handling, but `livestreamControlsWidgetBuilder` and `backButtonBuilder` return
   `SizedBox.shrink()` so the chat overlay owns the bottom of the screen.
5. **Chat is restyled for video, not screens.** A custom `messageBuilder` renders each message as
   an avatar, name and line of text — no bubbles, no surfaces — with a text shadow so it stays
   legible over a bright frame, and a `ShaderMask` fades older messages into the video.
6. **The composer floats.** The `Scaffold` uses `resizeToAvoidBottomInset: false` so the video
   stays full-bleed, and the composer lifts itself over the keyboard using
   `MediaQuery.viewInsetsOf(context).bottom`.
7. **Reactions ride the Video API, not chat.** The heart and clap buttons call
   `call.sendReaction(...)`. Every participant — including the sender — receives the resulting
   `StreamCallReactionEvent` on `call.callEvents`, and `FloatingReactionsLayer` animates it up
   over the video.

## Running the App

1. Open the project in your IDE.
2. Run `flutter pub get`.
3. Deploy to **two devices** (physical devices or simulators/emulators).
4. Log in as **Alice Johnson (host)** on one device and any viewer on the other.
5. On the host device, tap **Start livestream**.
6. On the viewer device, tap **Watch and chat**.
7. Send messages from either side — they appear over the video on both.
8. Tap the heart or clap to send a reaction that floats up on every device.

> The host needs a real camera. The iOS Simulator has none, so an iOS host broadcasts no video and
> viewers see "The host's video is not available" — chat and reactions still work. An **Android
> emulator does** have one: set the AVD's back camera to `VirtualScene` and run the host there to
> see the overlay against actual video.

## Key Files

- `lib/main.dart` — user picker, permissions, and the app-level `StreamChat` wrapper
- `lib/stream_clients.dart` — connects/disconnects one user against both Video and Chat
- `lib/home_screen.dart` — creates the livestream call *and* its matching chat channel
- `lib/host_livestream_screen.dart` — host UI: go live, broadcast controls, same chat overlay
- `lib/viewer_livestream_screen.dart` — viewer UI: `LivestreamPlayer` with its controls replaced
- `lib/livestream_chat_overlay.dart` — the fading message list and the composer
- `lib/livestream_chat_message.dart` — the custom over-video message row and `CREATOR` badge
- `lib/livestream_reactions.dart` — sending call reactions and animating them over the video
- `lib/livestream_top_bar.dart` — `LIVE` badge and live viewer count
- `lib/chat_overlay_theme.dart` — the Stream Chat theme that makes chat transparent over video

## Configuration

To use your own Stream credentials, update `lib/app_config.dart`:

- Replace `streamApiKey` with your Stream API key.
- Generate new user tokens at https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens.
- Update the host and viewer IDs and tokens.

The same token is used for Video and Chat, so your app must have both products enabled in the
[Stream Dashboard](https://dashboard.getstream.io/).

## Dependencies

- `stream_video_flutter: ^1.6.0` — Video SDK with the pre-built `LivestreamPlayer`
- `stream_chat_flutter: ^9.23.0` — Chat SDK with the message list and composer
- `permission_handler: ^12.0.1` — Runtime camera / microphone permissions

## Notes

- `inputBackgroundColor` in `StreamMessageInputThemeData` fills both the bar behind the composer
  *and* the rounded field inside it. The sample sets it to transparent and draws the translucent
  pill itself — otherwise you get an opaque bar across the bottom of the video.
- Two Stream Chat theme values paint opaque surfaces that hide the video, and both have to be made
  transparent: `messageInputTheme.inputBackgroundColor` (above) and
  `messageListViewTheme.backgroundColor`, which otherwise fills the message list with the dark
  theme's `barsBg` — an opaque black panel no matter how light the overlay's own scrim is.
- The floating reactions layer is stacked **above** the chat overlay. Underneath it, the chat's
  gradient scrim washes the emoji out.
- The host preview renders `StreamCallParticipant` directly rather than `StreamCallContent`.
  `StreamCallContent` brings its own app bar and call controls and letterboxes the video to make
  room for them — and `callAppBarWidgetBuilder: (_, __) => null` does *not* remove the app bar, it
  falls back to the default one. For a full-bleed broadcast, render the participant yourself.
- Co-hosts are supported: `AppConfig.hosts` holds more than one user, every host publishes, and
  the hosts appear together in a grid (name labels switch on automatically once there is more than
  one). Changing that list changes who may broadcast — but membership is fixed when the call is
  created, so an existing call keeps its old host list; use a new `livestreamId` after editing it.
- Reactions are Video API events, not chat messages: they are ephemeral and are not part of the
  channel history. Use chat messages if you need reactions to persist.
