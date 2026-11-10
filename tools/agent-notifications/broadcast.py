#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

DIM = re.compile(r"\x1b\[2m[^\x1b]*\x1b\[0m")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
BOX_RULE = "\u2500"
PROMPT = "\u276f"
HOST_CLI = Path.home() / ".multiprompt-runtime/reader.py"
HOST_SEND_TIMEOUT = 30
SEND_SETTLE_SECONDS = 0.5
DEFAULT_WAIT = 20.0


def run(cmd, input_text=None, timeout=15):
    try:
        result = subprocess.run(cmd, input=input_text, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return None
    return result.stdout if result.returncode == 0 else None


def tmux(*args):
    return run(["tmux", *args])


def hostname():
    return os.environ.get("HOSTNAME") or (run(["hostname"]) or "unknown").strip()


def panes():
    table = {}
    for line in (tmux("list-panes", "-a", "-F", "#{pane_id}\t#{pane_tty}\t#{session_name}") or "").splitlines():
        parts = line.split("\t")
        if len(parts) == 3:
            table[parts[1].replace("/dev/", "")] = dict(pane=parts[0], name=parts[2])
    return table


def tty_of(pid):
    if not pid:
        return ""
    return (run(["ps", "-o", "tty=", "-p", str(pid)]) or "").strip()


def draft(pane):
    raw = tmux("capture-pane", "-e", "-p", "-t", pane, "-S", "-60") or ""
    lines = [DIM.sub("", ANSI.sub("", line)) for line in raw.splitlines()]
    rules = [index for index, line in enumerate(lines) if line.startswith(BOX_RULE)]
    if len(rules) < 2:
        return ""
    box = lines[rules[-2] + 1:rules[-1]]
    text = " ".join(line.lstrip(PROMPT).strip() for line in box)
    return "".join(text.split())


def wait_for_clear(pane, seconds, step=0.5):
    started = time.monotonic()
    while True:
        if not draft(pane):
            return time.monotonic() - started
        if time.monotonic() - started >= seconds:
            return None
        time.sleep(step)


def type_into(pane, message):
    if run(["tmux", "send-keys", "-t", pane, "-l", "--", message]) is None:
        return False
    time.sleep(0.4)
    if run(["tmux", "send-keys", "-t", pane, "Enter"]) is None:
        return False
    time.sleep(SEND_SETTLE_SECONDS)
    wanted = "".join(message.split())
    if wanted and wanted == draft(pane):
        run(["tmux", "send-keys", "-t", pane, "Enter"])
    return True


def host_chats():
    out = run([sys.executable, str(HOST_CLI), "host", "list"], timeout=HOST_SEND_TIMEOUT)
    try:
        chats = json.loads(out or "{}").get("chats")
    except ValueError:
        return {}
    return {chat["sid"]: chat for chat in chats or [] if isinstance(chat, dict) and chat.get("sid")}


def host_processes():
    found = {}
    try:
        entries = list(Path("/proc").iterdir())
    except OSError:
        return found
    for entry in entries:
        if not entry.name.isdigit():
            continue
        try:
            argv = [part.decode("utf-8", "replace") for part in (entry / "cmdline").read_bytes().split(b"\0") if part]
        except OSError:
            continue
        if "--agent-host" not in argv:
            continue
        index = argv.index("--agent-host")
        if index + 2 < len(argv) and argv[index + 2]:
            found[argv[index + 2]] = argv[index + 1]
    return found


def host_send(provider, sid, message):
    out = run([sys.executable, str(HOST_CLI), "host", "send", provider, sid, "--text", message],
              timeout=HOST_SEND_TIMEOUT)
    try:
        return json.loads(out or "{}").get("status") or "error"
    except ValueError:
        return "error"


def claude_sessions():
    out = run(["claude", "agents", "--json"], timeout=HOST_SEND_TIMEOUT)
    try:
        sessions = json.loads(out or "[]")
    except ValueError:
        return []
    return [session for session in sessions or [] if isinstance(session, dict)]


def targets():
    table = panes()
    chats = host_chats()
    live = host_processes()
    rows = []
    seen = set()
    for session in claude_sessions():
        if session.get("kind") != "interactive":
            continue
        sid = session.get("sessionId") or ""
        name = session.get("name") or sid[:8] or "unnamed"
        hit = table.get(tty_of(session.get("pid")))
        if hit:
            rows.append(dict(name=name, sid=sid, channel="terminal", pane=hit["pane"]))
        elif sid in live:
            rows.append(dict(name=name, sid=sid, channel="chat", provider=live[sid]))
        else:
            rows.append(dict(name=name, sid=sid, channel="none"))
        if sid:
            seen.add(sid)
    for sid, provider in live.items():
        if sid in seen:
            continue
        chat = chats.get(sid) or {}
        rows.append(dict(name=chat.get("name") or sid[:8], sid=sid, channel="chat", provider=provider))
        seen.add(sid)
    return rows


def deliver(row, message, wait_seconds, dry):
    if row["channel"] == "none":
        return "no terminal and no chat"
    if row["channel"] == "chat":
        return "would send" if dry else host_send(row.get("provider") or "claude", row["sid"], message)
    if dry:
        return "would wait and send" if draft(row["pane"]) else "would send"
    waited = wait_for_clear(row["pane"], wait_seconds)
    if waited is None:
        return "left alone, still has unsent text"
    if not type_into(row["pane"], message):
        return "failed"
    return "sent" if waited < 1 else f"sent after waiting {int(waited)}s"


def parse(argv):
    flags = dict(dry=False, self_include=False, sender="", wait=DEFAULT_WAIT)
    words = []
    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg == "--dry-run":
            flags["dry"] = True
        elif arg == "--include-self":
            flags["self_include"] = True
        elif arg == "--from" and index + 1 < len(argv):
            index += 1
            flags["sender"] = argv[index]
        elif arg == "--wait" and index + 1 < len(argv):
            index += 1
            try:
                flags["wait"] = max(float(argv[index]), 0.0)
            except ValueError:
                return None, "usage: broadcast \"one line\" [--dry-run] [--include-self] [--from NAME] [--wait SECONDS]"
        elif arg.startswith("-"):
            return None, "usage: broadcast \"one line\" [--dry-run] [--include-self] [--from NAME] [--wait SECONDS]"
        else:
            words.append(arg)
        index += 1
    text = " ".join(" ".join(words).split())
    if not text:
        return None, "usage: broadcast \"one line\" [--dry-run] [--include-self] [--from NAME] [--wait SECONDS]"
    flags["text"] = text
    return flags, ""


def main(argv):
    flags, error = parse(argv)
    if flags is None:
        print(error)
        return 2
    rows = targets()
    self_pane = os.environ.get("TMUX_PANE", "")
    sender = flags["sender"]
    if not sender:
        for row in rows:
            if row["channel"] == "terminal" and row["pane"] == self_pane:
                sender = row["name"]
    sender = sender or "broadcast"
    message = f"[broadcast from {sender}] {flags['text']}"
    todo = []
    for row in rows:
        if row["channel"] == "terminal" and row["pane"] == self_pane and not flags["self_include"]:
            row["result"] = "self skipped"
            continue
        todo.append(row)
    with ThreadPoolExecutor(max_workers=4) as pool:
        for row, result in zip(todo, pool.map(lambda row: deliver(row, message, flags["wait"], flags["dry"]), todo)):
            row["result"] = result
    verb = "would reach" if flags["dry"] else "reached"
    delivered = sum(1 for row in todo if row["result"].startswith(("sent", "queued", "would")))
    print(f"broadcast from {sender} on {hostname()}: {verb} {delivered} of {len(todo)} live sessions")
    for row in rows:
        print(f"  {row['name']} [{row['channel']}] {row['result']}")
    missed = len(todo) - delivered
    print(f"{len(rows)} sessions listed once, {len(todo)} live, {missed} not delivered")
    return 0 if not missed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
