#!/usr/bin/env bash
# Runs the standard load sequence against one build:
#   idle baseline, three 1-message loads, one 5-message load, then a 1-message
#   load with a 30 s CPU-sample capture of the viewer.
# Loads start a fixed gap after the previous one ended, so every run starts
# from the same quiet state.
#
# Usage: run_sequence.sh <label> <viewer VM service ws:// URI | viewer `flutter run` log>
#
# Needs the run_load.sh environment (STREAM_API_SECRET, BUDDY_DIR) and
# Python with `websockets`. Optional: IDLE=60 GAP=65 OUT_DIR=.
set -euo pipefail

label=${1:?usage: run_sequence.sh <label> <ws-uri|flutter-run-log>}
target=${2:?usage: run_sequence.sh <label> <ws-uri|flutter-run-log>}
here=$(cd "$(dirname "$0")" && pwd)
out_dir=${OUT_DIR:-.}
export OUT_DIR=$out_dir

if [[ $target == ws://* ]]; then
  ws=$target
else
  # `flutter run` prints the VM service as http://127.0.0.1:<port>/<token>=/
  ws=$(grep -o "http://127.0.0.1:[0-9]*/[^/]*=/" "$target" | head -1 | sed 's#^http#ws#; s#/$#/ws#')
fi
[[ -n $ws ]] || { echo "no VM service URI found in $target" >&2; exit 1; }

wait_gap() {
  local end
  end=$(date -j -f %H:%M:%S "$(cat "$out_dir/load-$1.end")" +%s 2>/dev/null ||
    date -d "$(cat "$out_dir/load-$1.end")" +%s)
  until (( $(date +%s) - end >= ${GAP:-65} )); do sleep 2; done
}

sleep "${IDLE:-60}"
for run in 1 2 3; do
  MSGS=1 "$here/run_load.sh" "$label-$run"
  wait_gap "$label-$run"
done
MSGS=5 "$here/run_load.sh" "$label-5"
wait_gap "$label-5"

python3 "$here/cpu_sample.py" "$ws" 30 -o "$out_dir/cpu-$label.json" > "$out_dir/cpu-$label.log" 2>&1 &
cpu=$!
sleep 2
MSGS=1 "$here/run_load.sh" "$label-cpu"
wait "$cpu"
python3 "$here/cpu_summary.py" "$out_dir/cpu-$label.json"

for run in 1 2 3 5 cpu; do
  echo "$label-$run $(cat "$out_dir/load-$label-$run.start")-$(cat "$out_dir/load-$label-$run.end")"
done
