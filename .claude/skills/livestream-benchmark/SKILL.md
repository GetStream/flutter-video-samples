---
name: livestream-benchmark
description: Run and compare performance benchmarks of the Stream Chat and Video Flutter SDKs with the chat_rooms_with_livestream sample - on-device load runs with bot traffic, Dart CPU sampling, timeline traces of what rebuilds, VM micro-benchmarks, and A/B comparisons of SDK commits or PRs. Use when the user wants to measure jank, CPU or rebuild cost, check whether an SDK change or PR made the livestream faster or slower, compare main branches across days, or set up a benchmark run on devices. For writing up a single recording, use bench-report.
---

# Livestream benchmark

How to measure the SDKs' performance with the `chat_rooms_with_livestream`
sample, compare builds, and avoid fooling yourself. This skill covers
*running* benchmarks. To turn one recording into a report page, use the
`bench-report` skill.

The recording format is documented on the `Bench` class in
`packages/chat_rooms_with_livestream/lib/bench/bench.dart` and summarised in
`lib/bench/README.md`. Read the README before the first run.

## Pick the kind of benchmark

| Question | Benchmark | Tool |
|---|---|---|
| Does the app jank under real traffic? Did a change help? | On-device load run | Benchmark mode + `scripts/run_sequence.sh` |
| Which Dart code takes the CPU during a load? | CPU sampling | `scripts/cpu_sample.py`, `scripts/cpu_summary.py` |
| What rebuilds per frame, and how often? | Timeline trace | `scripts/timeline_builds.py`, or DevTools |
| How much does one SDK function cost at N items? | VM micro-benchmark | a throwaway `flutter test` file (below) |
| Does a widget resubscribe or rebuild when it shouldn't? | Counting test | a widget test that counts listens or builds |

Use them together. The load run tells you *whether* something changed. CPU
samples and timelines tell you *why*. Micro-benchmarks and counting tests
prove a fix in isolation and stay deterministic. Device numbers never are.

## On-device load runs

### Setup

- **Two physical devices.** The host publishes the stream and the viewer
  watches it, and both run the same build. Measure on the viewer unless the
  question is about publishing.
  - Don't use a simulator as the host: it sends black video, so the viewer
    renders 2-4 frames per second instead of about 30, and its numbers can't be
    compared with any other run.
  - A physical Android device works as either role.
- **Profile builds only:**

  ```bash
  flutter run --profile -d <device> --dart-define-from-file=bench_env.json --dart-define=STREAM_BENCH=true
  ```

  - `bench_env.json` holds `STREAM_BENCH_CALL_ID` and the user tokens. Use the
    same file and call id for both devices and for every build you compare.
  - Build the devices one at a time from the same checkout. They share `build/`.
- **Bot load.** stream-video-buddy's `benchmark/load-test.js` (see its
  `benchmark/README.md`) joins N bots to the call and has each send chat
  messages. `scripts/run_load.sh` wraps it with the load used so far, and stops
  the load once the messages are sent, so the bots leave again:
  - 50 bots in 4 tabs
  - call `bench-livestream-3`, livestream channel `backstage-lounge`
  - `--seed bob`, so every run uses the same bot users
  - It needs `STREAM_API_SECRET` and `BUDDY_DIR` in the environment.
- **Python 3 with `websockets`** for the VM service scripts.

### Starting the stream

- Benchmark mode can't run alongside marionette (`BenchBinding` and
  `MarionetteBinding` both replace the binding), so a person has to tap through
  the app:
  - on the host: sign in as a creator, open the room, tap **Go live**
  - on the viewer: sign in as a member, open the same room, tap **Watch now**
- Don't sign in or type anything on the devices yourself.
- Ask the user to start the stream. Wait until the recordings show it is up
  before starting any load:

  ```bash
  D=/sdcard/Android/data/com.example.chat_rooms_with_livestream/files/bench
  f=$(adb -s <host> shell ls $D | tail -1)
  adb -s <host> shell cat $D/$f | grep -c '"label":"live"'
  f=$(adb -s <viewer> shell ls $D | tail -1)
  adb -s <viewer> shell cat $D/$f | grep -c '"label":"first_video_frame"'
  ```

  A viewer recording with `viewer_attach` but no `first_video_frame`, and
  samples whose `calls` list is empty, never joined. Check the `flutter run`
  log for an exception before blaming the build.

### The sequence

`.claude/skills/livestream-benchmark/scripts/run_sequence.sh <label> <viewer flutter-run log or ws:// URI>` runs,
for one build:

1. 60 s idle with the stream playing (the baseline)
2. three loads with 1 message per bot
3. one load with 5 per bot
4. a 1-message load with a 30 s CPU capture of the viewer

Each load starts 65 s after the previous one ended. Use the same sequence for
every build you compare, and change the labels, not the parameters.

### Comparing builds

Pin each build's SDK commits with `scripts/pin_refs.py`, then:
- `flutter pub get`
- `flutter analyze lib`, to catch API changes before you spend a device run
- rebuild both devices

Example, comparing two days of video and webrtc with chat held fixed:

```bash
python3 .claude/skills/livestream-benchmark/scripts/pin_refs.py --chat <master-sha> --video <yesterday-sha> --webrtc <yesterday-sha>
```

- **Change one thing per step.** For example:
  - A = baseline
  - B = A with today's video and webrtc
  - C = B with the chat PR

  Then A→B and B→C each isolate one change.
- **Check what a PR is based on.** A PR stacked on another unmerged PR,
  compared with master, measures both together. Say so, or add a build for the
  base PR.
- Pin SHAs, never branch names, and write them down with the results.
- Keep the sample's `pubspec.yaml` changes out of commits unless the user asks.
  Save the original first.

### Analysis

Pull the recordings, viewer and host into separate folders per build:

```bash
adb -s <device> pull /sdcard/Android/data/com.example.chat_rooms_with_livestream/files/bench/<file> <dir>/
python3 .claude/skills/livestream-benchmark/scripts/compare_bursts.py A=<a.jsonl> B=<b.jsonl> C=<c.jsonl>
```

`compare_bursts.py` prints every message burst, totals over all bursts, and
the idle stretch, per build. Report the totals, and use the bursts to show the
spread. For a full page on one recording, hand it to `bench-report`.

Before you trust a number from an analysis script, check it against what the
user saw on the device. A script once reported 0 participants because it read
a field that doesn't exist (`call` instead of the `calls` list) and defaulted
to 0.

## CPU sampling

```bash
python3 .claude/skills/livestream-benchmark/scripts/cpu_sample.py <ws://…/ws> 30 -o cpu.json "MutableStateEmitterImpl.value=" "drawFrame"
python3 .claude/skills/livestream-benchmark/scripts/cpu_summary.py cpu.json
```

- Get the VM service URI from the `flutter run` log: rewrite
  `http://127.0.0.1:<port>/<token>=/` as `ws://…/<token>=/ws`.
- **Scope:** it samples the main isolate only, so it measures Dart CPU on the UI
  thread. Raster and native work aren't in it.
- **Output:** each focus string gets its self-time leaves and direct callees.
  `cpu_summary.py` gives CPU, how many times `CallState` was replaced, and frames
  per second.
- Start the capture, then the load, so the window covers the burst.

## Timeline traces

```bash
python3 .claude/skills/livestream-benchmark/scripts/timeline_builds.py <ws://…/ws> 15 --widgets DefaultStreamMessageItem,StreamMessageText
```

- **What it shows:** how many times each listed widget built per frame. Use it
  to prove something rebuilds too often, for example every message row rebuilding
  for one new message.
- **Timings:** for frame times, rerun with `--no-widget-builds`, or use the
  recording.
- **DevTools:** gives the same data interactively. The recording's `mark`s drop
  `bench:<label>` events on the timeline, so a trace lines up with the file.

## VM micro-benchmarks

For "what does this function cost at 0, 100, 1000 and 5000 items", write a
throwaway test next to the package's tests, and don't commit it:

```dart
test('copyFromMetadata', () {
  for (final n in [0, 100, 1000, 5000]) {
    final inputs = [for (var i = 0; i < 300; i++) build(n)];
    run(inputs.take(100)); // warm-up: the JIT compiles the hot path first
    final samples = [for (final input in inputs) time(() => subject(input))]..sort();
    print('BENCH n=$n median=${samples[samples.length ~/ 2]}us');
  }
});
```

- Report medians, not means: GC pauses produce outliers.
- Build the inputs before timing, so allocation isn't counted.
- Measure the baseline from a separate git worktree at the base commit. Don't
  stash or switch branches in the one you're working in, because the user may
  have their own stashes.
- These run on the JIT. Compare them with each other, never with device
  numbers. They also don't include the work they trigger elsewhere, such as
  downstream `==` checks or rebuilds, so measure that separately.

## How benchmarking changes the result

Every one of these produced a wrong conclusion at least once. Check them
before reporting a number, and say which apply to it.

**Build and device**
- **Debug builds** run on the JIT with assertions on. Their frame and CPU
  numbers mean nothing. Profile mode needs a physical device.
- **The simulator host's black video** cuts the viewer's frame rate, which
  changes jank percentages and percentiles.
- **Accessibility services turn on Flutter semantics,** which costs about
  1 ms per frame. Password managers like 1Password do this. Note it when
  comparing devices.
- **Charging and temperature.** Thermal state and charging change CPU
  frequency. Configs run back to back on a warming device aren't strictly
  comparable. Note it, and alternate the order of configs across repeats.

**The recorder** (it runs inside the app it measures)
- **Its own cost:**
  - each second: one method-channel call, one JSON line and a flush
  - a 50 ms timer that measures event-loop lag
  - timing `otherParticipants` once per sample
  - the README lists these
  This is small, but it's present in every run, so it cancels out only when
  every build records the same way.
- **`BenchBinding` wraps the binary messenger** to time every platform-channel
  call. That adds a little to every channel call.
- **It's registered as the video SDK's external logger.** An exception in the
  recorder surfaces inside SDK code. A flush race once threw "StreamSink is
  bound to a stream" from a warning logged during join, and the viewer never
  connected. Lines written during a flush are now buffered. If a run behaves
  strangely, look for `Bench.` frames in the stack.
- **Log capture is capped at 20 lines per second.** Above that, lines are
  counted in `logsDropped`, not written.

**Profilers**
- **`profileWidgetBuilds` and `profileRenderObjectLayouts`** inflate builds and
  layout several times over: one `RenderParagraph` layout went from 0.6 to
  3.2 ms. Slivers build their children during layout, so both look slower. Use
  these flags to see *what* runs, never for timings.
- **The VM timeline is a ring buffer.** With widget builds traced it held only
  about 85 frames, so one read at the end of a burst silently lost its start.
  Keep captures short, or drain the timeline every ~2 s.
- **CPU sampling** costs a little CPU itself, and covers only the isolate you
  sample. Run it during one load of the sequence, not all of them, and compare
  captures taken the same way.

**The load and the noise**
- **Identical runs vary a lot.** Three identical 1-message runs of one build
  ranged from 2.5% to 12.7% jank. One run per build can't show a difference of
  a few points.
  - Repeat each build at least three times, alternating the order of builds.
  - Compare totals across runs.
  - Before calling an outlier a regression or a fix, look at its seconds: CPU,
    event-loop lag, stalls and call-state updates. A busy device (high CPU and
    lag, nothing in the app) points to noise.
- **The same load command doesn't always deliver the same load.** The
  5-message runs delivered 241, 160 and 225 of 250 messages. Compare jank per
  message, and say when loads differ.
- **The load has to stress the code you changed.** 50 messages at ~10 per
  second with a steady 52 participants showed nothing for changes aimed at:
  - participant churn
  - unchanged events
  - message-row rebuilds

  Match the load to the change: more messages per second, bots joining and
  leaving mid-run, or a bigger participant count.
- **Look at build vs raster.** Build time up with raster flat is Dart or widget
  work. Raster up is the GPU. Only the first can be blamed on SDK state
  handling.

## Safety

- **The API secret** stays in the `STREAM_API_SECRET` environment variable.
  Never put it in a script, a file, a report, or a chat reply.
- **The devices are the user's.** Don't type credentials or PINs on them, and
  ask before installing a build on a device that isn't already set up for
  benchmarking.
- **Reports** list commit SHAs and the load parameters, never secrets or user
  tokens.
