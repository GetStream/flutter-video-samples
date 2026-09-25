#!/usr/bin/env python3
"""Render a benchmark report page from analyze.py output plus written content.

    python3 render.py analysis.json content.json -o report.html

analysis.json - output of analyze.py (numbers, phases, chart series).
content.json  - the words: title, lede, tiles, findings, next steps. Schema in
                ../SKILL.md. String values may contain inline HTML (<b>, <code>).

Everything derived from the data - header metadata, the phase table, the
timeline rows, bands and marks - is generated here, so the written content
never has to restate numbers the page already shows.
"""

import argparse
import html
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, "..", "assets", "template.html")

PHASE_NAMES = {
    "pre-call": "Before the call",
    "post-call": "After the call",
    "baseline": "In call, no load",
    "loaded": "Load held",
    "ramp-up": "Load rising",
    "ramp-down": "Load falling",
}

MARK_CODES = [
    # (predicate on mark, letter, legend text)
    (lambda m: m["label"].endswith("_attach"), "A", "joined call"),
    (lambda m: m["label"] in ("first_video_frame", "first_publish_frame"), "F", "first frame"),
    (lambda m: m["label"] == "live", "G", "went live"),
    (lambda m: m["label"] == "ramp_start" and m.get("direction") == "up", "↑", "load starts rising"),
    (lambda m: m["label"] == "ramp_start" and m.get("direction") == "down", "↓", "load starts falling"),
    (lambda m: m["label"] == "plateau", "P", "load settled"),
    (lambda m: m["label"].endswith("_detach"), "D", "left call"),
]


def esc(v):
    return html.escape(str(v), quote=True)


def fmt_t(t, long_run):
    t = int(round(t))
    return "%d:%02d" % (t // 60, t % 60) if long_run else "%d" % t


def fmt_int(v):
    return "–" if v is None else "{:,}".format(int(round(v)))


def phase_name(p, i, overrides):
    if str(i) in overrides:
        return overrides[str(i)]
    base, _, chat = p["label"].partition("+")
    name = PHASE_NAMES.get(base, base)
    return name + (" + chat burst" if chat else "")


def build_meta(a):
    m, d = a["meta"], a["meta"].get("device") or {}
    parts = [
        ("device", ("%s %s" % (d.get("manufacturer", ""), d.get("model", ""))).strip()),
        (d.get("platform", a["meta"].get("os", "os")).replace("android", "Android").replace("ios", "iOS"),
         d.get("osVersion")),
        ("build", m.get("build")),
        ("display", "%g Hz" % (m.get("display") or {}).get("refreshHz", 0) if (m.get("display") or {}).get("refreshHz") else None),
        ("duration", "%g s" % a["durationS"] if a["durationS"] < 180 else "%d:%02d" % divmod(int(a["durationS"]), 60)),
        ("call", a["call"]["id"]),
        ("role", a["call"]["role"]),
        ("user", (a.get("session") or {}).get("userId")),
        ("peak load", fmt_int(a["call"]["peakLoad"]) + " participants" if a["call"]["peakLoad"] else None),
        ("recorded", (m.get("ts") or "")[:16].replace("T", " ") + " UTC" if m.get("ts") else None),
    ]
    return "".join('<span>%s <b>%s</b></span>' % (esc(k), esc(v)) for k, v in parts if v)


def build_tiles(tiles):
    out = []
    for t in tiles:
        out.append(
            '<div class="tile"><span class="pill %s">%s</span><span class="v">%s</span><span class="l">%s</span></div>'
            % (esc(t.get("status", "info")), t.get("pill", ""), t.get("value", ""), t.get("label", ""))
        )
    return "".join(out)


def video_cell(p, role):
    rtc = p.get("rtc") or {}
    if role == "host" and rtc.get("pub"):
        v = rtc["pub"]
        q = v.get("qualityLimitation") or {}
        limit = max(q, key=q.get) if q else None
        main = "%s kbps · %s fps" % (fmt_int(v.get("kbps")), fmt_int(v.get("fps")))
        sub = ("%sp" % fmt_int(v.get("h")) if v.get("h") else "") + ((" · limited by %s" % limit) if limit and limit != "none" else "")
        return main, sub, v
    if rtc.get("sub"):
        v = rtc["sub"]
        main = "%s kbps · %s fps" % (fmt_int(v.get("kbps")), fmt_int(v.get("fps")))
        bits = []
        if v.get("lossPct"):
            bits.append("%g%% loss" % v["lossPct"])
        if v.get("freezesTotal"):
            bits.append("%s freezes" % fmt_int(v["freezesTotal"]))
        return main, " · ".join(bits), v
    return "–", "", {}


def build_phase_table(a, overrides):
    phases = a["phases"]
    role = a["call"]["role"]
    long_run = a["durationS"] >= 180
    ref = next((p for p in phases if p["label"] == "baseline"), None)
    video_head = "Sent video" if role == "host" else "Received video"
    head = ["Phase", "Time (s)" if not long_run else "Time", "Participants", "Chat msgs", "Call updates",
            "Janky frames", "Build p90", "Loop lag p95", "CPU", "RSS", video_head]
    rows = []
    for i, p in enumerate(phases):
        def hot(cond):
            return ' class="num hot"' if (ref is not None and p is not ref and cond) else ' class="num"'

        load = p["load"]
        load_txt = "–" if not load else (fmt_int(load[0]) if load[0] == load[1] else
                                        "%s → %s" % (fmt_int(p["loadStart"]), fmt_int(p["loadEnd"])))
        jank_txt = "%s / %s (%s%%)" % (fmt_int(p["jank"]), fmt_int(p["frames"]),
                                       "%g" % p["jankPct"] if p["jankPct"] is not None else "–")
        vmain, vsub, _ = video_cell(p, role)
        rj = ref["jankPct"] if ref and ref["jankPct"] is not None else 0
        cells = [
            "<td>%s</td>" % esc(phase_name(p, i, overrides)),
            '<td class="num">%s–%s</td>' % (fmt_t(p["from"], long_run), fmt_t(p["to"], long_run)),
            '<td class="num">%s</td>' % load_txt,
            '<td class="num">%s</td>' % fmt_int(p["chatMsgs"]),
            '<td class="num">%s</td>' % fmt_int(p["stateEmits"]),
            "<td%s>%s</td>" % (hot((p["jankPct"] or 0) >= rj + 5), jank_txt),
            "<td%s>%s</td>" % (hot((p["buildP90"] or 0) > (a["meta"].get("frameBudgetMs") or 16.7)),
                               "–" if p["buildP90"] is None else "%.1f ms" % p["buildP90"]),
            "<td%s>%s</td>" % (hot((p["lagP95"] or 0) > 16), "–" if p["lagP95"] is None else "%.1f ms" % p["lagP95"]),
            "<td%s>%s</td>" % (hot(ref is not None and ref["cpu"] and (p["cpu"] or 0) > ref["cpu"] * 1.3),
                               "–" if p["cpu"] is None else "%d%%" % round(p["cpu"])),
            "<td%s>%s</td>" % (hot(ref is not None and ref["rss"] and (p["rss"] or 0) > ref["rss"] + 100),
                               "–" if p["rss"] is None else "%d MB" % round(p["rss"])),
            '<td class="num">%s%s</td>' % (esc(vmain), "<small>%s</small>" % esc(vsub) if vsub else ""),
        ]
        rows.append("<tr>%s</tr>" % "".join(cells))
    return "".join("<th>%s</th>" % esc(h) for h in head), "".join(rows)


def build_rows(a):
    role = a["call"]["role"]
    s_cols, r_cols = a["series"]["sCols"], a["series"]["rCols"]
    has = lambda src, key: any(
        row[(s_cols if src == "s" else r_cols).index(key)] not in (None, 0)
        for row in a["series"][src]
    )
    budget = a["meta"].get("frameBudgetMs") or 16.7
    rows = []
    if has("s", "load"):
        rows.append(dict(name="Participants in call", sub="server count", src="s", key="load", type="step", color="--s1", fmt="int"))
    if has("s", "msgs"):
        rows.append(dict(name="Chat messages / s", sub="message.new", src="s", key="msgs", type="bar", color="--s1", fmt="int"))
    if has("s", "emits"):
        rows.append(dict(name="Call state updates / s", sub="SDK state emissions", src="s", key="emits", type="bar", color="--s1", fmt="int"))
    rows += [
        dict(name="Frame build p90", sub="ms, UI thread", src="s", key="buildP90", type="line", color="--s3", budget=budget, fmt="ms"),
        dict(name="Janky frames / s", sub="build or raster > %.1f ms" % budget, src="s", key="jank", type="bar", color="--s3", fmt="int"),
        dict(name="Event-loop lag p95", sub="ms, capped at 60", src="s", key="lagP95", type="line", color="--s3", cap=60, fmt="ms"),
        dict(name="Process CPU", sub="% of one core", src="s", key="cpu", type="line", color="--s3", fmt="pct"),
        dict(name="Memory (RSS)", sub="MB", src="s", key="rss", type="line", color="--s3", fmt="mb"),
    ]
    if role == "host" and has("r", "outKbps"):
        rows += [
            dict(name="Sent video", sub="kbps, all layers", src="r", key="outKbps", type="line", color="--s3", fmt="kbps"),
            dict(name="Sent fps", sub="top layer", src="r", key="outFps", type="line", color="--s3", min=0, fmt="int"),
            dict(name="Encode time", sub="ms per frame", src="r", key="encMs", type="line", color="--s3", fmt="ms"),
        ]
    if has("r", "inKbps"):
        rows += [
            dict(name="Received video", sub="kbps, every ~2 s", src="r", key="inKbps", type="line", color="--s3", fmt="kbps"),
            dict(name="Received fps", sub="decoded", src="r", key="inFps", type="line", color="--s3", min=0, fmt="int"),
        ]
    if has("s", "thermal"):
        rows.append(dict(name="Thermal status", sub="0 = none", src="s", key="thermal", type="step", color="--s2", min=0, fmt="int"))
    return rows


def build_bands(a):
    bands, seen = [], set()
    for p in a["phases"]:
        base, _, chat = p["label"].partition("+")
        if base in ("ramp-up", "ramp-down", "loaded"):
            bands.append({"from": p["from"] - 0.5, "to": p["to"] + 0.5, "color": "--band"})
            seen.add("load")
        if chat:
            bands.append({"from": p["from"] - 0.5, "to": p["to"] + 0.5, "color": "--band2"})
            seen.add("chat")
    return bands, seen


def build_marks(a):
    marks, used = [], []
    for m in a["marks"]:
        for pred, code, text in MARK_CODES:
            if pred(m):
                marks.append([m["t"], code])
                if (code, text) not in used:
                    used.append((code, text))
                break
    return marks, used


def ticks(duration):
    for step in (5, 10, 15, 30, 60, 120, 300, 600, 900, 1800):
        if duration / step <= 8:
            break
    long_run = duration >= 180
    return [[t, fmt_t(t, long_run) + ("" if long_run else " s")] for t in range(0, int(duration) + 1, step)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("analysis")
    ap.add_argument("content")
    ap.add_argument("-o", "--out", required=True)
    args = ap.parse_args()
    with open(args.analysis, encoding="utf-8") as f:
        a = json.load(f)
    with open(args.content, encoding="utf-8") as f:
        c = json.load(f)
    with open(TEMPLATE, encoding="utf-8") as f:
        page = f.read()

    rows = build_rows(a)
    bands, seen = build_bands(a)
    marks, used = build_marks(a)
    head, body = build_phase_table(a, c.get("phaseNames") or {})

    legend = []
    if "load" in seen:
        legend.append('<span><i class="sw" style="background:var(--band);border:1px solid var(--s1)"></i>Load changing or held</span>')
    if "chat" in seen:
        legend.append('<span><i class="sw" style="background:var(--band2);border:1px solid var(--s2)"></i>Chat burst (≥ 2 msgs/s)</span>')
    legend.append('<span><i class="sw" style="background:var(--s1)"></i>Load</span>')
    legend.append('<span><i class="sw" style="background:var(--s3)"></i>App &amp; video</span>')

    hint = ""
    if used:
        hint = "Marks along the top row: " + " · ".join(
            '<span class="mono">%s</span> %s' % (esc(code), esc(text)) for code, text in used) + ". "
    hint += "The dashed line in the build-time row is the %.1f ms frame budget." % (a["meta"].get("frameBudgetMs") or 16.7)

    focus = c.get("focus")
    if focus is None:
        worst = max(a["phases"], key=lambda p: p["jankPct"] or 0, default=None)
        focus = (worst["from"] + worst["to"]) / 2 if worst else a["durationS"] / 2

    config = {
        "series": a["series"], "rows": rows, "bands": bands, "marks": marks,
        "xMax": a["durationS"] + 1, "ticks": ticks(a["durationS"]), "focus": focus,
    }

    findings = []
    for fnd in c.get("findings") or []:
        inner = "<h3>%s</h3>" % fnd.get("title", "")
        inner += "".join("<p>%s</p>" % p for p in fnd.get("paragraphs") or [])
        if fnd.get("bullets"):
            inner += '<ul class="plain">%s</ul>' % "".join("<li>%s</li>" % b for b in fnd["bullets"])
        findings.append('<div class="finding"><span class="tag">%s</span><div>%s</div></div>' % (fnd.get("tag", ""), inner))

    extra = "".join(
        "<section><h2>%s</h2>%s</section>" % (s.get("title", ""), s.get("html", ""))
        for s in c.get("extraSections") or []
    )

    default_intro = ("Every row shares the same time axis. Shaded bands show when the load was changing or held "
                     "and when chat messages were arriving. Hover or tap the chart to read every row at the same moment.")
    slots = {
        "TITLE": esc(c["title"]),
        "EYEBROW": c.get("eyebrow", ""),
        "H1": c.get("h1", c["title"]),
        "META": build_meta(a),
        "LEDE": c.get("lede", ""),
        "TILES": build_tiles(c.get("tiles") or []),
        "TIMELINE_INTRO": c.get("timelineIntro", default_intro),
        "LEGEND": "".join(legend),
        "HINT": hint,
        "PHASE_HEAD": head,
        "PHASE_ROWS": body,
        "FINDINGS": "".join(findings),
        "EXTRA_SECTIONS": extra,
        "NEXT_TITLE": c.get("nextTitle", "Before the next run"),
        "NEXT": "".join("<li>%s</li>" % n for n in c.get("next") or []),
    }
    for k, v in slots.items():
        page = page.replace("{{%s}}" % k, v)
    # `</` inside the JSON would end the script tag early.
    page = page.replace("/*CONFIG*/null", json.dumps(config, separators=(",", ":")).replace("</", "<\\/"))

    with open(args.out, "w", encoding="utf-8") as f:
        f.write(page)
    print(args.out)


if __name__ == "__main__":
    main()
