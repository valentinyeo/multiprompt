#!/usr/bin/env python3
import argparse
import glob
import json
import os
import sys
import time

DEFAULT_ROOT = os.path.expanduser("~/.local/state/multiprompt/agent-host")
CAUSE_WINDOW = 180

CAUSE_BY_EVENT = {
    "idle_stop": "idle_stop",
    "stop_requested": "requested stop",
    "disabled": "chat removed",
    "restart_now": "runtime/host update",
    "restart_waiting": "runtime/host update",
    "rotate": "runtime/host update",
    "rotate_failed": "runtime/host update",
    "rotate_unavailable": "runtime/host update",
    "switched_ai": "switch AI",
    "handover": "terminal",
    "terminal_move": "terminal",
    "terminal_move_failed": "terminal",
    "agent_closed": "AI exited",
    "host_error": "crash",
    "fresh_start_failed": "crash",
    "agent_reaped": "crash",
    "inflight_timeout": "crash",
}

EXIT_EVENTS = {"stop", "exit", "crash", "signal"}
IMMEDIATE_CAUSES = {"crash": "crash", "signal": "killed by signal"}
UNEXPLAINED = "unexplained"


def read_events(root):
    chats = {}
    for path in sorted(glob.glob(os.path.join(root, "*.events.log"))):
        sid = os.path.basename(path)[: -len(".events.log")]
        events = []
        try:
            with open(path, encoding="utf-8", errors="replace") as stream:
                for line in stream:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                    except ValueError:
                        continue
                    if isinstance(entry, dict) and type(entry.get("at")) in (int, float):
                        events.append(entry)
        except OSError:
            continue
        if events:
            events.sort(key=lambda entry: entry["at"])
            chats[sid] = events
    return chats


def chat_name(events, index):
    for entry in events[: index + 1][::-1]:
        if entry.get("event") == "start":
            detail = entry.get("detail")
            if isinstance(detail, dict) and isinstance(detail.get("tmux"), str):
                return detail["tmux"]
    for entry in events:
        if entry.get("event") == "start":
            detail = entry.get("detail")
            if isinstance(detail, dict) and isinstance(detail.get("tmux"), str):
                return detail["tmux"]
    return "-"


def cause_for(events, closed):
    at, event = closed
    if at is None or event is None:
        return UNEXPLAINED, "no exit record"
    if event in IMMEDIATE_CAUSES:
        return IMMEDIATE_CAUSES[event], event
    best = None
    for entry in events:
        name = entry.get("event")
        if name not in CAUSE_BY_EVENT:
            continue
        distance = abs(entry["at"] - at)
        if distance > CAUSE_WINDOW:
            continue
        if entry["at"] > at and name in EXIT_EVENTS:
            continue
        rank = (distance, 0 if entry["at"] <= at else 1)
        if best is None or rank < best[0]:
            best = (rank, name, entry.get("detail"))
    if best is not None:
        return CAUSE_BY_EVENT[best[1]], best[1]
    return UNEXPLAINED, event


def exits(chats, since, until):
    rows = []
    for sid, events in chats.items():
        run = None
        for index, entry in enumerate(events):
            name = entry.get("event")
            if name == "start":
                if run is not None:
                    rows.append(run)
                run = dict(started=entry["at"], sid=sid, chat=chat_name(events, index),
                           events=events, closed=None, exit_event=None)
            elif run is not None and name in EXIT_EVENTS:
                if run["closed"] is None:
                    run["closed"] = entry["at"]
                    run["exit_event"] = name
                    detail = entry.get("detail")
                    if isinstance(detail, dict) and isinstance(detail.get("cause"), str):
                        run["recorded"] = detail["cause"]
        if run is not None and run["closed"] is not None:
            rows.append(run)
    report = []
    for run in rows:
        at = run["closed"] if run["closed"] is not None else run["started"]
        if not since <= at <= until:
            continue
        recorded = run.get("recorded")
        if recorded is not None:
            cause = CAUSE_BY_EVENT.get(recorded, recorded)
            source = recorded
        else:
            cause, source = cause_for(run["events"], (run["closed"], run["exit_event"]))
        report.append(dict(at=at, sid=run["sid"], chat=run["chat"], cause=cause, source=source))
    report.sort(key=lambda row: row["at"])
    return report


def counts(rows):
    totals = {}
    for row in rows:
        totals[row["cause"]] = totals.get(row["cause"], 0) + 1
    return sorted(totals.items(), key=lambda item: (-item[1], item[0]))


def stamp(at):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(at))


def parse_stamp(value):
    import calendar
    return calendar.timegm(time.strptime(value, "%Y-%m-%dT%H:%M:%SZ"))


def main(argv=None):
    parser = argparse.ArgumentParser(description="Report every hosted chat exit with its cause.")
    parser.add_argument("--root", default=DEFAULT_ROOT, help="agent-host state directory")
    parser.add_argument("--hours", type=float, default=48.0, help="window length ending now")
    parser.add_argument("--since", help="window start, YYYY-MM-DDTHH:MM:SSZ")
    parser.add_argument("--until", help="window end, YYYY-MM-DDTHH:MM:SSZ")
    parser.add_argument("--json", action="store_true", help="machine readable output")
    parser.add_argument("--no-table", action="store_true", help="counts only")
    parser.add_argument("--now", type=float, default=time.time(), help="window end as epoch seconds")
    options = parser.parse_args(argv)

    until = parse_stamp(options.until) if options.until else options.now
    since = parse_stamp(options.since) if options.since else until - max(0.0, options.hours) * 3600
    rows = exits(read_events(options.root), since, until)
    totals = counts(rows)
    unexplained = [row for row in rows if row["cause"] == UNEXPLAINED]

    if options.json:
        print(json.dumps(dict(since=stamp(since), until=stamp(until), exits=len(rows),
                              counts=dict(totals), rows=[dict(row, at=stamp(row["at"])) for row in rows],
                              unexplained=len(unexplained)), indent=2, sort_keys=True))
        return 1 if unexplained else 0

    hours = (until - since) / 3600
    print(f"Chat exits {stamp(since)} to {stamp(until)} ({hours:.1f}h): {len(rows)} exits")
    if not options.no_table:
        print(f"{'UTC':21} {'CHAT':22} {'SID':9} CAUSE")
        for row in rows:
            print(f"{stamp(row['at']):21} {row['chat'][:22]:22} {row['sid'][:8]:9} {row['cause']}")
        print()
    print("Counts per cause:")
    for cause, total in totals:
        print(f"{total:5}  {cause}")
    print()
    print(f"Unexplained exits: {len(unexplained)}")
    return 1 if unexplained else 0


if __name__ == "__main__":
    sys.exit(main())
