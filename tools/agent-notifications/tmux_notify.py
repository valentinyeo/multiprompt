import fnmatch
import os
from pathlib import Path
import select
import socket
import stat
import subprocess
import threading
import time

AGENTS = {"claude", "codex", "pi", "hax", "grok"}
MARKER_MAX_AGE = 604800


def semantic_title(session, title):
    if not title.startswith("✳"):
        return ""
    title = title[1:].strip()
    if not title or title in ("Claude Code", session):
        return ""
    return "".join(c for c in title if " " <= c <= "~").strip()[:80]


def agent_from_argv(args):
    for arg in args:
        if arg.startswith("-"):
            continue
        for pattern, agent in (
            ("*/cursor-agent/versions/*/index.js", "cursor"),
            ("*/pi-coding-agent/*/cli.js", "pi"),
            ("*/@openai/codex/*/codex.js", "codex"),
        ):
            if fnmatch.fnmatchcase(arg, pattern):
                return agent
        if arg.rsplit("/", 1)[-1] not in ("node", "bun", "agent"):
            break
    return "none"


def detect_agent(command, pid, proc=Path("/proc")):
    if command in AGENTS:
        return command
    if not pid.isdecimal():
        return "none"
    pids = [pid]
    level = [pid]
    for _ in range(3):
        children = []
        for parent in level:
            try:
                children.extend((proc / parent / "task" / parent / "children").read_text().split())
            except OSError:
                pass
        children = [child for child in children if child.isdecimal() and child not in pids]
        pids.extend(children)
        level = children
    for child in pids:
        try:
            comm = (proc / child / "comm").read_text(errors="replace").strip()
            if comm in AGENTS:
                return comm
            args = (proc / child / "cmdline").read_bytes().decode("utf-8", errors="replace").rstrip("\0").split("\0")
            agent = agent_from_argv(args)
            if agent != "none":
                return agent
        except OSError:
            pass
    return "none"


def marker_mode(session, agent, directory=Path("/tmp"), now=None):
    path = directory / ("zigshell-semantic-" + session.replace("/", "_"))
    try:
        line = path.read_bytes().decode("utf-8").split("\n", 1)[0].strip(" \t")
        marker_agent, _, mode = line.replace("\t", " ").partition(" ")
        if marker_agent:
            if marker_agent != agent:
                return None
        elif agent not in ("claude", "codex"):
            return None
        if (time.time() if now is None else now) - path.stat().st_mtime >= MARKER_MAX_AGE:
            return None
        return mode.strip(" ")
    except (OSError, UnicodeError):
        return None


def notify(message):
    try:
        with socket.create_connection(("127.0.0.1", 19548), timeout=0.2) as conn:
            conn.sendall(message.encode("utf-8"))
    except OSError:
        pass


def pane_title(pane, socket_path):
    if not pane.startswith("%") or not pane[1:].isdecimal() or not socket_path.startswith("/"):
        return ""
    try:
        result = subprocess.run(
            ["tmux", "-S", socket_path, "display-message", "-p", "-t", pane, "#{pane_title}"],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=0.5, check=True,
        )
        return result.stdout.rstrip("\n")
    except (OSError, subprocess.SubprocessError):
        return ""


def dispatch(fields, send=notify):
    event, session, command, pid, pane, socket_path = fields
    if not session or len(session) > 120 or any(c in session for c in ":|,;\r\n\0"):
        return
    if event == "title":
        subject = semantic_title(session, pane_title(pane, socket_path))
        if subject:
            send(f"TITLE:{session}:{subject}")
        return
    if event not in ("activity", "silence", "session", "attach"):
        return
    agent = detect_agent(command, pid)
    if event in ("session", "attach"):
        if agent != "none":
            send(f"AGENT:{session}:{agent}")
        if event == "attach":
            subject = semantic_title(session, pane_title(pane, socket_path))
            if subject:
                send(f"TITLE:{session}:{subject}")
        return
    mode = marker_mode(session, agent)
    if event == "activity" and mode != "full":
        send(f"ACTIVE:{session}")
    elif event == "silence" and not (agent != "none" and mode is not None):
        send(f"DONE:{session}")


def serve_events(path, send=notify, stop=None):
    fd = os.open(path, os.O_RDWR | os.O_NONBLOCK | os.O_NOFOLLOW)
    pending = b""
    try:
        while stop is None or not stop.is_set():
            if not select.select([fd], [], [], None if stop is None else 0.1)[0]:
                continue
            pending += os.read(fd, 4096)
            while pending.count(b"\0") >= 6:
                *fields, pending = pending.split(b"\0", 6)
                dispatch([field.decode("utf-8", errors="replace") for field in fields], send)
            if len(pending) > 4096:
                pending = b""
    finally:
        os.close(fd)


def start_sender(directory):
    path = directory / "tmux-events"
    try:
        os.mkfifo(path, 0o600)
    except FileExistsError:
        pass
    info = path.lstat()
    if not stat.S_ISFIFO(info.st_mode) or info.st_uid != os.getuid():
        raise PermissionError("unsafe tmux notification FIFO")
    path.chmod(0o600)
    thread = threading.Thread(target=serve_events, args=(path,), daemon=True)
    thread.start()
    return thread
