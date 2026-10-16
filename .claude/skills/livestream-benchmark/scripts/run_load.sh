#!/usr/bin/env bash
# Runs one bot load against the benchmark call with stream-video-buddy's
# load test, and stops it once every bot has sent its messages, so the bots
# leave again.
#
# Usage: run_load.sh <label>
#
# Required environment:
#   STREAM_API_SECRET  The app's API secret. The load test mints one token per
#                      bot with it and never logs it. Never write it to a file.
#   BUDDY_DIR          Your stream-video-buddy checkout.
# Optional environment (defaults are the load used for the October 2026 runs):
#   MSGS=1 PARTICIPANTS=50 TABS=4 SEED=bob HOLD=180
#   CALL_ID=bench-livestream-3 CALL_TYPE=livestream
#   CHANNEL_ID=backstage-lounge CHANNEL_TYPE=livestream
#   STREAM_API_KEY  Defaults to the sample's key in lib/env/env.dart.
#   OUT_DIR=.       Where load-<label>.{log,start,end} are written.
set -euo pipefail

label=${1:?usage: run_load.sh <label>}
: "${STREAM_API_SECRET:?set STREAM_API_SECRET, the load test mints the bot tokens with it}"
: "${BUDDY_DIR:?set BUDDY_DIR to your stream-video-buddy checkout}"
out_dir=${OUT_DIR:-.}
call_id=${CALL_ID:-bench-livestream-3}
log=$out_dir/load-$label.log

date +%H:%M:%S > "$out_dir/load-$label.start"
(
  cd "$BUDDY_DIR"
  exec node benchmark/load-test.js \
    --api-key "${STREAM_API_KEY:-xf5bwmvkbysn}" \
    --call-id "$call_id" --call-type "${CALL_TYPE:-livestream}" \
    --participants "${PARTICIPANTS:-50}" --tabs "${TABS:-4}" \
    --chat-channel-id "${CHANNEL_ID:-backstage-lounge}" \
    --chat-channel-type "${CHANNEL_TYPE:-livestream}" \
    --message-count "${MSGS:-1}" --hold "${HOLD:-180}" --seed "${SEED:-bob}"
) > "$log" 2>&1 &
pid=$!

# The load test prints "Holding the call" once every message is sent.
until grep -qE "Holding the call|Error" "$log"; do
  kill -0 "$pid" 2>/dev/null || break
  sleep 1
done
kill -INT "$pid" 2>/dev/null || true
sleep 3
kill -9 "$pid" 2>/dev/null || true
pkill -9 -f "node benchmark/load-test.js.*--call-id $call_id" 2>/dev/null || true
date +%H:%M:%S > "$out_dir/load-$label.end"

grep -E "joined in|chat send|Error" "$log" || true
