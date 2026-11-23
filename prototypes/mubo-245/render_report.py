#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
import re


def parse_ladder_answer(answer_path):
    if not answer_path or not answer_path.is_file():
        return {}
    try:
        payload = json.loads(answer_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    choices = payload.get("choices") or []
    content = ""
    if choices and isinstance(choices[0], dict):
        msg = choices[0].get("message") or {}
        raw = msg.get("content")
        if isinstance(raw, str):
            content = raw.strip()
        elif isinstance(raw, list):
            content = "".join(p.get("text", "") for p in raw if isinstance(p, dict)).strip()
    if not content:
        return {}
    m = re.search(r"\{.*\}", content, re.S)
    if not m:
        return {"raw": content}
    try:
        return json.loads(m.group(0))
    except ValueError:
        return {"raw": content}


def format_turn_strip(turns):
    out = []
    for t in turns:
        if t["turn"] == 11:
            out.append("|R|")
        if t["turn"] == 21:
            out.append("|U|")
        out.append("P" if t["passed"] else "F")
    return "".join(out)


def build_markdown(bundle):
    lines = [
        "# MUBO-245 Prototype Run Summary",
        "",
        "| Option | pinned-canary (T1-20) | pospeak (T1-20) | Unpin (T21-22) | Avg ms/turn | Total cost | Transcript markers |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for opt in ("a", "b", "c"):
        d = bundle["options"].get(opt) or {}
        cs = ((d.get("skills") or {}).get("pinned-canary") or {}).get("summary") or {}
        ps = ((d.get("skills") or {}).get("pospeak") or {}).get("summary") or {}
        avg_ms = round(((cs.get("avg_turn_ms") or 0) + (ps.get("avg_turn_ms") or 0)) / 2, 1)
        cost = round((cs.get("total_cost_usd") or 0) + (ps.get("total_cost_usd") or 0), 4)
        markers = (cs.get("transcript_marker_hits") or 0) + (ps.get("transcript_marker_hits") or 0)
        lines.append(
            f"| {opt.upper()} | {cs.get('pinned_pass',0)}/{cs.get('pinned_total',0)} "
            f"(pre {cs.get('pre_restart_pass',0)}/10, post {cs.get('post_restart_pass',0)}/10) "
            f"| {ps.get('pinned_pass',0)}/{ps.get('pinned_total',0)} "
            f"(pre {ps.get('pre_restart_pass',0)}/10, post {ps.get('post_restart_pass',0)}/10) "
            f"| {(cs.get('unpin_pass',0)+ps.get('unpin_pass',0))}/{(cs.get('unpin_total',0)+ps.get('unpin_total',0))} "
            f"| {avg_ms} | ${cost:.4f} | {markers} |"
        )
    lines.append("")
    lines.append("## Turn-by-Turn Pass/Fail Strips (`P`=pass, `F`=fail, `|R|`=restart, `|U|`=unpin)")
    lines.append("")
    for opt in ("a", "b", "c"):
        d = bundle["options"].get(opt) or {}
        for sk in ("pinned-canary", "pospeak"):
            turns = ((d.get("skills") or {}).get(sk) or {}).get("turns") or []
            lines.append(f"- Option {opt.upper()} `{sk}`: `{format_turn_strip(turns)}`")
    lines.append("")
    if bundle.get("ladder_judge"):
        lines.append("## Token Ladder Judge")
        lines.append("")
        lines.append("```json")
        lines.append(json.dumps(bundle["ladder_judge"], indent=2))
        lines.append("```")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", required=True)
    parser.add_argument("--judge-answer", default="")
    parser.add_argument("--ladder-lane", default="")
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()

    in_dir = Path(args.input_dir)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    options = {}
    for opt in ("a", "b", "c"):
        path = in_dir / f"option-{opt}" / "results.json"
        if path.is_file():
            options[opt] = json.loads(path.read_text(encoding="utf-8"))

    judge = parse_ladder_answer(Path(args.judge_answer)) if args.judge_answer else {}
    bundle = {
        "options": options,
        "ladder_judge": judge,
        "ladder_lane": args.ladder_lane,
    }
    (out_dir / "results_bundle.json").write_text(json.dumps(bundle, indent=2) + "\n", encoding="utf-8")
    (out_dir / "summary.md").write_text(build_markdown(bundle), encoding="utf-8")

    template = (Path(__file__).resolve().parent / "viewer.html").read_text(encoding="utf-8")
    safe_json = json.dumps(bundle).replace("</", "<\\/")
    rendered = template.replace("__MUBO245_BUNDLE__", safe_json)
    (out_dir / "viewer_rendered.html").write_text(rendered, encoding="utf-8")


if __name__ == "__main__":
    main()
