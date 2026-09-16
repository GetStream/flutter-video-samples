# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

A Melos monorepo of **standalone Flutter sample apps** for [Stream Video](https://getstream.io/video).
Each app under `packages/` is a self-contained, runnable showcase of one use case — not a library,
not a shared-code project. Samples deliberately duplicate boilerplate (login screen, `AppConfig`,
permission requests) so a developer can copy a single folder and run it.

```
packages/
  audio_room_with_chat/          Audio room + Stream Chat
  chat_with_video_call/          Chat app with video calling
  video_livestream_feed/         Livestream discovery feed + go-live host flow
  video_livestream_overlay/      Livestream with video filters/overlay
  video_livestream_with_call/    Viewer calls the host mid-broadcast
  video_multicall/               Multiple concurrent calls / audio session handoff
  video_ringing_with_chat_push/  Ringing + push notifications (Firebase/CallKit)
  quickstart_kits/               Starter versions of samples (tutorial starting points)
```

## Use the Stream skills

**Never write Stream SDK code from memory.** The Video and Chat SDKs move fast and the samples
track the latest release. Before adding or changing SDK usage:

- **`stream-docs`** — look up the actual API (`StreamVideo`, `Call`, `LivestreamPlayer`,
  `StreamCallContainer`, call types, permissions, events). Answers come from live getstream.io docs
  with citations. Use it for "how do I …" and for confirming a method/parameter still exists.
- **`stream`** — the router skill. Use it for Stream CLI work (querying calls/channels/users,
  app configuration in the dashboard, generating tokens) and when a task spans products.
  It installs and routes to peer packs on demand.
- **`stream-flutter`** — peer pack for Stream **Chat** in Flutter (`stream_chat_flutter` wiring,
  widget blueprints). Installed on demand via the `stream` router.
- **`stream-builder`** — only when explicitly asked for; it scaffolds new apps and is not the
  normal path for editing an existing sample here.

Also available: **`dart-cognitive-complexity`** for keeping sample code readable — samples are
teaching material, so favour flat, obvious code over clever abstractions.

If a local checkout of `stream-video-flutter` / `stream-chat-flutter` exists as a sibling directory,
reading the SDK source is the fastest way to confirm an exact signature. Docs first, source to verify.

## Building and running

Per-sample (the normal path — each package is an ordinary Flutter app):

```bash
cd packages/<sample> && flutter pub get && flutter run
```

Workspace-wide via Melos (`melos.yaml`, root `pubspec.yaml` pins `melos: ^3.0.0`):

```bash
melos bootstrap
```

```bash
melos run lint:all
```

Available scripts: `analyze`, `analyze:warnings`, `format` (check-only), `format:fix`,
`lint:all` (analyze + format check), `test` (packages with a `test/` dir), `build:android`,
`build:ios`, `clean:flutter`.

Notes and gotchas:

- **Bootstrap first.** A fresh checkout has no `.dart_tool/`, and without it `dart analyze` and
  `dart format` misreport — you get `Failed to resolve package URI "package:flutter_lints/..."`
  warnings and spurious language-version parse errors.
- `melos run format` never writes (it passes `--output=none`); use `format:fix` to apply.
- The tree predates the current Dart formatter, so `melos run format` reports diffs in most
  samples today. Don't mass-reformat as a side effect of an unrelated change — format only the
  files you touched, or do the reformat as its own commit.
- Most samples need **two devices** (host + viewer, caller + callee). Verify on real devices or
  two simulators/emulators — a single device cannot demonstrate them.
- `video_ringing_with_chat_push` additionally needs Firebase config and APNs/CallKit setup; see its
  README before touching it.

## Conventions for samples

Follow the existing shape rather than inventing a new one. A sample is:

- `lib/app_config.dart` — a single `AppConfig` class of `static const` values: `streamApiKey`,
  user ids/names/tokens, call ids. Header doc comment explains how to swap in your own credentials,
  and states that the bundled demo credentials are **public demo values**.
- `lib/main.dart` — permission request, `StreamVideo(...)` init, a simple user-picker login screen,
  `StreamVideo.reset(disconnect: true)` on logout/re-login.
- One screen per file at the top level of `lib/` (`home_screen.dart`, `host_*_screen.dart`,
  `viewer_*_screen.dart`), widgets in their own files. Only larger samples use `lib/screens/`.
- `analysis_options.yaml` including `package:flutter_lints/flutter.yaml` with `build/**` excluded.
- `pubspec.yaml` with `publish_to: "none"`, and Stream dependencies pinned to the same minor as
  every other sample (currently `^1.6.0` for `stream_video_*`).

All samples share the public demo API key `mmhfdzb5evj2` and its pre-generated user tokens. Do not
introduce real credentials, and do not commit secrets.

### README per sample

Each sample has its own `README.md`. Newer samples follow this structure — match it:

`# <Name> Example` → intro + link to the matching cookbook/tutorial page → `## Use Case` →
`## How It Works` (numbered, naming the actual SDK calls) → `## Running the App` →
`## Key Files` → `## Configuration` → `## Dependencies` → `## Notes`.

Include the callout that demo credentials are publicly accessible. When adding a new sample, also
add it to the list at the top of the root `README.md`.

## SDK version bumps

Version-bump commits (e.g. "v1.6.0 adjustments") touch **every** sample: update the Stream
dependency versions in each `pubspec.yaml` (including `quickstart_kits/*`), apply any API changes,
then analyze and run the affected samples. Keep versions aligned across all packages.

## Before finishing

```bash
melos run lint:all
```

Run the sample you changed on a device if the change is behavioural — these apps exist to be run,
and a sample that compiles but doesn't work is worse than no sample.
