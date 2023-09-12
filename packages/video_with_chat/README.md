# Video with Chat 
This project demonstrates how real-time messaging can be added to a Google Meet/Zoom style Video conferencing application using Stream's [Chat API](https://getstream.io/chat).

To run this project you will need:
1. The latest version of [Flutter](https://flutter.dev) installed on your machine
2. A free account on [Stream](https://getstream.io/try-for-free/)
3. A fresh cup of coffee ☕️


## Getting started 🛠️
1. Clone the repository using the following command:
```shell
git clone https://github.com/GetStream/flutter-video-samples.git

cd flutter-video-samples/packages/video_with_chat
```

2. Install the required packages:
```shell
flutter pub get
```

3. Configure the project API keys located in `lib/env/env.dart`:
```dart
abstract class Env {
  static const String streamVideoApiKey = '';
  static const String streamChatApiKey = '';

  static const String sampleUserId00 = '';
  static const String sampleUserName00 = '';
  static const String sampleUserRole00 = '';
  static const String sampleUserImage00 = '';
  static const String sampleUserVideoToken00 = '';
  static const String sampleUserChatToken00 = '';

  static const String sampleUserId01 = '';
  static const String sampleUserName01 = '';
  static const String sampleUserRole01 = '';
  static const String sampleUserImage01 = '';
  static const String sampleUserVideoToken01 = '';
  static const String sampleUserChatToken01 = '';

  static const String sampleUserId02 = '';
  static const String sampleUserName02 = '';
  static const String sampleUserRole02 = '';
  static const String sampleUserImage02 = '';
  static const String sampleUserVideoToken02 = '';
  static const String sampleUserChatToken02 = '';

  static const String sampleUserId03 = '';
  static const String sampleUserName03 = '';
  static const String sampleUserRole03 = '';
  static const String sampleUserImage03 = '';
  static const String sampleUserVideoToken03 = '';
  static const String sampleUserChatToken03 = '';

  static const String sampleUserId04 = '';
  static const String sampleUserName04 = '';
  static const String sampleUserRole04 = '';
  static const String sampleUserImage04 = '';
  static const String sampleUserVideoToken04 = '';
  static const String sampleUserChatToken04 = '';

  static const String sampleUserId05 = '';
  static const String sampleUserName05 = '';
  static const String sampleUserRole05 = '';
  static const String sampleUserImage05 = '';
  static const String sampleUserVideoToken05 = '';
  static const String sampleUserChatToken05 = '';
}
```

> Note: For apps in development mode, development tokens can be used on both Video and Chat. For populating test conversations for debugging, consider using our online [generator](https://generator.getstream.io/) to automate part of the process.

4. Finally, run your application and enjoy!
```dart
flutter run 
```

<a href="https://getstream.io">
<img src="https://user-images.githubusercontent.com/24237865/138428440-b92e5fb7-89f8-41aa-96b1-71a5486c5849.png" align="right" width="12%"/>
</a>

## 🛥 What is Stream?
Stream allows developers to rapidly deploy scalable feeds, chat messaging and video with an industry leading 99.999% uptime SLA guarantee.

Stream provides UI components and state handling that make it easy to build video calling for your app. All calls run on Stream’s network of edge servers around the world, ensuring optimal latency and reliability.

## 📕 Tutorials
With Stream’s video components, you can use their SDK to build in-app video calling, audio rooms, audio calls, or live streaming. The best place to get started is with their tutorials:

- **[Video & Audio Calling Tutorial](https://getstream.io/video/docs/flutter/video-calling-guide/)**
- **[Audio Rooms Tutorial](https://getstream.io/video/docs/flutter/audio-rooms/)**
- **[Livestreaming Tutorial](https://getstream.io/video/docs/flutter/livestreaming/)**

If you’re interested in customizing the UI components for the Video SDK, check out the [UI Component Docs](https://getstream.io/video/docs/flutter/ui-components-overview/).

## 👩‍💻 Free for Makers 👨‍💻
Stream is free for most side and hobby projects. To qualify, your project/company needs to have < 5 team members and < $10k in monthly revenue. Makers get $100 in monthly credit for video for free. For more details, check out the [Maker Account](https://getstream.io/maker-account).

## 💡Supported Features💡
Here are some of the features we support:

- Developer experience: Great SDKs, docs, tutorials and support so you can build quickly
- Edge network: Servers around the world ensure optimal latency and reliability
- Chat: Stored chat, reactions, threads, typing indicators, URL previews etc
- Security & Privacy: Based in USA and EU, Soc2 certified, GDPR compliant
- Dynascale: Automatically switch resolutions, fps, bitrate, codecs and paginate video on large calls
- Native device integration: CallKit support on iOS and OS integration for Android
- Screensharing
- Active speaker
- Custom events
- Geofencing
- Notifications and ringing calls
- Opus DTX & Red for reliable audio
- Webhooks & SQS
- Backstage mode
- Flexible permissions system
- Joining calls by ID, link or invite
- Enabling and disabling audio and video when in calls
- Flipping, Enabling and disabling camera in calls
- Enabling and disabling speakerphone in calls
- Push notification providers support
- Call recording
- Broadcasting to HLS

## 🗺️ Roadmap
Video roadmap and changelog is available [here](https://github.com/GetStream/protocol/discussions/127).

## 💼 We are hiring!
We’ve recently closed a [$38 million Series B funding round](https://techcrunch.com/2021/03/04/stream-raises-38m-as-its-chat-and-activity-feed-apis-power-communications-for-1b-users/) and we keep actively growing. Our APIs are used by more than a billion end-users, and you’ll have a chance to make a huge impact on the product within a team of the strongest engineers all over the world. Check out our current openings and apply via [Stream’s website](https://getstream.io/team/#jobs).

## License
```
Copyright (c) 2014-2023 Stream.io Inc. All rights reserved.

Licensed under the Stream License;
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   https://github.com/GetStream/flutter-video-samples

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
