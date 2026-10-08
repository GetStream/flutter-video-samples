# Benchmark mode

Records what the app, both Stream SDKs and the device are doing during a
livestream load test, into one JSON-lines file per app launch. The same build
records the **host** side (publishing) and the **viewer** side (subscribing) -
the role comes from which screen joins the call.

Off by default. Without `STREAM_BENCH=true` nothing is subscribed or written.

## Build

Always profile mode. Debug builds run on the JIT with assertions on, so frame
and CPU numbers from them are meaningless.

```bash
flutter run --profile \
  --dart-define-from-file=bench_env.json \
  --dart-define=STREAM_BENCH=true
```

`bench_env.json` holds `STREAM_API_KEY`, the `STREAM_TOKEN_0x` tokens and
`STREAM_BENCH_CALL_ID` (see `lib/env/env.dart` and `newLiveCallId`). Use the
same file for the host and the viewer build.

## Run

1. Launch both devices. A `REC` pill appears bottom-left; recording starts at
   launch, so the time before sign-in is your idle baseline.
2. Host: sign in as a creator, open the room, **Go live**. Viewer: sign in as a
   member, open the same room, **Watch now**.
3. Let it settle for a minute with no bots, which gives you a baseline.
4. Let the backend add participants however it likes - one batch of 10k,
   several batches, a trickle. There is nothing to tap: the recorder watches
   the participant count and marks each change itself (below).
5. After the bots leave and things settle, end the stream on the host.
6. Tap **Share** on each device, or pull the file:

```bash
# Android - app-specific external storage, works on a profile build
adb pull /sdcard/Android/data/com.example.chat_rooms_with_livestream/files/bench/ .
```

On iOS use Share (AirDrop / Files). The file is in the app's Documents
directory under `bench/`.

Tap the red dot to collapse the pill if it covers something.

## What's in the file

Each line is a JSON object; `t` is the line type and `ms` is milliseconds since
recording started (monotonic, use it to line up lines). See the doc comment on
`Bench` in `bench.dart` for every line type. The main ones:

| `t` | When | Contents |
|---|---|---|
| `s` | every 1 s | UI frames (count, jank, build/raster p50/p90/max), event-loop lag, RSS, process CPU %, threads, thermal, battery; per call: server participant count, participants held in client state, state emissions and SDK events per second by type, time to compute `otherParticipants`; chat events per second by type, loaded/pinned message counts, watchers |
| `rtc` | every SDK stats report (~2 s) | publisher: per-simulcast-layer resolution, fps, kbps, quality-limitation reason and its per-window bandwidth/cpu seconds, encode ms/frame, frames and keyframes encoded in the window, resolution changes, reported `scalabilityMode`, encoder implementation, NACK/PLI; the camera source's size, fps and frames delivered (`src`); SFU-reported RTT, jitter, loss. Subscriber: resolution, fps, kbps, loss, jitter-buffer delay, decode ms/frame, dropped frames, freezes. Selected candidate pair RTT and available bandwidth |
| `mark` | app events and detected load changes | `host_attach`, `host_joined`, `go_live_tap`/`go_live_done`, `live`, `first_publish_frame`, `viewer_attach`, `first_video_frame`, `end_stream_tap`, `*_detach`; `connection_quality` when the SFU re-rates this device; load: `ramp_start`, `plateau`, `load_up`/`load_down` |
| `status` | on change | call status (Joined, Reconnecting, Migrating, ...), chat websocket status |
| `life` | on change | app lifecycle, memory-pressure warnings |
| `log` | as they happen | SDK warnings and errors, plus the Video SDK's info lines tagged `[verify]` (publish encodings requested and applied, capture size path, encoder scalability mode after 5 s and 20 s, subscriptions sent, subscription watchdog at 3 s and 10 s), capped at 20 per second (the cap is reported as `logsDropped`) |
| `native` | as they happen | a platform-channel call whose round trip took 50 ms or more: channel, method, start and duration. Capped at 20 per second (`nativeDropped`). Per-second totals (`calls`, `slow`, `maxMs`, `maxCall`) are in each `s` line under `native` |
| `stall` | when the Dart event loop was blocked 100 ms or more | how long (`lagMs`), when it started (`fromMs`), and the native calls in flight or finishing during it |

`dev` fields differ by platform: Android also reports Java/native heap, PSS
(every 10 s), battery temperature and current, and thermal headroom; iOS
reports `footprintMb` (the number jetsam kills on).

### Load marks

Derived once a second from the larger of the server participant count and the
participants the client holds (`load` in each call sample), so they appear the
same way however the backend adds participants:

- `ramp_start` - the count started moving up or down after being steady
  (by at least 2% or 10 participants over 5 s).
- `plateau` - it has held steady for 10 s since; carries `from`, the final
  `participantCount`, `rampSeconds`, and `endedSecondsAgo` (the mark is written
  once the plateau is confirmed, ~10 s after the ramp actually ended). Batches
  give one ramp/plateau pair each; a slow trickle is one long ramp.
- `load_up` / `load_down` - the count crossed 10, 50, 100, 250, 500, 1k, 2k, 3k,
  5k, 7.5k, 10k, 15k or 20k, giving comparable points across runs.

Marks also drop `bench:<label>` instant events on the Dart timeline, so a
DevTools performance trace recorded at the same time lines up with the file.

## What it costs

On top of the app's normal work, one sample per second: one method-channel call,
one JSON line (~1-2 KB) and a flush; plus a 50 ms timer for event-loop lag. The
`otherParticipants` timing runs once per sample, not on every state update, so
the benchmark does not add the per-update cost it is trying to measure.

### Native call timing

In benchmark mode `main()` installs `BenchBinding` (`native_calls.dart`), which
wraps the app's binary messenger and times every platform-channel call from the
Dart side, including the WebRTC fork's `FlutterWebRTC.Method` calls the Video
SDK makes. No SDK or fork change is needed.

Since Flutter 3.29 Dart runs on the platform main thread, so a native handler
that blocks that thread blocks Dart too. Read the two line types together:

- A `native` call that overlaps a `stall` is the blocking suspect.
- A slow `native` call with no stall is native work happening off the main
  thread. An asynchronous handler, like the fork's queued audio-session calls,
  replies late without blocking anything.

The timing is a round trip, not time spent on the main thread, and it can't
see work native code starts on its own (for example the audio device module
starting capture), only the Dart calls that were waiting on it. The bench's own
`creator_rooms/bench` channel is left out.
