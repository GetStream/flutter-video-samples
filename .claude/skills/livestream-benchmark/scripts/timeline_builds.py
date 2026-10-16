"""Records the Dart timeline of a running app and counts which widgets build in each frame.

Usage: python3 timeline_builds.py <ws://.../ws> <seconds> [--widgets A,B,...] [--no-widget-builds] [-o timeline.json]

Use it to see *what* rebuilds (for example how many message rows build per
frame), not how long frames take: per-widget build events make builds and
layout several times slower. For timings, rerun with --no-widget-builds, or
use a cpu_sample.py capture or the benchmark recording.

The timeline is a ring buffer. Keep captures short (under ~20 s with widget
builds on) or frames from the start of the window are silently dropped.
"""
import argparse
import asyncio
import collections
import json

import websockets

from vm_service import VmService

DEFAULT_WIDGETS = ('StreamMessageItem', 'DefaultStreamMessageItem', 'StreamMessageText', 'DefaultStreamMessageText',
                   'MarkdownBody', 'StreamMessageFooter', 'StreamUserAvatar')


async def record(uri, seconds, widget_builds):
    async with websockets.connect(uri, max_size=None) as ws:
        vm = VmService(ws)
        isolate = await vm.main_isolate()
        await vm.call('setVMTimelineFlags', recordedStreams=['Dart', 'Embedder'])
        if widget_builds:
            await vm.call('ext.flutter.profileWidgetBuilds', isolateId=isolate, enabled='true')
        await vm.call('clearVMTimeline')
        print(f'recording {seconds:.0f}s ...', flush=True)
        await asyncio.sleep(seconds)
        timeline = await vm.call('getVMTimeline')
        if widget_builds:
            await vm.call('ext.flutter.profileWidgetBuilds', isolateId=isolate, enabled='false')
        await vm.call('setVMTimelineFlags', recordedStreams=[])
    return timeline['traceEvents']


def report(events, widgets):
    # Frames are the BUILD spans; each widget build counts towards the frame whose span contains it.
    builds = sorted((e['ts'], e['ts'] + e.get('dur', 0)) for e in events if e.get('name') == 'BUILD' and e.get('ph') == 'X')
    per_frame = collections.defaultdict(collections.Counter)
    for e in events:
        if e.get('ph') in ('B', 'X') and e.get('name') in widgets:
            for i, (start, end) in enumerate(builds):
                if start <= e['ts'] <= end:
                    per_frame[i][e['name']] += 1
                    break
    print(f'BUILD spans: {len(builds)}, frames building a listed widget: {len(per_frame)}')
    totals = collections.Counter()
    for c in per_frame.values():
        totals.update(c)
    print('builds in window:', dict(totals))
    for name in widgets:
        counts = sorted(c[name] for c in per_frame.values() if c[name])
        if counts:
            print(f'{name} builds per frame that built it (min/median/max):',
                  counts[0], counts[len(counts) // 2], counts[-1])
    frame_ms = sorted((end - start) / 1000 for start, end in builds)
    if frame_ms:
        print(f'BUILD ms p50 {frame_ms[len(frame_ms) // 2]:.1f}  p90 {frame_ms[int(len(frame_ms) * .9)]:.1f}  '
              f'max {frame_ms[-1]:.1f}')
    print('events by name (top 15):',
          collections.Counter(e['name'] for e in events if e.get('ph') in ('B', 'X')).most_common(15))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('uri')
    parser.add_argument('seconds', type=float)
    parser.add_argument('--widgets', default=','.join(DEFAULT_WIDGETS))
    parser.add_argument('--no-widget-builds', action='store_true')
    parser.add_argument('-o', '--out', default='timeline.json')
    args = parser.parse_args()
    events = asyncio.run(record(args.uri, args.seconds, not args.no_widget_builds))
    with open(args.out, 'w') as f:
        json.dump(events, f)
    report(events, tuple(args.widgets.split(',')))


if __name__ == '__main__':
    main()
