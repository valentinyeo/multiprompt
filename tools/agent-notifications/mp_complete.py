#!/usr/bin/env python3
import base64
from collections import OrderedDict, deque
import json
import os
from pathlib import Path
import re
import select
import shutil
import subprocess
import sys
import tempfile
import time

HOME = Path.home()
CACHE = HOME / ".cache/multiprompt/complete/claude.json"
TOKEN = re.compile(r"[A-Za-z0-9_. /()-]{1,120}\Z")
TRANSCRIPT_TOKEN = re.compile(r"[0-9]+\.[0-9]+\Z")
END = "@@MP_END@@"
CLAUDE_HIDDEN = {"__remote-workflow", "agents", "design-consent", "design-revoke", "extra-usage", "heapdump", "workflow-launch-exec"}
CLAUDE_VERSION = "2.1.283"
CODEX_VERSION = "0.155.1"
INTERACTIVE = {"model", "config", "resume", "permissions", "mcp", "theme", "help", "skills", "new", "branch", "plan",
               "ide", "keymap", "vim", "experimental", "approve", "memories", "import", "hooks", "rename",
               "archive", "delete", "fork", "goal", "agents", "side", "usage", "title", "statusline",
               "pets", "plugins", "personality", "subagents"}
SERVER = None
SERVER_LAST = 0
SERVER_BUFFER = b""


def clean(text, limit=200):
    value = re.sub(r"\s+", " ", str(text or "")).strip()[:limit]
    while len(value.encode("utf-8")) > limit and value:
        value = value[:-1]
    return value


def seeds(filename):
    try:
        lines = Path(__file__).with_name(filename).read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    result = []
    for line in lines:
        fields = re.split(r"\t+| {2,}", line, maxsplit=1)
        name = fields[0]
        desc = fields[1] if len(fields) > 1 else ""
        if name.startswith("/"):
            result.append((name[1:], "", clean(desc)))
    return result


def frontmatter(path):
    try:
        text = path.read_text(encoding="utf-8-sig")[:65536]
    except OSError:
        return {}, ""
    if not text.startswith("---\n"):
        return {}, text
    marker = text.find("\n---", 3)
    if marker < 0:
        return {}, text
    fields = {}
    key = None
    for line in text[4:marker].splitlines():
        m = re.match(r"^([\w-]+):\s*(.*)$", line)
        if m:
            key, value = m.groups()
            if value in (">", "|", ">-", "|-"):
                fields[key] = ""
            else:
                fields[key] = value.strip("\"'")
        elif key and line.startswith(("  ", "\t")):
            fields[key] += " " + line.strip()
    return fields, text[marker + 4:]


def off(overrides, name):
    value = overrides.get(name)
    return value is False or isinstance(value, str) and value.lower() in ("off", "disabled", "false")


def scan(root, prefix, kind, overrides, commands=False):
    if not root.is_dir():
        return []
    paths = root.rglob("*.md") if commands else root.glob("*/SKILL.md")
    result = []
    for path in sorted(paths):
        fields, body = frontmatter(path)
        if not commands and fields.get("user-invocable", "").lower() == "false":
            continue
        name = prefix + (path.relative_to(root).with_suffix("").as_posix().replace("/", ":") if commands else fields.get("name") or path.parent.name)
        if off(overrides, name) or off(overrides, name.split(":")[-1]):
            continue
        description = fields.get("description") or next((s.strip("# ") for s in body.splitlines() if s.strip()), "")
        result.append((kind, name, clean(fields.get("argument-hint")), clean(description)))
    return result


def project_and_plugins(cwd, settings):
    overrides = settings.get("skillOverrides") or {}
    rows = scan(HOME / ".claude/skills", "", "S", overrides)
    rows += scan(HOME / ".claude/commands", "", "C", overrides, True)
    root = cwd
    while True:
        rows += scan(root / ".claude/skills", "", "J", overrides)
        rows += scan(root / ".claude/commands", "", "J", overrides, True)
        if root == HOME or root.parent == root:
            break
        root = root.parent
    installed = read_json(HOME / ".claude/plugins/installed_plugins.json").get("plugins", {})
    for key, records in installed.items():
        if (settings.get("enabledPlugins") or {}).get(key) is not True:
            continue
        records = records if isinstance(records, list) else [records]
        for entry in reversed(records):
            path = Path(entry.get("installPath") or "/nonexistent")
            if entry.get("scope") == "local" and cwd != Path(entry.get("projectPath") or "/nonexistent") and Path(entry.get("projectPath") or "/nonexistent") not in cwd.parents:
                continue
            if not path.is_dir():
                break
            prefix = key.split("@", 1)[0] + ":"
            rows += scan(path / "skills", prefix, "P", overrides)
            rows += scan(path / "commands", prefix, "P", overrides, True)
            break
    return rows


def read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def cache_key():
    binary = shutil.which("claude") or ""
    try:
        binary = str(Path(binary).resolve())
    except OSError:
        pass
    key = [binary]
    for path in (HOME / ".claude/settings.json", HOME / ".claude/plugins/installed_plugins.json"):
        try:
            stat = path.stat()
            key.extend((stat.st_mtime_ns, stat.st_size))
        except OSError:
            key.append(None)
    for root in (HOME / ".claude/skills", HOME / ".claude/commands"):
        files = list(root.rglob("*.md")) if root.is_dir() else []
        key.extend((len(files), max((p.stat().st_mtime_ns for p in files), default=0)))
    return key


def probe_claude():
    env = {k: v for k, v in os.environ.items() if k not in ("TMUX", "TMUX_PANE", "MULTIPROMPT_TAB")}
    env["MP_COMPLETE_PROBE"] = "1"
    with tempfile.TemporaryDirectory() as cwd:
        output = subprocess.run(["claude", "-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose"],
            input=json.dumps({"type": "control_request", "request_id": "mp1", "request": {"subtype": "initialize"}}) + "\n",
            text=True, encoding="utf-8", capture_output=True, cwd=cwd, env=env, timeout=15).stdout
    for line in output.splitlines():
        try:
            event = json.loads(line)
            if event.get("type") == "control_response":
                return event["response"]["response"]["commands"]
        except (ValueError, KeyError, TypeError):
            continue
    raise ValueError("Claude did not return initialize commands")


def warn_version(agent, expected):
    try:
        output = subprocess.run([agent, "--version"], capture_output=True, text=True, encoding="utf-8",
                                timeout=2, check=True).stdout
        version = re.search(r"\d+\.\d+\.\d+", output)
        installed = version.group() if version else "unknown"
        if expected != installed:
            CACHE.parent.mkdir(parents=True, exist_ok=True)
            with (CACHE.parent / "versions.log").open("a", encoding="utf-8") as log:
                log.write(f"{agent}: seed {expected}, installed {installed}\n")
    except (OSError, subprocess.SubprocessError):
        pass


def warm():
    import fcntl

    CACHE.parent.mkdir(parents=True, exist_ok=True)
    with (CACHE.parent / "claude.lock").open("w", encoding="utf-8") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        key = cache_key()
        previous = read_json(CACHE)
        if previous.get("key") == key and time.time() - previous.get("at", 0) < 21600:
            return
        if previous.get("key") != key:
            warn_version("claude", CLAUDE_VERSION)
        try:
            commands = probe_claude()
        except (OSError, ValueError, subprocess.TimeoutExpired):
            return
        path = CACHE.with_suffix(".tmp")
        path.write_text(json.dumps({"key": key, "at": time.time(), "commands": commands}), encoding="utf-8")
        os.replace(path, CACHE)


def warm_async():
    subprocess.Popen([sys.executable, __file__, "--warm", "claude"], stdin=subprocess.DEVNULL,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def claude_rows(cwd):
    cached = read_json(CACHE)
    stale = cached.get("key") != cache_key() or time.time() - cached.get("at", 0) >= 21600
    if stale:
        warm_async()
    rows = [("B", c.get("name", "").lstrip("/"), clean(c.get("argumentHint")), clean(c.get("description")))
            for c in cached.get("commands", []) if c.get("name", "").lstrip("/") not in CLAUDE_HIDDEN]
    rows += [("B", name, "opens in terminal", desc) for name, _, desc in seeds("claude_interactive_builtins.tsv")]
    rows += project_and_plugins(cwd, read_json(HOME / ".claude/settings.json"))
    if stale and not cached:
        return "loading", []
    return ("stale" if stale else "ok"), rows


def codex_call(method, params):
    global SERVER, SERVER_LAST, SERVER_BUFFER
    if SERVER and (SERVER.poll() is not None or time.monotonic() - SERVER_LAST > 600):
        SERVER.terminate()
        SERVER = None
        SERVER_BUFFER = b""
    if SERVER is None:
        warn_version("codex", CODEX_VERSION)
        SERVER = subprocess.Popen(["codex", "app-server"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL, bufsize=0)
        SERVER.stdin.write((json.dumps({"id": 1, "method": "initialize", "params": {"clientInfo": {"name": "multiprompt", "version": "1"}}}) + "\n").encode())
        SERVER.stdin.flush()
        wait_codex(1)
        SERVER.stdin.write(b'{"method":"initialized"}\n')
        SERVER.stdin.flush()
    SERVER_LAST = time.monotonic()
    SERVER.stdin.write((json.dumps({"id": 2, "method": method, "params": params}) + "\n").encode())
    SERVER.stdin.flush()
    return wait_codex(2).get("result", {})


def wait_codex(request_id):
    global SERVER_BUFFER
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        while b"\n" in SERVER_BUFFER:
            line, SERVER_BUFFER = SERVER_BUFFER.split(b"\n", 1)
            item = json.loads(line)
            if item.get("id") == request_id:
                return item
        if not select.select([SERVER.stdout], [], [], deadline - time.monotonic())[0]:
            break
        chunk = os.read(SERVER.stdout.fileno(), 65536)
        if not chunk:
            break
        SERVER_BUFFER += chunk
    raise TimeoutError("codex app-server timed out")


def codex_rows(cwd, op):
    global SERVER
    rows = [("B", name, "opens in terminal" if name in INTERACTIVE else "", desc) for name, _, desc in seeds("codex_slash.txt")] if op == "slash" else []
    rows += scan(HOME / ".codex/prompts", "prompts:", "R", {}, True) if op == "slash" else []
    try:
        data = codex_call("skills/list", {"cwds": [str(cwd)]})
        for group in data.get("data", []):
            for skill in group.get("skills", []):
                if skill.get("enabled", True):
                    rows.append(("K", skill["name"], "", clean((skill.get("interface") or {}).get("shortDescription") or skill.get("description"))))
    except (OSError, ValueError, KeyError, TimeoutError, BrokenPipeError):
        if SERVER is not None:
            SERVER.terminate()
            SERVER = None
            global SERVER_BUFFER
            SERVER_BUFFER = b""
        if op == "skills":
            return "error", []
    return "ok", rows


def resolve_cwd(session, supplied):
    if session != "-":
        try:
            resolved = subprocess.run(["tmux", "display-message", "-p", "-t", session, "#{pane_current_path}"],
                                      capture_output=True, text=True, encoding="utf-8", timeout=0.5, check=True).stdout.strip()
            if Path(resolved).is_absolute() and Path(resolved).is_dir():
                return Path(resolved)
        except (OSError, subprocess.SubprocessError):
            pass
    return Path(supplied) if supplied != "-" and Path(supplied).is_absolute() and Path(supplied).is_dir() else HOME


SESSION_ID = re.compile(r"[A-Za-z0-9_-]{1,80}\Z")
TMUX_NAME = re.compile(r"[A-Za-z0-9_.:-]{1,80}\Z")
TRANSCRIPT_BYTES = 180000
TRANSCRIPT_TAIL = 8 * 1024 * 1024
_TRANSCRIPTS = OrderedDict()
TRANSCRIPT_CACHE_LIMIT = 64


def transcript_read_offset(cached, identity, size, mtime):
    if (cached and cached["identity"] == identity and size >= max(cached["size"], cached["offset"]) and
            (size > cached["size"] or mtime == cached["mtime"])):
        return cached["offset"]
    return None


def conversation_path(agent, sid, cwd):
    if not SESSION_ID.fullmatch(sid):
        return None
    root = HOME / (".claude/projects" if agent == "claude" else ".codex/sessions")
    candidates = []
    if agent == "claude":
        folder = re.sub(r"[^A-Za-z0-9]", "-", str(cwd))
        candidates.append(root / folder / (sid + ".jsonl"))
        candidates.extend(root.glob("*/" + sid + ".jsonl"))
    else:
        candidates.extend(root.glob("**/rollout-*-" + sid + ".jsonl"))
    for path in candidates:
        try:
            if path.is_file() and path.resolve().is_relative_to(root.resolve()):
                return path
        except OSError:
            pass
    return None


_COMMAND_NAME = re.compile(r"<command-name>\s*(.*?)\s*</command-name>", re.S)
_COMMAND_ARGS = re.compile(r"<command-args>(.*?)</command-args>", re.S)
_LOCAL_COMMAND = re.compile(r"<(local-command-stdout|local-command-stderr|local-command-caveat)>.*?</\1>", re.S)


def clean_command_markup(text):
    if "<command-name>" in text:
        name = _COMMAND_NAME.search(text)
        if name:
            args = _COMMAND_ARGS.search(text)
            command = name.group(1).strip()
            if command and not command.startswith("/"):
                command = "/" + command
            arguments = args.group(1).strip() if args else ""
            return (command + " " + arguments).strip()
    if "<local-command-" in text:
        text = _LOCAL_COMMAND.sub("", text)
    return text


def conversation_messages(path, agent):
    key = (str(path), agent)
    cached = _TRANSCRIPTS.get(key)
    with path.open("rb") as source:
        info = os.fstat(source.fileno())
        file_identity = (info.st_dev, info.st_ino)
        offset = transcript_read_offset(cached, file_identity, info.st_size, info.st_mtime_ns)
        if offset is not None:
            source.seek(max(0, offset - 64))
            if source.read(min(offset, 64)) != cached["boundary"]:
                offset = None
        if offset is None:
            messages = deque()
            total = 0
            start = max(0, info.st_size - TRANSCRIPT_TAIL)
            source.seek(start)
            if start:
                source.readline()
            offset = source.tell()
        else:
            messages = deque(cached["messages"])
            total = sum(len(row[2]) for row in messages)
            source.seek(offset)
        for raw in iter(source.readline, b""):
            if not raw.endswith(b"\n"):
                break
            offset = source.tell()
            try:
                event = json.loads(raw)
            except (ValueError, UnicodeError):
                continue
            if not isinstance(event, dict):
                continue
            if agent == "claude":
                attachment = event.get("attachment") if event.get("type") == "attachment" else None
                if isinstance(attachment, dict) and attachment.get("type") == "queued_command" and not event.get("isSidechain"):
                    message = {"role": "user", "content": attachment.get("prompt", "")}
                elif event.get("type") not in ("user", "assistant") or event.get("isMeta") or event.get("isSidechain"):
                    continue
                else:
                    message = event.get("message") or {}
            else:
                if event.get("type") != "response_item":
                    continue
                message = event.get("payload") or {}
                if not isinstance(message, dict) or message.get("type") != "message":
                    continue
            if not isinstance(message, dict):
                continue
            role = message.get("role")
            if role not in ("user", "assistant"):
                continue
            content = message.get("content", "")
            if isinstance(content, list):
                text = "\n".join(part.get("text", "") for part in content
                                 if isinstance(part, dict) and part.get("type") in ("text", "input_text", "output_text")
                                 and isinstance(part.get("text"), str))
            else:
                text = content if isinstance(content, str) else ""
            if not text.strip():
                continue
            if role == "user" and text.lstrip().startswith("<task-notification>"):
                continue
            if role == "user":
                text = clean_command_markup(text)
                if not text.strip():
                    continue
            encoded = text.encode("utf-8")
            if len(encoded) > TRANSCRIPT_BYTES:
                encoded = encoded[:TRANSCRIPT_BYTES].decode("utf-8", "ignore").encode("utf-8")
            timestamp = clean(event.get("timestamp"), 40)
            identity = message.get("id") or event.get("uuid")
            if identity and messages and messages[-1][3] == identity:
                old = messages.pop()
                total -= len(old[2])
                encoded = old[2] + b"\n" + encoded
                encoded = encoded[:TRANSCRIPT_BYTES].decode("utf-8", "ignore").encode("utf-8")
                timestamp = old[1]
            messages.append((role, timestamp, encoded, identity))
            total += len(encoded)
            while len(messages) > 96 or total > TRANSCRIPT_BYTES:
                total -= len(messages.popleft()[2])
        source.seek(max(0, offset - 64))
        boundary = source.read(min(offset, 64))
    _TRANSCRIPTS[key] = {"identity": file_identity, "size": info.st_size, "mtime": info.st_mtime_ns,
                         "offset": offset, "boundary": boundary, "messages": list(messages)}
    _TRANSCRIPTS.move_to_end(key)
    while len(_TRANSCRIPTS) > TRANSCRIPT_CACHE_LIMIT:
        _TRANSCRIPTS.popitem(last=False)
    return list(messages)


def process_basename(value):
    return str(value).replace("\\", "/").rsplit("/", 1)[-1]


def agent_pid_for_panes(pane_pids, table, agent):
    children = {}
    for pid, (ppid, _argv) in table.items():
        children.setdefault(ppid, []).append(pid)
    for pane in pane_pids:
        queue = [pane]
        seen = set()
        while queue:
            pid = queue.pop(0)
            if pid in seen:
                continue
            seen.add(pid)
            argv = table.get(pid, (0, []))[1]
            if any(process_basename(part) == agent for part in argv):
                return pid
            queue.extend(children.get(pid, []))
    return None


def claude_project_folder(cwd):
    return re.sub(r"[^A-Za-z0-9]", "-", str(cwd))


def newest_jsonl(paths):
    best = None
    best_mtime = -1.0
    for path in paths:
        try:
            if not path.is_file():
                continue
            mtime = path.stat().st_mtime
        except OSError:
            continue
        if mtime > best_mtime:
            best, best_mtime = path, mtime
    return best


def process_table(root=Path("/proc")):
    table = {}
    try:
        entries = list(root.iterdir())
    except OSError:
        return table
    for entry in entries:
        if not entry.name.isdigit():
            continue
        try:
            stat = (entry / "stat").read_text(encoding="utf-8", errors="replace")
            raw = (entry / "cmdline").read_bytes()
        except OSError:
            continue
        close = stat.rfind(")")
        tail = stat[close + 2:].split() if close >= 0 else []
        ppid = int(tail[1]) if len(tail) > 1 and tail[1].lstrip("-").isdigit() else 0
        argv = [part.decode("utf-8", "replace") for part in raw.split(b"\0") if part]
        table[int(entry.name)] = (ppid, argv)
    return table


def read_process_cwd(pid):
    try:
        return os.readlink(f"/proc/{pid}/cwd")
    except OSError:
        return None


def claude_session_metadata(pid):
    data = read_json(HOME / ".claude/sessions" / f"{pid}.json")
    sid = data.get("sessionId")
    cwd = data.get("cwd")
    return (sid if isinstance(sid, str) and SESSION_ID.fullmatch(sid) else None,
            cwd if isinstance(cwd, str) and cwd else None)


def claude_transcript_for_cwd(cwd):
    folder = HOME / ".claude/projects" / claude_project_folder(cwd)
    if not folder.is_dir():
        return None
    return newest_jsonl(folder.glob("*.jsonl"))


def codex_transcript_for_cwd(cwd):
    root = HOME / ".codex/sessions"
    if not root.is_dir():
        return None
    best = None
    best_mtime = -1.0
    try:
        candidates = list(root.rglob("rollout-*.jsonl"))
    except OSError:
        return None
    for path in candidates:
        try:
            with path.open("r", encoding="utf-8") as source:
                meta = json.loads(source.readline())
            payload = meta.get("payload") if isinstance(meta, dict) else None
            if not isinstance(payload, dict) or payload.get("cwd") != cwd:
                continue
            sid = payload.get("id") or payload.get("session_id")
            if not isinstance(sid, str) or not SESSION_ID.fullmatch(sid):
                continue
            mtime = path.stat().st_mtime
        except (OSError, ValueError):
            continue
        if mtime > best_mtime:
            best, best_mtime = (sid, path), mtime
    return best


def resolve_tmux_agent(agent, name):
    try:
        result = subprocess.run(["tmux", "list-panes", "-t", name, "-F", "#{pane_pid}"],
                                capture_output=True, text=True, encoding="utf-8", timeout=3, check=False)
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    pane_pids = [int(line) for line in result.stdout.split() if line.isdigit()]
    if not pane_pids:
        return None
    pid = agent_pid_for_panes(pane_pids, process_table(), agent)
    if pid is None:
        return None
    cwd = read_process_cwd(pid)
    if agent == "claude":
        sid, mapped_cwd = claude_session_metadata(pid)
        cwd = mapped_cwd or cwd
        if sid:
            path = conversation_path("claude", sid, cwd) if cwd else None
            if path is not None:
                return sid, path
        fallback = claude_transcript_for_cwd(cwd) if cwd else None
        if fallback is None:
            return None
        return fallback.stem, fallback
    if cwd is None:
        return None
    return codex_transcript_for_cwd(cwd)


def transcript_token(path):
    try:
        info = path.stat()
        return f"{info.st_size}.{info.st_mtime_ns}"
    except OSError:
        return "-"


def transcript_response(rid, agent, sid, cwd, token="-"):
    path = conversation_path(agent, sid, cwd)
    current = transcript_token(path) if path else "-"
    if path and token != "-" and token == current:
        return "\n".join((f"@mp\t{rid}\ttranscript\tsame\t{sid}\t0\t{current}", END, ""))
    messages = conversation_messages(path, agent) if path else []
    status = "ok" if messages else "missing"
    rows = ["\t".join(("M", role, timestamp or "-", base64.b64encode(text).decode("ascii")))
            for role, timestamp, text, _ in messages]
    return "\n".join((f"@mp\t{rid}\ttranscript\t{status}\t{sid}\t{len(rows)}\t{current}", *rows, END, ""))


def session_field_ok(op, value):
    if value == "-":
        return True
    if op == "transcript" and TRANSCRIPT_TOKEN.fullmatch(value):
        return True
    return bool(TOKEN.fullmatch(value))


def tmux_transcript_response(rid, agent, name):
    resolved = resolve_tmux_agent(agent, name)
    sid = resolved[0] if resolved else "-"
    path = resolved[1] if resolved else None
    messages = conversation_messages(path, agent) if path else []
    status = "ok" if messages else "missing"
    rows = ["\t".join(("M", role, timestamp or "-", base64.b64encode(text).decode("ascii")))
            for role, timestamp, text, _ in messages]
    token = transcript_token(path) if path else "-"
    return "\n".join((f"@mp\t{rid}\ttranscript\t{status}\t{sid}\t{len(rows)}\t{token}\t{agent}\t{name}", *rows, END, ""))


def request(line):
    fields = line.rstrip("\n").split("\t")
    rid = fields[0] if fields and fields[0].isdigit() else "0"
    op = fields[1] if len(fields) > 1 else "ping"
    header = ["@mp", rid, op, "error", "-", "0"]
    session_field = fields[3] if len(fields) > 3 else "-"
    session_ok = bool(TMUX_NAME.fullmatch(session_field)) if session_field.startswith("tmux:") else session_field_ok(op, session_field)
    if (len(fields) != 6 or len(line) > 4096 or not fields[0].isdigit() or
        fields[1] not in ("ping", "slash", "skills", "files", "transcript") or fields[2] not in ("claude", "codex") or
        not session_ok or
        fields[4] != "-" and not Path(fields[4]).is_absolute() or
        len(fields[5]) > 200 or any(ord(c) < 32 or ord(c) == 127 for c in fields[4] + fields[5])):
        return "\t".join(header) + "\n" + END + "\n"
    if op == "transcript":
        if session_field.startswith("tmux:"):
            return tmux_transcript_response(rid, fields[2], session_field[len("tmux:"):])
        return transcript_response(rid, fields[2], fields[5], Path(fields[4]), fields[3])
    cwd = resolve_cwd(fields[3], fields[4])
    if op == "ping":
        status, rows = "ok", []
    elif op == "files":
        status, rows = "error", []
    elif fields[2] == "claude":
        status, rows = claude_rows(cwd)
    else:
        status, rows = codex_rows(cwd, op)
    if op == "skills":
        rows = [r for r in rows if r[0] == "K"]
    seen = set()
    clean_rows = []
    for kind, name, hint, desc in rows:
        if name and name not in seen and len(clean_rows) < 512:
            seen.add(name)
            clean_rows.append("\t".join((kind, clean(name), clean(hint), clean(desc))))
    header[3:] = [status, clean(str(cwd), 700), str(len(clean_rows))]
    return "\n".join(("\t".join(header), *clean_rows, END, ""))


def main():
    if sys.argv[1:3] == ["--warm", "claude"]:
        warm()
    elif sys.argv[1:2] == ["--once"] and len(sys.argv) == 3:
        try:
            sys.stdout.write(request(base64.b64decode(sys.argv[2], validate=True).decode("utf-8")))
        except (ValueError, UnicodeError):
            sys.stdout.write("@mp\t0\tping\terror\t-\t0\n" + END + "\n")
    elif sys.argv[1:2] == ["--harvest"] and len(sys.argv) == 4:
        session, agent = sys.argv[2:]
        if not session.startswith("mp-ac-test-") or not TOKEN.fullmatch(session) or agent not in ("claude", "codex"):
            raise SystemExit("harvest requires a scratch session and claude or codex")
        subprocess.run(["bash", str(Path(__file__).with_name("harvest_tui.sh")), session, agent], check=True, timeout=45)
    elif sys.argv[1:2] == ["--serve"]:
        for line in sys.stdin:
            try:
                sys.stdout.write(request(line))
            except (OSError, ValueError, subprocess.SubprocessError):
                sys.stdout.write("@mp\t0\tping\terror\t-\t0\n" + END + "\n")
            sys.stdout.flush()
    else:
        raise SystemExit("usage: mp_complete.py --serve | --once base64 | --warm claude | --harvest scratch-session agent")


if __name__ == "__main__":
    main()
