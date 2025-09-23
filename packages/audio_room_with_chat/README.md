A working sample that integrates Stream Audio Rooms with a Stream Chat experience. It demonstrates creating and joining live audio rooms with in-room chat, permission requests, and a simple host/participant UI.

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
2. Open `lib/env/env.dart` and set your Stream API key(s). Add sample users and tokens.
   - For development, you can generate user tokens using Stream’s token tool (see comments in `env.dart`).
3. Install dependencies:
   - `flutter pub get`
4. Run the app on your desired platform:
   - `flutter run`
