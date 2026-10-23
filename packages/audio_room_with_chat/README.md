A working sample that integrates Stream Audio Rooms with a Stream Chat experience. It demonstrates creating and joining live audio rooms with in-room chat, permission requests, and a simple host/participant UI.

> [!IMPORTANT]
> This sample needs your own Stream API key and user tokens. See [Configuration](#configuration) before running it.

## Cookbook
Looking for a step‑by‑step guide? Check out the cookbook:

- [Cookbook: Video with Chat integration](https://getstream.io/video/docs/flutter/ui-cookbook/audio-room-with-chat/)

## Features
- Discover, create, and join live audio rooms
- Host/participant controls: go live/stop live, request/grant speak, mic on/off
- Integrated chat channel per room (Stream Chat `livestream` channel)
- Works across iOS, Android, Web, and Desktop (where supported by Flutter/SDKs)

## Getting Started
1. Ensure you have Flutter installed and set up.
2. Install dependencies:
   - `flutter pub get`
3. Create `env/env.json` with your Stream credentials, see [Configuration](#configuration).
4. Run the app on your desired platform:
   - `flutter run`

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
scripts/generate_env.sh packages/audio_room_with_chat
```

Alternatively, copy `env/env.example.json` to `env/env.json` and fill in the values yourself. You can generate user tokens with the [token generator](https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens).

Then run the sample as usual with `flutter run` or from your IDE. If `env/env.json` is missing values, the app shows a setup screen listing them. `env/env.json` is ignored by git, so your credentials stay out of the repository.

> [!NOTE]
> `env/env.json` is bundled with the app, and tokens created this way don't expire. That's fine for trying the sample out, but in a production app, generate tokens on your server.
