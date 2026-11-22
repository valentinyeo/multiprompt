#!/usr/bin/env python3
import os
from pathlib import Path
import re
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import eta_hook
import notify

DESC_MAX = 80
PLAIN = re.compile(r"\d+\Z")
PARTS = re.compile(r"(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?\Z")
CONTROL = re.compile(r"[\x00-\x1f\x7f]")
USAGE = (
    'usage: mp-eta 20m "Fix the login bug"\n'
    "       mp-eta +10m\n"
    "       mp-eta 15m --bg   (work continues after this turn ends)\n"
    "       mp-eta stats\n"
    "durations: 45s, 20m, 1h, 1h20m, or a plain number of minutes"
)


def parse_duration(text):
    text = (text or "").strip().lower()
    if PLAIN.fullmatch(text):
        minutes = int(text)
        return minutes * 60 if minutes > 0 else None
    match = PARTS.fullmatch(text)
    if not match or not any(match.groups()):
        return None
    hours, minutes, seconds = (int(group or 0) for group in match.groups())
    total = hours * 3600 + minutes * 60 + seconds
    return total if total > 0 else None


def format_duration(seconds):
    return notify.format_duration(seconds)


def sanitize_desc(text):
    return " ".join(CONTROL.sub(" ", text or "").split())[:DESC_MAX]


def agent_name(env):
    return notify.agent_name(env)


def wire(name, remaining, desc):
    return f"ETA:{name}:{max(0, int(remaining))}:{desc}"


def fail(message):
    sys.stderr.write("mp-eta: " + message + "\n")
    return 1


def usage():
    sys.stderr.write(USAGE + "\n")
    return 2


def resolved_target(env):
    return notify.target(os.environ if env is None else env)


def set_estimate(text, words, env=None, now=None):
    seconds = parse_duration(text)
    if seconds is None:
        return usage()
    resolved = resolved_target(env)
    if not resolved:
        return fail("cannot identify this tab, run mp-eta inside a multiprompt session")
    name, port, _ = resolved
    now = int(time.time() if now is None else now)
    desc = sanitize_desc(" ".join(words))
    agent = agent_name(os.environ if env is None else env)
    previous = notify.eta_entry(name)
    if previous is None:
        entry = {
            "agent": agent,
            "est_seconds": seconds,
            "first_est_seconds": seconds,
            "started_at": now,
            "updated_at": now,
            "revisions": 0,
            "desc": desc,
        }
        message = f"Estimate: {format_duration(seconds)} on {name}"
    else:
        started = notify.as_seconds(previous.get("started_at"))
        started = now if started is None else started
        first = notify.as_seconds(previous.get("first_est_seconds"))
        if first is None or first <= 0:
            first = notify.as_seconds(previous.get("est_seconds")) or seconds
        entry = {
            "agent": previous.get("agent") or agent,
            "est_seconds": max(0, now - started) + seconds,
            "first_est_seconds": first,
            "started_at": started,
            "updated_at": now,
            "revisions": (notify.as_seconds(previous.get("revisions")) or 0) + 1,
            "desc": desc or str(previous.get("desc") or ""),
            "background": bool(previous.get("background")),
        }
        message = (f"Estimate updated: {format_duration(seconds)} left "
                   f"(first estimate {format_duration(first)}) on {name}")
    try:
        notify.deliver([wire(name, seconds, entry["desc"])], port)
    except OSError as error:
        return fail(f"could not reach multiprompt: {error}")
    notify.set_eta_open(name, entry)
    try:
        eta_hook.clear_pending(name, now)
    except Exception:
        pass
    print(message)
    return 0


def extend(text, env=None, now=None):
    delta = parse_duration(text)
    if delta is None:
        return usage()
    resolved = resolved_target(env)
    if not resolved:
        return fail("cannot identify this tab, run mp-eta inside a multiprompt session")
    name, port, _ = resolved
    entry = notify.eta_entry(name)
    if entry is None:
        return fail('no open estimate for this tab, set one with mp-eta 20m "<what>"')
    now = int(time.time() if now is None else now)
    estimate = notify.as_seconds(entry.get("est_seconds")) or 0
    started = notify.as_seconds(entry.get("started_at")) or now
    first = notify.as_seconds(entry.get("first_est_seconds"))
    if first is None or first <= 0:
        first = estimate or delta
    previous = estimate
    estimate += delta
    remaining = max(0, estimate - max(0, now - started))
    entry["est_seconds"] = estimate
    entry["first_est_seconds"] = first
    entry["updated_at"] = now
    entry["revisions"] = (notify.as_seconds(entry.get("revisions")) or 0) + 1
    try:
        notify.deliver([wire(name, remaining, str(entry.get("desc") or ""))], port)
    except OSError as error:
        return fail(f"could not reach multiprompt: {error}")
    notify.set_eta_open(name, entry)
    try:
        eta_hook.clear_pending(name, now)
    except Exception:
        pass
    print(f"Estimate: {format_duration(estimate)} (was {format_duration(previous)}) on {name}")
    return 0


def stats():
    data = notify.eta_stats()
    if not data:
        print("no data yet")
        return 0
    for agent in sorted(data):
        median, count = data[agent]
        print(f"{agent}: tasks take {median:.1f}x the estimate (last {count})")
    return 0


def keep_open(env=None):
    resolved = resolved_target(env)
    entry = notify.eta_entry(resolved[0]) if resolved else None
    if not isinstance(entry, dict):
        return fail("no open estimate to keep; run mp-eta <time> \"<what>\" --bg")
    entry["background"] = True
    notify.set_eta_open(resolved[0], entry)
    print(f"Countdown stays up while background work runs on {resolved[0]}")
    return 0


def main(argv, env=None, now=None):
    background = "--bg" in argv
    argv = [arg for arg in argv if arg != "--bg"]
    if not argv:
        return keep_open(env) if background else usage()
    if argv[0] == "stats":
        return stats()
    if argv[0].startswith("+"):
        result = extend(argv[0][1:], env, now)
    else:
        result = set_estimate(argv[0], argv[1:], env, now)
    if result == 0 and background:
        result = keep_open(env)
    return result


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
