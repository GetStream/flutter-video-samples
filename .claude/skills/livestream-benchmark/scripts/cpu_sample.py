"""Samples the Dart CPU of a running profile build and breaks down time under given functions.

Usage: python3 cpu_sample.py <ws://.../ws> <seconds> [-o cpu-samples.json] [focus-substring ...]

Samples only the main isolate, so this is Dart CPU on the UI thread, not the
whole process. Clears the sample buffer first, so the capture covers exactly
the window you wait for.
"""
import argparse
import asyncio
import collections
import json

import websockets

from vm_service import VmService, function_name


async def capture(uri, seconds):
    async with websockets.connect(uri, max_size=None) as ws:
        vm = VmService(ws)
        isolate = await vm.main_isolate()
        await vm.call('clearCpuSamples', isolateId=isolate)
        print(f'sampling {seconds:.0f}s ...', flush=True)
        await asyncio.sleep(seconds)
        return await vm.call('getCpuSamples', isolateId=isolate, timeOriginMicros=0, timeExtentMicros=2**62)


def report(samples, focuses):
    period_ms = samples['samplePeriod'] / 1000
    stacks = [[function_name(samples, i) for i in s['stack']] for s in samples['samples']]  # leaf first
    print(f'{len(stacks)} samples at {period_ms:.2f} ms ({len(stacks) * period_ms:.0f} ms of CPU)')
    for focus in focuses:
        hits = [s for s in stacks if any(focus in f for f in s)]
        print(f'\n== under {focus!r}: {len(hits)} samples (~{len(hits) * period_ms:.0f} ms)')
        if not hits:
            continue
        print('  leaf (self) frames:')
        for f, c in collections.Counter(s[0] for s in hits).most_common(15):
            print(f'    {c:4d}  {f}')
        callees = collections.Counter()
        for s in hits:
            i = max(j for j, f in enumerate(s) if focus in f)
            if i > 0:
                callees[s[i - 1]] += 1
        print('  called directly from it:')
        for f, c in callees.most_common(10):
            print(f'    {c:4d}  {f}')
        print('  one full stack:', ' < '.join(hits[0][:25]))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('uri')
    parser.add_argument('seconds', type=float)
    parser.add_argument('focus', nargs='*')
    parser.add_argument('-o', '--out', default='cpu-samples.json')
    args = parser.parse_intermixed_args()
    samples = asyncio.run(capture(args.uri, args.seconds))
    with open(args.out, 'w') as f:
        json.dump(samples, f)
    report(samples, args.focus)


if __name__ == '__main__':
    main()
