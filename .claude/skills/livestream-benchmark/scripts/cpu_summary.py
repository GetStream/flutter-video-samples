"""One-line summary of a cpu_sample.py capture: Dart CPU, call-state sets and frames per second.

Usage: python3 cpu_summary.py <cpu-samples.json> [more.json ...]

The call-state setter count is how often stream_video's CallState was
replaced; each set notifies every partial-state subscription.
"""
import json
import sys

from vm_service import function_name

for path in sys.argv[1:]:
    with open(path) as f:
        s = json.load(f)
    stamps = [x['timestamp'] for x in s['samples']]
    secs = (max(stamps) - min(stamps)) / 1e6
    period_ms = s['samplePeriod'] / 1000
    names = {i: function_name(s, i) for i in range(len(s['functions']))}

    def count(key):
        return sum(any(key in names[i] for i in x['stack']) for x in s['samples'])

    core_pct = len(stamps) * period_ms / (secs * 1000) * 100
    print(f'{path}: {secs:.0f}s, ~{core_pct:.1f}% of a core; '
          f'call-state sets {count("MutableStateEmitterImpl.value=") / secs:.1f}/s; '
          f'frames {count("WidgetsBinding.drawFrame") / secs:.1f}/s')
