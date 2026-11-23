#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


SAMPLE_TURNS = (1, 5, 10, 11, 15, 20, 21)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    in_dir = Path(args.input_dir)
    sections = []
    for opt in ("a", "b", "c"):
        path = in_dir / f"option-{opt}" / "results.json"
        if not path.is_file():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        pospeak = (data.get("skills") or {}).get("pospeak") or {}
        turns = pospeak.get("turns") or []
        summary = pospeak.get("summary") or {}
        canary_summary = ((data.get("skills") or {}).get("pinned-canary") or {}).get("summary") or {}
        lines = [
            f"=== OPTION {opt.upper()} ===",
            f"pinned-canary: pinned_pass={canary_summary.get('pinned_pass')}/{canary_summary.get('pinned_total')} (expected PINNED), "
            f"unpin_pass={canary_summary.get('unpin_pass')}/{canary_summary.get('unpin_total')} (expected NO PINNED after unpin)",
            f"pospeak deterministic: pinned_pass={summary.get('pinned_pass')}/{summary.get('pinned_total')}, "
            f"unpin_pass={summary.get('unpin_pass')}/{summary.get('unpin_total')}",
        ]
        for turn in turns:
            if turn.get("turn") in SAMPLE_TURNS:
                lines.append(
                    f"Turn {turn['turn']} ({turn['phase']}, pinned={turn['pinned']}): "
                    f"{(turn.get('reply') or '').strip()[:500]}"
                )
        sections.append("\n".join(lines))

    prompt = (
        "You are grading three Multi Bot pinned-skill prototypes (Option A: UserPromptSubmit hook, "
        "Option B: send-path marker prepend, Option C: --append-system-prompt on resume) on how well "
        "each preserved the 'pospeak' skill across a 22-turn chat with a restart at turn 11 and unpin at turn 21.\n\n"
        "Pospeak rules while pinned (turns 1-20): bold one-line verdict first, plain everyday product words "
        "(no file paths, function names, backticks, or dev jargon), no em dashes, short (<95 words), ends with 'Next:'. "
        "Turn 21 is unpinned and SHOULD revert to plain technical prose without bold header or Next line.\n\n"
        "Return strict JSON only with keys: "
        '{"scores": {"a": {"pospeak_quality_10": int, "drift_notes": str}, '
        '"b": {"pospeak_quality_10": int, "drift_notes": str}, '
        '"c": {"pospeak_quality_10": int, "drift_notes": str}}, '
        '"best_adherence": "a|b|c|tie", "one_line_verdict": str}\n\n'
        + "\n\n".join(sections)
    )
    request = {
        "messages": [
            {"role": "system", "content": "Return compact valid JSON only. No markdown fences."},
            {"role": "user", "content": prompt},
        ],
        "max_tokens": 3500,
    }
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(request, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
