"""Compares chat-message bursts across benchmark recordings, one recording per build.

Usage: python3 compare_bursts.py <label>=<bench-*.jsonl> [<label>=<bench-*.jsonl> ...]

A burst is a run of one-second samples with `message.new` chat events,
allowing gaps of up to 3 s. For each recording it prints every burst with 5 or
more messages, then totals over all bursts and over the idle stretch before
the first one (from 10 s after the call connected until 3 s before the first
burst). Use the viewer recordings: the numbers are the device's UI thread.
"""
import json
import sys


def chat_messages(sample):
    return (sample.get('chat') or {}).get('events', {}).get('message.new', 0)


def call_load(sample):
    return max((c.get('load') or 0 for c in sample.get('calls') or []), default=0)


def bursts(samples):
    found, current = [], None
    for s in samples:
        if not chat_messages(s):
            continue
        t = s['ms'] / 1000
        if current and t - current[-1]['ms'] / 1000 <= 3:
            current.append(s)
        else:
            current = [s]
            found.append(current)
    return found


def summary(secs):
    framed = [s for s in secs if s['ui'].get('frames')]
    frames = sum(s['ui'].get('frames', 0) for s in secs)
    jank = sum(s['ui'].get('jank', 0) for s in secs)
    p90 = sorted(s['ui'].get('buildP90', 0) for s in framed) or [0]
    worst = sorted(s['ui'].get('buildMax', 0) for s in framed) or [0]
    cpu = [s['dev']['cpuPct'] for s in secs if (s.get('dev') or {}).get('cpuPct') is not None]
    return (f'jank {jank}/{frames} ({100 * jank / max(frames, 1):.1f}%)  buildP90 median {p90[len(p90) // 2]:.1f} ms  '
            f'worst build p90 {worst[int(len(worst) * .9)]:.1f} / max {worst[-1]:.1f} ms  '
            f'cpu {sum(cpu) / max(len(cpu), 1):.0f}%'), jank


for arg in sys.argv[1:]:
    label, _, path = arg.partition('=')
    with open(path) as f:
        events = [json.loads(line) for line in f if line.strip()]
    samples = [e for e in events if e['t'] == 's']
    print(f'\n== {label}  ({path})')
    groups = [g for g in bursts(samples) if sum(map(chat_messages, g)) >= 5]
    for g in groups:
        start, end = g[0]['ms'] / 1000, g[-1]['ms'] / 1000
        secs = [s for s in samples if start <= s['ms'] / 1000 <= end]
        msgs = sum(map(chat_messages, secs))
        text, jank = summary(secs)
        print(f'  burst {start:5.0f}-{end:5.0f}s  msgs {msgs:3d}  {text}  jank/msg {jank / msgs:.2f}  '
              f'load {max(map(call_load, secs))}')
    if not groups:
        print('  no bursts with 5+ messages')
        continue
    in_bursts = [s for g in groups for s in samples if g[0]['ms'] <= s['ms'] <= g[-1]['ms']]
    msgs = sum(map(chat_messages, in_bursts))
    text, jank = summary(in_bursts)
    print(f'  all bursts       msgs {msgs:3d}  {text}  jank/msg {jank / msgs:.2f}')
    connected = next((s['ms'] for s in samples
                      if any(c.get('status') == 'Connected' for c in s.get('calls') or [])), None)
    if connected is not None:
        idle = [s for s in samples if connected + 10000 < s['ms'] < groups[0][0]['ms'] - 3000]
        if idle:
            print(f'  idle ({len(idle)} s)        {summary(idle)[0]}')
