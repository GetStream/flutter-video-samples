## Chat with Video — Starter (Flutter)

A minimal starter to help you integrate Stream Chat and Stream Video in Flutter.

This starter kit accompanies the UI Cookbook guide: [Cookbook: Video in Chat – Building Chat Apps With Video Support](https://getstream.io/video/docs/flutter/ui-cookbook/chat-with-video/).
For the final, fully working sample, see `packages/chat_with_video_call`.

> [!IMPORTANT]
> This starter needs your own Stream API key and user tokens. See [Configuration](#configuration) before running it.

## Configuration

The starter doesn't contain any Stream credentials. It reads the API key and the user tokens from `env/env.json` when it starts:

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
scripts/generate_env.sh packages/quickstart_kits/chat_with_video_starter
```

Alternatively, copy `env/env.example.json` to `env/env.json` and fill in the values yourself. You can generate user tokens with the [token generator](https://getstream.io/chat/docs/flutter-dart/tokens_and_authentication/#manually-generating-tokens).

Then run the starter as usual with `flutter run` or from your IDE. If `env/env.json` is missing values, the app shows a setup screen listing them. `env/env.json` is ignored by git, so your credentials stay out of the repository.

> [!NOTE]
> `env/env.json` is bundled with the app, and tokens created this way don't expire. That's fine for trying the starter out, but in a production app, generate tokens on your server.
