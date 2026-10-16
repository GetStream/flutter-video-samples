"""Pins the sample's SDK git dependency overrides to the commits of one build under test.

Usage: python3 pin_refs.py [--chat REF] [--video REF] [--webrtc REF] [--core REF] [pubspec.yaml]

Rewrites the `ref:` of every git override pointing at that repository
(stream-chat-flutter, stream-video-flutter, webrtc-flutter,
stream-core-flutter). Leaves the others alone. Defaults to the
chat_rooms_with_livestream pubspec. Run `flutter pub get` and `flutter analyze
lib` afterwards. Use full or unambiguous short SHAs, not branch names, so the
build is reproducible.
"""
import argparse
import re

REPOS = {'chat': 'stream-chat-flutter', 'video': 'stream-video-flutter', 'webrtc': 'webrtc-flutter',
         'core': 'stream-core-flutter'}

parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
for key in REPOS:
    parser.add_argument(f'--{key}')
parser.add_argument('pubspec', nargs='?', default='packages/chat_rooms_with_livestream/pubspec.yaml')
args = parser.parse_args()

with open(args.pubspec) as f:
    source = f.read()
for key, repo in REPOS.items():
    ref = getattr(args, key)
    if not ref:
        continue
    pattern = r'(url: https://github\.com/GetStream/%s\.git\n(?:\s+path: .*\n)?\s+ref: )\S+' % repo
    source, count = re.subn(pattern, lambda m: m.group(1) + ref, source)
    print(f'{repo}: {count} override(s) -> {ref}' if count else f'{repo}: no git override with a ref found')
with open(args.pubspec, 'w') as f:
    f.write(source)
