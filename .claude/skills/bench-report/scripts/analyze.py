#!/usr/bin/env python3
"""Summarise a benchmark-mode recording (lib/bench/ in chat_rooms_with_livestream).

Reads one JSON-lines recording and prints a JSON analysis: run metadata, phases
derived from the participant count and chat traffic, per-phase stats, WebRTC
quality, stalls, jank attribution, grouped SDK logs, data-quality warnings, and
the chart series the report template draws.

    python3 analyze.py <recording.jsonl> [-o analysis.json]

The file format is documented on the `Bench` class in lib/bench/bench.dart.
Python 3.9 compatible, standard library only.
"""

import argparse
import json
import re
import statistics
import sys
from collections import Counter, defaultdict

CHAT_BURST_MSGS = 2      # message.new per second that counts as a chat burst
STALL_MS = 200           # event-loop lag or frame span that counts as a stall
MIN_PHASE_S = 3          # shorter phase runs merge into their neighbour


def load(path):
    lines, bad = [], 0
    with open(path, encoding="utf-8") as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                lines.append(json.loads(raw))
            except ValueError:
                bad += 1  # a truncated last line when the app was killed
    return lines, bad


def med(xs):
    xs = [x for x in xs if x is not None]
    return round(statistics.median(xs), 2) if xs else None


def mean(xs):
    xs = [x for x in xs if x is not None]
    return round(sum(xs) / len(xs), 2) if xs else None


def mx(xs):
    xs = [x for x in xs if x is not None]
    return round(max(xs), 2) if xs else None


def pearson(a, b):
    pairs = [(x, y) for x, y in zip(a, b) if x is not None and y is not None]
    if len(pairs) < 5:
        return None
    xs, ys = zip(*pairs)
    mxv, myv = sum(xs) / len(xs), sum(ys) / len(ys)
    sx = sum((x - mxv) ** 2 for x in xs) ** 0.5
    sy = sum((y - myv) ** 2 for y in ys) ** 0.5
    if sx == 0 or sy == 0:
        return None
    return round(sum((x - mxv) * (y - myv) for x, y in pairs) / (sx * sy), 2)


def primary_call(samples):
    """The call with the most samples; a file normally has one."""
    counts = Counter()
    for s in samples:
        for c in s.get("calls") or []:
            counts[(c.get("callId"), c.get("role"))] += 1
    if not counts:
        return None, None
    (cid, role), _ = counts.most_common(1)[0]
    return cid, role


def call_of(sample, cid):
    for c in sample.get("calls") or []:
        if c.get("callId") == cid:
            return c
    return None


def label_seconds(rows, baseline):
    """Per-second phase label from the load curve and chat traffic."""
    loads = [r["load"] for r in rows]
    base = []
    for i, load in enumerate(loads):
        if load is None:
            base.append("pre-call" if not any(l is not None for l in loads[:i]) else "post-call")
            continue
        # Moving if the count changed by more than 0.5% (min 3) over the last
        # 5 s - backward-looking, so a slow trickle still accumulates.
        earlier = [l for l in loads[max(0, i - 5):i] if l is not None]
        prev = earlier[0] if earlier else load
        delta = load - prev
        if abs(delta) > max(3, int(max(load, prev) * 0.005)):
            base.append("ramp-up" if delta > 0 else "ramp-down")
        else:
            elevated = load > baseline + max(3, int(baseline * 0.02))
            base.append("loaded" if elevated else "baseline")

    # The backward window keeps a ramp going for up to 5 s after the count
    # stops moving; end each ramp at its last actual change instead.
    i = 0
    while i < len(base):
        if not base[i].startswith("ramp"):
            i += 1
            continue
        j = i
        while j + 1 < len(base) and base[j + 1] == base[i]:
            j += 1
        last_change = max(
            (k for k in range(i, j + 1) if k > 0 and loads[k - 1] is not None and loads[k] != loads[k - 1]),
            default=i,
        )
        for k in range(last_change + 1, j + 1):
            elevated = loads[k] > baseline + max(3, int(baseline * 0.02))
            base[k] = "loaded" if elevated else "baseline"
        i = j + 1

    return [
        b + ("+chat" if r["msgs"] >= CHAT_BURST_MSGS and b not in ("pre-call", "post-call") else "")
        for b, r in zip(base, rows)
    ]


def runs(labels):
    out = []
    for i, l in enumerate(labels):
        if out and out[-1][0] == l:
            out[-1][2] = i
        else:
            out.append([l, i, i])
    # Merge short steady runs into the previous one (or the next, at the start).
    changed = True
    while changed and len(out) > 1:
        changed = False
        for k, (l, a, b) in enumerate(out):
            # Ramps are real transitions, so they stay however short they are.
            if b - a + 1 < MIN_PHASE_S and l.split("+")[0] in ("baseline", "loaded"):
                if k > 0:
                    out[k - 1][2] = b
                else:
                    out[k + 1][1] = a
                out.pop(k)
                changed = True
                break
        merged = [out[0]]
        for r in out[1:]:
            if r[0] == merged[-1][0]:
                merged[-1][2] = r[2]
            else:
                merged.append(r)
        out = merged
    return out


def rtc_digest(rtc_lines, t0, t1):
    """Median/total video stats for rtc reports within [t0, t1] seconds."""
    sub = defaultdict(list)
    pub = defaultdict(list)
    qlr = Counter()
    for r in rtc_lines:
        t = r["ms"] / 1000
        if t < t0 or t > t1:
            continue
        for v in (r.get("sub") or {}).get("inVideo") or []:
            for k in ("kbps", "fps", "lossPct", "jitterMs", "jbMs", "decMsPerFrame",
                      "framesDroppedD", "freezesD", "freezeSecD", "w", "h"):
                sub[k].append(v.get(k))
        for a in (r.get("sub") or {}).get("inAudio") or []:
            sub["audioConcealPct"].append(a.get("concealPct"))
        layers = (r.get("pub") or {}).get("outVideo") or []
        if layers:
            pub["kbps"].append(sum(l.get("kbps") or 0 for l in layers))
            top = max(layers, key=lambda l: (l.get("w") or 0) * (l.get("h") or 0))
            for k in ("fps", "w", "h", "encMsPerFrame"):
                pub[k].append(top.get(k))
            pub["pli"].append(sum(l.get("pli") or 0 for l in layers))
            pub["nack"].append(sum(l.get("nack") or 0 for l in layers))
            for l in layers:
                if l.get("qlr"):
                    qlr[l["qlr"]] += 1
        for rem in (r.get("pub") or {}).get("remote") or []:
            if rem.get("kind") == "video":
                pub["remoteRttMs"].append(rem.get("rttMs"))
                pub["remoteFractionLost"].append(rem.get("fractionLost"))
        pair = (r.get("sub") or {}).get("pair") or (r.get("pub") or {}).get("pair") or {}
        sub["pairRttMs"].append(pair.get("rttMs"))

    def summarise(d):
        out = {}
        for k, xs in d.items():
            if k in ("freezesD", "freezeSecD", "framesDroppedD", "pli", "nack"):
                vals = [x for x in xs if x is not None]
                out[(k[:-1] if k.endswith("D") else k) + "Total"] = round(sum(vals), 2) if vals else None
            else:
                out[k] = med(xs)
        return {k: v for k, v in out.items() if v is not None}

    res = {}
    s, p = summarise(sub), summarise(pub)
    if s:
        res["sub"] = s
    if p:
        if qlr:
            p["qualityLimitation"] = dict(qlr)
        res["pub"] = p
    return res


def group_logs(logs):
    groups = OrderedCounter()
    first = {}
    for l in logs:
        # Strip ids, urls and numbers so repeats group together.
        key = re.sub(r"wss?://\S+", "<url>", l.get("msg", ""))
        key = re.sub(r"[0-9a-f]{8}-[0-9a-f-]{27,}", "<id>", key)
        key = re.sub(r"\d+", "#", key)[:160]
        k = (l.get("sdk"), l.get("level"), l.get("tag"), key)
        groups[k] += 1
        first.setdefault(k, round(l["ms"] / 1000, 1))
    return [
        {"sdk": k[0], "level": k[1], "tag": k[2], "msg": k[3], "count": n, "firstAt": first[k]}
        for k, n in groups.items()
    ]


class OrderedCounter(dict):
    def __missing__(self, key):
        return 0


def analyze(path):
    lines, bad = load(path)
    meta = next((l for l in lines if l["t"] == "meta"), {})
    session = next((l for l in lines if l["t"] == "session"), {})
    samples = [l for l in lines if l["t"] == "s"]
    rtc = [l for l in lines if l["t"] == "rtc"]
    marks = [l for l in lines if l["t"] == "mark"]
    statuses = [l for l in lines if l["t"] == "status"]
    life = [l for l in lines if l["t"] == "life"]
    logs = [l for l in lines if l["t"] == "log"]
    if not samples:
        sys.exit("No `s` sample lines - is this a benchmark recording?")

    cid, role = primary_call(samples)
    rows = []
    for s in samples:
        c = call_of(s, cid) if cid else None
        ui, dev, chat = s.get("ui", {}), s.get("dev", {}), s.get("chat", {})
        ev = (c or {}).get("events") or {}
        rows.append({
            "t": round(s["ms"] / 1000, 1),
            "load": c.get("load", c.get("participantCount")) if c else None,
            "held": c.get("participants") if c else None,
            "emits": c.get("stateEmits") if c else None,
            "events": sum(ev.values()) if c else None,
            "othersUs": c.get("othersUs") if c else None,
            "msgs": (chat.get("events") or {}).get("message.new", 0),
            "chatEvents": sum((chat.get("events") or {}).values()),
            "frames": ui.get("frames", 0),
            "jank": ui.get("jank", 0),
            "jank4x": ui.get("jank4x", 0),
            "buildP90": ui.get("buildP90"),
            "rasterP90": ui.get("rasterP90"),
            "totalMax": ui.get("totalMax"),
            "lagP95": (s.get("loop") or {}).get("lagP95Ms"),
            "lagMax": (s.get("loop") or {}).get("lagMaxMs"),
            "cpu": dev.get("cpuPct"),
            "rss": (s.get("mem") or {}).get("rssMb"),
            "pss": dev.get("pssMb"),
            "footprint": dev.get("footprintMb"),
            "threads": dev.get("threads"),
            "thermal": dev.get("thermalStatus"),
            "headroom": dev.get("thermalHeadroom"),
            "battery": dev.get("batteryPct"),
            "batteryTemp": dev.get("batteryTempC"),
            "charging": dev.get("charging"),
        })

    in_call = [r["load"] for r in rows if r["load"] is not None]
    baseline = min(in_call) if in_call else 0
    labels = label_seconds(rows, baseline)
    phase_runs = runs(labels)

    phases = []
    for label, a, b in phase_runs:
        seg = rows[a:b + 1]
        frames = sum(r["frames"] for r in seg)
        jank = sum(r["jank"] for r in seg)
        loads = [r["load"] for r in seg if r["load"] is not None]
        t0, t1 = seg[0]["t"], seg[-1]["t"]
        phases.append({
            "label": label,
            "from": t0, "to": t1, "seconds": b - a + 1,
            "load": [min(loads), max(loads)] if loads else None,
            "loadStart": loads[0] if loads else None,
            "loadEnd": loads[-1] if loads else None,
            "chatMsgs": sum(r["msgs"] for r in seg),
            "stateEmits": sum(r["emits"] or 0 for r in seg),
            "callEvents": sum(r["events"] or 0 for r in seg),
            "frames": frames, "jank": jank,
            "jankPct": round(jank / frames * 100, 1) if frames else None,
            "buildP90": med(r["buildP90"] for r in seg),
            "rasterP90": med(r["rasterP90"] for r in seg),
            "lagP95": med(r["lagP95"] for r in seg),
            "lagMax": mx(r["lagMax"] for r in seg),
            "cpu": mean(r["cpu"] for r in seg),
            "rss": mean(r["rss"] for r in seg),
            "rssMax": mx(r["rss"] for r in seg),
            "threads": med(r["threads"] for r in seg),
            "othersUsMax": mx(r["othersUs"] for r in seg),
            "rtc": rtc_digest(rtc, t0, t1 + 1),
        })

    # Seconds where the UI thread stalled badly.
    stalls = [
        {"t": r["t"], "lagMaxMs": r["lagMax"], "frameMaxMs": r["totalMax"], "load": r["load"]}
        for r in rows
        if (r["lagMax"] or 0) >= STALL_MS or (r["totalMax"] or 0) >= STALL_MS
    ]

    # What janky seconds coincide with, inside the call only.
    call_rows = [r for r in rows if r["load"] is not None and r["frames"]]

    def jank_rate(sel):
        f = sum(r["frames"] for r in sel)
        return round(sum(r["jank"] for r in sel) / f * 100, 1) if f else None

    emits_hi = statistics.median([r["emits"] or 0 for r in call_rows] or [0]) + 3
    attribution = {
        "withChatMsgs": {"seconds": sum(1 for r in call_rows if r["msgs"] > 0),
                         "jankPct": jank_rate([r for r in call_rows if r["msgs"] > 0])},
        "withoutChatMsgs": {"seconds": sum(1 for r in call_rows if r["msgs"] == 0),
                            "jankPct": jank_rate([r for r in call_rows if r["msgs"] == 0])},
        "highStateEmits": {"threshold": emits_hi,
                           "seconds": sum(1 for r in call_rows if (r["emits"] or 0) >= emits_hi),
                           "jankPct": jank_rate([r for r in call_rows if (r["emits"] or 0) >= emits_hi])},
        "lowStateEmits": {"seconds": sum(1 for r in call_rows if (r["emits"] or 0) < emits_hi),
                          "jankPct": jank_rate([r for r in call_rows if (r["emits"] or 0) < emits_hi])},
        "corrJankVsChatMsgs": pearson([r["jank"] for r in call_rows], [r["msgs"] for r in call_rows]),
        "corrJankVsStateEmits": pearson([r["jank"] for r in call_rows], [r["emits"] for r in call_rows]),
        "corrJankVsCallEvents": pearson([r["jank"] for r in call_rows], [r["events"] for r in call_rows]),
        "corrJankVsLoad": pearson([r["jank"] for r in call_rows], [r["load"] for r in call_rows]),
    }

    call_events = Counter()
    chat_events = Counter()
    for s in samples:
        c = call_of(s, cid) if cid else None
        if c:
            call_events.update(c.get("events") or {})
        chat_events.update((s.get("chat") or {}).get("events") or {})

    mark_list = [{"t": round(m["ms"] / 1000, 1), **{k: v for k, v in m.items() if k not in ("t", "ms")}} for m in marks]
    first_frame = next((m for m in mark_list if m["label"] in ("first_video_frame", "first_publish_frame")), None)
    attach = next((m for m in mark_list if m["label"].endswith("_attach")), None)
    # Before the recorder fix, first_video_frame came one report late; the
    # first rtc report showing fps is the better bound either way.
    first_rtc_video = None
    for r in rtc:
        vids = ((r.get("sub") or {}).get("inVideo") or []) + ((r.get("pub") or {}).get("outVideo") or [])
        if any((v.get("fps") or 0) > 0 for v in vids):
            first_rtc_video = round(r["ms"] / 1000, 1)
            break
    status_list = [{"t": round(s["ms"] / 1000, 1), "source": s.get("source"), "status": s.get("status")} for s in statuses]
    reconnects = [s for s in status_list if s["source"] == "call" and s["status"] in ("Reconnecting", "Migrating", "ReconnectionFailed", "Disconnected")]

    # Data-quality warnings the report should surface.
    warnings = []
    if meta.get("build") != "profile":
        warnings.append("Build mode is '%s', not profile - frame and CPU numbers are not representative." % meta.get("build"))
    if any(r["charging"] for r in rows):
        warnings.append("The device was charging during the run - battery drain and temperature are not usable, and throttling behaves differently.")
    peak = max(in_call) if in_call else 0
    if not any(m["label"] == "plateau" for m in mark_list) and peak > baseline + 5:
        warnings.append("No `plateau` mark: the load never held steady for 10 s, so there is no steady-state window at peak load.")
    if peak and peak < 1000:
        warnings.append("Peak load was %d participants - a smoke test, not a large-room run." % peak)
    if not cid:
        warnings.append("The device never joined a call during the recording.")
    if bad:
        warnings.append("%d line(s) could not be parsed (usually a truncated last line)." % bad)
    define_id = (meta.get("defines") or {}).get("STREAM_BENCH_CALL_ID")
    if cid and define_id and not cid.endswith(define_id):
        warnings.append("STREAM_BENCH_CALL_ID in the header ('%s') differs from the call actually joined ('%s')." % (define_id, cid))

    # Before/after memory around the call.
    call_idx = [i for i, r in enumerate(rows) if r["load"] is not None]
    memory = {}
    if call_idx:
        before = rows[max(0, call_idx[0] - 10):call_idx[0]]
        after = rows[call_idx[-1] + 1:call_idx[-1] + 11]
        memory = {
            "rssBefore": mean(r["rss"] for r in before),
            "rssInCallMax": mx(rows[i]["rss"] for i in call_idx),
            "rssAfter": mean(r["rss"] for r in after),
            "threadsBefore": med(r["threads"] for r in before),
            "threadsInCallMax": mx(rows[i]["threads"] for i in call_idx),
            "threadsAfter": med(r["threads"] for r in after),
            "pssSamples": [(r["t"], r["pss"]) for r in rows if r["pss"] is not None],
        }

    thermal = {
        "max": mx(r["thermal"] for r in rows),
        "headroomMax": mx(r["headroom"] for r in rows),
        "batteryStart": next((r["battery"] for r in rows if r["battery"] is not None), None),
        "batteryEnd": next((r["battery"] for r in reversed(rows) if r["battery"] is not None), None),
        "batteryTempMax": mx(r["batteryTemp"] for r in rows),
    }

    # Chart series: compact arrays the template draws.
    series = {
        "s": [[r["t"], r["load"], r["msgs"], r["buildP90"], r["jank"], r["lagP95"], r["cpu"],
               r["rss"], r["emits"], r["thermal"]] for r in rows],
        "sCols": ["t", "load", "msgs", "buildP90", "jank", "lagP95", "cpu", "rss", "emits", "thermal"],
        "r": [],
        "rCols": ["t", "inKbps", "inFps", "outKbps", "outFps", "encMs", "freezes"],
    }
    for r in rtc:
        iv = ((r.get("sub") or {}).get("inVideo") or [None])[0] or {}
        layers = (r.get("pub") or {}).get("outVideo") or []
        top = max(layers, key=lambda l: (l.get("w") or 0) * (l.get("h") or 0)) if layers else {}
        series["r"].append([
            round(r["ms"] / 1000, 1), iv.get("kbps"), iv.get("fps"),
            round(sum(l.get("kbps") or 0 for l in layers), 1) if layers else None,
            top.get("fps"), top.get("encMsPerFrame"), iv.get("freezesD"),
        ])

    return {
        "file": path,
        "meta": meta,
        "session": {k: v for k, v in session.items() if k not in ("t", "ms")},
        "durationS": round(samples[-1]["ms"] / 1000, 1),
        "call": {"id": cid, "role": role, "baselineLoad": baseline, "peakLoad": peak},
        "marks": mark_list,
        "statuses": status_list,
        "reconnects": reconnects,
        "lifecycle": [{"t": round(l["ms"] / 1000, 1), "state": l.get("state")} for l in life],
        "timeToFirstFrame": {
            "markSinceAttachMs": first_frame.get("sinceAttachMs") if first_frame else None,
            "firstRtcWithVideoS": first_rtc_video,
            "attachAtS": attach["t"] if attach else None,
            "note": "Stats arrive every ~2 s, so time to first frame is known to within one report.",
        },
        "phases": phases,
        "stalls": stalls,
        "jankAttribution": attribution,
        "callEventTotals": dict(call_events.most_common()),
        "chatEventTotals": dict(chat_events.most_common()),
        "memory": memory,
        "thermal": thermal,
        "logs": group_logs(logs),
        "warnings": warnings,
        "series": series,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("recording")
    ap.add_argument("-o", "--out")
    args = ap.parse_args()
    result = analyze(args.recording)
    text = json.dumps(result, indent=1, ensure_ascii=False)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
        # A short digest on stdout so the caller doesn't need to open the file.
        digest = {k: v for k, v in result.items() if k not in ("series",)}
        print(json.dumps(digest, indent=1, ensure_ascii=False))
    else:
        print(text)


if __name__ == "__main__":
    main()
