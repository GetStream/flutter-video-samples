A working sample that integrates Stream Video calling into a Stream Chat experience. It demonstrates starting and joining video calls directly from chat channels, including core call controls and a simple UI.

> [!IMPORTANT]
> The predefined API key, user credentials, and any hardcoded room, channel, or call IDs in this sample should be treated as publicly accessible demo values. If you reuse them, other people running the sample may join the same calls or conversations.

## Cookbook
Looking for a step‑by‑step guide? Check out the cookbook entry:

- [Cookbook: Video in Chat – Building Chat Apps With Video Support](https://getstream.io/video/docs/flutter/ui-cookbook/chat-with-video/)

## Features
- Launch and join video calls from chat conversations
- Basic call controls: mute/unmute, camera on/off, speaker selection
- Channel list and message UI wired to Stream Chat
- Works across iOS, Android, Web, and Desktop (where supported by Flutter/SDKs)

## Getting Started
1. Ensure you have Flutter installed and set up.
2. Open `lib/env/env.dart` and set your Stream API key(s). Add sample users and tokens.
   - For development, you can generate user tokens using Stream’s token tool (see comments in `env.dart`).
3. Install dependencies:
   - `flutter pub get`
4. Run the app on your desired platform:
   - `flutter run`
