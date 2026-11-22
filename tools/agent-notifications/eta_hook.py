#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import notify

PROMPT_CONTEXT = (
    'Before you start, estimate how long this request will take you and run: '
    'mp-eta <time> "<what you are doing>". When what you learn changes the '
    'picture, run mp-eta <time left> again. If you end your turn while '
    'background work continues, add --bg.'
)
DENY_REASON = 'Give a time estimate first: run mp-eta <time> "<what>"'
STALE_SECONDS = 6 * 60 * 60
MAX_ENTRIES = 200
OVERDUE_SILENCE = 5 * 60
UPDATE_SILENCE = 10 * 60
UPDATE_FLOOR = 10 * 60
UPDATE_SHARE = 0.4
MP_ETA = re.compile(r"(?:^|[^\w-])mp[-_]eta")


def state_path():
    return notify.state_dir() / "eta-hook.json"


def read_state():
    data = notify.read_json(state_path(), {})
    return data if isinstance(data, dict) else {}


def write_state(data):
    notify.write_json(state_path(), data)


def prune(data, now):
    kept = {}
    for key, entry in data.items():
        if not isinstance(entry, dict):
            continue
        try:
            stamp = float(entry.get("stamp") or 0)
        except (TypeError, ValueError):
            continue
        if now - stamp > STALE_SECONDS:
            continue
        kept[key] = entry
    if len(kept) > MAX_ENTRIES:
        ordered = sorted(kept.items(), key=lambda pair: float(pair[1].get("stamp") or 0))
        kept = dict(ordered[-MAX_ENTRIES:])
    return kept


def session_key(payload):
    return str(payload.get("session_id") or "").strip()


def tab_name(env):
    resolved = notify.target(env)
    return resolved[0] if resolved else ""


def watched(env):
    if not env.get("TMUX"):
        return True
    pane = env.get("TMUX_PANE", "")
    if not re.fullmatch(r"%[0-9]+", pane):
        return False
    try:
        result = subprocess.run(
            ["tmux", "display-message", "-p", "-t", pane, "#{session_attached}"],
            capture_output=True, text=True, encoding="utf-8", timeout=0.5, check=True,
        )
        return int(result.stdout.strip() or "0") > 0
    except (OSError, ValueError, subprocess.SubprocessError):
        return False


def prompt(payload, env, now):
    name = tab_name(env)
    if not name or not watched(env):
        return None
    data = prune(read_state(), now)
    entry = notify.eta_entry(name)
    if isinstance(entry, dict) and entry.get("carried"):
        notify.drop_eta(name)
        entry = None
    already_estimated = entry is not None
    data[session_key(payload) or name] = {
        "name": name,
        "pending": not already_estimated,
        "denied": False,
        "stamp": now,
    }
    write_state(data)
    context = PROMPT_CONTEXT
    stats = notify.eta_stats()
    agent = notify.agent_name(env)
    if agent not in stats and len(stats) == 1:
        agent = next(iter(stats))
    if agent in stats:
        context += f" Your recent tasks took {stats[agent][0]:.1f}x your estimate; adjust for that."
    return {"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": context}}


def from_subagent(payload):
    return any(payload.get(k) for k in ("agent_id", "subagent_id", "subagentType", "subagent_type"))


def pretool(payload, env, now):
    if from_subagent(payload):
        return None
    data = prune(read_state(), now)
    key = session_key(payload)
    if not key:
        key = tab_name(env)
    entry = data.get(key)
    if not isinstance(entry, dict) or not entry.get("pending") or entry.get("denied"):
        return None
    tool = str(payload.get("tool_name") or "")
    tool_input = payload.get("tool_input")
    command = str(tool_input.get("command") or "") if isinstance(tool_input, dict) else ""
    if tool == "Bash" and MP_ETA.search(command):
        return None
    entry["denied"] = True
    entry["stamp"] = now
    write_state(data)
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": DENY_REASON,
        }
    }


def clear_pending(name, now=None):
    now = time.time() if now is None else now
    data = prune(read_state(), now)
    changed = False
    for entry in data.values():
        if entry.get("name") == name and entry.get("pending"):
            entry["pending"] = False
            changed = True
    if changed:
        write_state(data)


def last_nudge(name):
    entry = read_state().get(name)
    return notify.as_seconds(entry.get("nudge")) if isinstance(entry, dict) else None


def nudge_text(entry, now, last_nudge_at):
    if not isinstance(entry, dict):
        return None
    started = notify.as_seconds(entry.get("started_at"))
    estimate = notify.as_seconds(entry.get("est_seconds"))
    if started is None or estimate is None or estimate <= 0:
        return None
    seen = notify.as_seconds(last_nudge_at)
    deadline = started + estimate
    if now > deadline:
        if seen is not None and now - seen < OVERDUE_SILENCE:
            return None
        overdue = max(1, (now - deadline) // 60)
        return (f"Your estimate for this request ran out {overdue}m ago. "
                "If you are still working, run: mp-eta <time left>.")
    updated = notify.as_seconds(entry.get("updated_at"))
    updated = started if updated is None else updated
    quiet = now - updated
    if quiet < max(UPDATE_FLOOR, int(estimate * UPDATE_SHARE)):
        return None
    if seen is not None and now - seen < UPDATE_SILENCE:
        return None
    return (f"{quiet // 60}m since your last estimate "
            f"({notify.format_duration(estimate)} total). If what you found changes "
            "the picture, run: mp-eta <time left>. Otherwise carry on.")


def posttool(payload, env, now):
    if from_subagent(payload):
        return None
    resolved = notify.target(env)
    if not resolved or not watched(env):
        return None
    name, port, _ = resolved
    sid = session_key(payload)
    if notify.lifecycle_state(name, sid) == "done":
        try:
            notify.deliver([f"ACTIVE:{name}"], port, attempts=1)
            notify.set_lifecycle(name, sid, "active")
            if (notify.eta_entry(name) or {}).get("carried"):
                notify.drop_eta(name)
        except (OSError, ValueError):
            pass
    entry = notify.eta_entry(name)
    if not isinstance(entry, dict):
        return None
    text = nudge_text(entry, now, last_nudge(name))
    if not text:
        return None
    data = prune(read_state(), now)
    data[name] = {"name": name, "nudge": now, "stamp": now}
    write_state(data)
    return {"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": text}}


def handle(mode, payload, env, now=None):
    if not isinstance(payload, dict):
        return None
    now = time.time() if now is None else now
    if mode == "prompt":
        return prompt(payload, env, now)
    if mode == "pretool":
        return pretool(payload, env, now)
    if mode == "posttool":
        return posttool(payload, env, now)
    return None


def main(argv):
    mode = argv[0] if argv else ""
    if mode == "stop":
        return 0
    if mode not in ("prompt", "pretool", "posttool"):
        return 0
    try:
        raw = sys.stdin.read(1024 * 1024)
        payload = json.loads(raw) if raw.strip() else {}
        result = handle(mode, payload, os.environ)
        if result:
            sys.stdout.write(json.dumps(result) + "\n")
    except Exception:
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
