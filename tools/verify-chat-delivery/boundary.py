import ctypes
from ctypes import wintypes
import datetime
import json
import importlib.util
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time
import uuid

ROOT = Path(os.environ["MP_VERIFY_STATE"])
MODE = sys.argv[1]
ARGS = sys.argv[2:]


def state():
    value = json.loads((ROOT / "state.json").read_text(encoding="utf-8-sig"))
    if value.get("binding"):
        value["bindingStatus"] = not (ROOT / "binding-status-hidden").exists()
    return value


def record(file, **values):
    row = dict(ms=time.time_ns() // 1000000, pid=os.getpid(), case=state()["name"], **values)
    data = (json.dumps(row, ensure_ascii=True) + "\n").encode("utf-8")
    with (ROOT / file).open("ab", buffering=0) as output:
        output.write(data)


BOX_WIDTH = 30


def box_rows(buffer):
    rows = []
    for line in buffer.split("\n"):
        rows.extend([line[i:i + BOX_WIDTH] for i in range(0, len(line), BOX_WIDTH)] or [""])
    return rows


def stateful(value):
    return "leftover" in value or value["mode"] == "idle"


def box_buffer():
    file = ROOT / "box.json"
    if file.exists():
        return json.loads(file.read_text(encoding="utf-8"))["buffer"]
    value = state()
    return value["leftover"] + "\n" if "leftover" in value else ""


def ctrl_u(buffer):
    if not buffer or buffer.endswith("\n"):
        return buffer[:-1]
    start = buffer.rfind("\n") + 1
    rel = len(buffer) - start
    row = rel // BOX_WIDTH - (1 if rel % BOX_WIDTH == 0 else 0)
    return buffer[:start + row * BOX_WIDTH]


def ctrl_k(buffer, cursor):
    if cursor >= len(buffer):
        return buffer
    if buffer[cursor] == "\n":
        return buffer[:cursor] + buffer[cursor + 1:]
    start = buffer.rfind("\n", 0, cursor) + 1
    stop = start + ((cursor - start) // BOX_WIDTH + 1) * BOX_WIDTH
    newline = buffer.find("\n", cursor)
    if newline != -1:
        stop = min(stop, newline)
    return buffer[:cursor] + buffer[stop:]


def screen(value, buffer=None):
    if value.get("binding"):
        status = "[workspace] 0:bash*" if value.get("bindingStatus") else "Status temporarily hidden"
        return "Named terminal: workspace\nExisting conversation sentinel\n\n" + status + "\n"
    head = "Claude Code\n\n" + ("Working... (esc to interrupt)\n" if value["mode"] == "busy" else "Ready\n") + "\n"
    if stateful(value):
        if buffer is None:
            buffer = value["leftover"] + "\n" if "leftover" in value else ""
        rows = box_rows(buffer) if buffer else [value["suggestion"] if value["mode"] == "idle" else ""]
        return head + "\u276f " + rows[0] + "\n" + "".join("  " + row + "\n" for row in rows[1:]) + "\u2500" * 50 + "\n"
    return head + "\u276f " + (value["suggestion"] if value["mode"] == "idle" else "") + "\n" + "\u2500" * 50 + "\n"


SGR_DIM = "\x1b[2m"
SGR_RESET = "\x1b[0m"
FAKE_LOCK = ROOT / "claude.lock"


def fake_locked(action):
    deadline = time.time() + 10
    while True:
        try:
            handle = os.open(FAKE_LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            break
        except (FileExistsError, PermissionError):
            try:
                if time.time() - FAKE_LOCK.stat().st_mtime > 5:
                    FAKE_LOCK.unlink()
            except OSError:
                pass
            if time.time() > deadline:
                raise TimeoutError("fake Claude lock")
            time.sleep(0.01)
    try:
        return action()
    finally:
        os.close(handle)
        for _ in range(200):
            try:
                FAKE_LOCK.unlink()
                break
            except FileNotFoundError:
                break
            except PermissionError:
                time.sleep(0.01)


def fake_read():
    return json.loads((ROOT / "claude.json").read_text(encoding="utf-8"))


def fake_write(claude):
    (ROOT / "claude.json").write_text(json.dumps(claude, ensure_ascii=True), encoding="utf-8")


def fake_suggestion_shown(claude):
    return claude["mode"] == "idle" and not claude["box"]


def fake_screen(claude, escapes):
    lines = ["Claude Code", "", "Working... (esc to interrupt)" if claude["mode"] == "busy" else "Ready", ""]
    for question, answer in claude.get("turns", []):
        lines.extend(["❯ " + question, "● " + answer, ""])
    lines += ["  Queued: " + " ".join(text.split()) for text in claude["queue"]]
    rows = claude["box"].split("\n") if claude["box"] else [""]
    first = rows[0]
    if fake_suggestion_shown(claude):
        first = SGR_DIM + claude["suggestion"] + SGR_RESET if escapes else claude["suggestion"]
    lines += ["❯ " + first, *("  " + row for row in rows[1:]), "─" * 50]
    return "\n".join(lines) + "\n"


def fake_stamp():
    return datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def fake_event(kind, **fields):
    value = state()
    row = dict(type=kind, timestamp=fake_stamp(), sessionId=value["sid"])
    if kind != "queue-operation":
        row.update(uuid=str(uuid.uuid4()), isSidechain=False)
    row.update(fields)
    data = (json.dumps(row, ensure_ascii=True) + "\n").encode("utf-8")
    with open(value["transcript"], "ab", buffering=0) as output:
        output.write(data)


def fake_queue_event(operation, content=None, **extra):
    fields = dict(operation=operation, **extra)
    if content is not None:
        fields["content"] = content
    fake_event("queue-operation", **fields)


def fake_submit(claude, text):
    if claude["mode"] == "busy":
        claude["queue"].append(text)
        fake_queue_event("enqueue", text)
    else:
        fake_event("user", message=dict(role="user", content=text))


def fake_take(claude):
    first = True
    while claude["queue"]:
        text = claude["queue"].pop(0)
        if first:
            fake_queue_event("remove", text, reason="absorbed_mid_turn")
        else:
            fake_queue_event("dequeue")
        first = False
        fake_event("attachment", attachment=dict(type="queued_command", prompt=text, commandMode="prompt"))
    fake_event("assistant", message=dict(role="assistant", id="msg_" + uuid.uuid4().hex[:12], model="claude-opus-5-5", content=[dict(type="text", text="Done with the queued messages.")]))
    claude["mode"] = "idle"


def fake_key(claude, key):
    if key == "Enter":
        if claude["box"]:
            text, claude["box"] = claude["box"], ""
            fake_submit(claude, text)
    elif key == "C-u":
        claude["box"] = ""
    elif key == "Up":
        if claude["queue"]:
            queued = list(claude["queue"])
            fake_queue_event("popAll", "\n".join(queued))
            claude["box"] = "\n".join(queued + ([claude["box"]] if claude["box"] else []))
            claude["queue"] = []
    elif key == "BSpace":
        claude["box"] = claude["box"][:-1]
    elif key == "Space":
        claude["box"] += " "
    elif key not in ("C-x", "C-s"):
        return False
    return True


def fake_run(origin, op, argv, change):
    def run():
        claude = fake_read()
        outcome = change(claude)
        fake_write(claude)
        record("frames.jsonl", origin=origin, op=op, argv=argv, mode=claude["mode"], queue=claude["queue"], box=claude["box"],
               suggestionShown=fake_suggestion_shown(claude), screen=fake_screen(claude, False), escaped=fake_screen(claude, True))
        return outcome
    return fake_locked(run)


def fake_send(argv):
    literal = False
    keys = []
    index = 1
    while index < len(argv):
        argument = argv[index]
        if argument == "-t":
            index += 2
        elif argument == "-l":
            literal = True
            index += 1
        elif argument == "--":
            keys = argv[index + 1:]
            break
        else:
            keys.append(argument)
            index += 1

    def change(claude):
        supported = True
        for key in keys:
            if literal:
                claude["box"] += key
            elif not fake_key(claude, key):
                supported = False
        return supported
    return fake_run("app", "send-keys", argv, change)


def fake_init():
    value = state()
    pane = str(value["panePid"])
    for target in (value["transcript"], value["meta"]):
        Path(target).parent.mkdir(parents=True, exist_ok=True)
    Path(value["transcript"]).write_bytes(b"")
    Path(value["meta"]).write_text(json.dumps(dict(sessionId=value["sid"], cwd=value["cwd"], pid=value["panePid"])), encoding="utf-8")
    process = Path(value["procDir"])
    process.mkdir(parents=True, exist_ok=True)
    (process / "stat").write_text(pane + " (claude) S 1 " + pane + " " + pane + " 0 -1", encoding="utf-8")
    (process / "cmdline").write_bytes(b"claude\0")
    fake_write(dict(mode=value["mode"], box="", queue=[], suggestion=value["suggestion"]))
    if value.get("name") == "reactions":
        fake_event("user", message=dict(role="user", content="start the reaction session"))
        prefix = "Same first words " + "for this example " * 8
        for identity, suffix in (("msg_first", "FIRST REPLY"), ("msg_second", "SECOND REPLY")):
            fake_event("assistant", message=dict(role="assistant", id=identity, content=[dict(type="text", text=prefix + "\n" + suffix)]))
        return 0
    fake_event("user", message=dict(role="user", content=("Please outline the next steps for this sample project. We need clear details and readable messages that wrap naturally within the centered chat column. Please include the implementation order, the checks to run, and how to confirm the result in both wide and narrow views. Width sample: " + "M" * 100 if os.environ.get("CHAT_WIDTH_PROOF") == "1" else "start the fake session")))
    fake_event("assistant", message=dict(role="assistant", id="msg_" + uuid.uuid4().hex[:12], model="claude-opus-5-5", content=[dict(type="text", text=("The fake session is ready. Here is a sample reply with enough detail to wrap across several lines. Both sides should stay comfortably inside the chat column as the window becomes narrower. Width sample: " + "M" * 100 if os.environ.get("CHAT_WIDTH_PROOF") == "1" else "The fake session is ready."))]))
    return 0


def session_names():
    return state().get("sessions") or ["verify-agent"]


def seed_event(handle, sid, kind, **fields):
    row = dict(type=kind, timestamp=fake_stamp(), sessionId=sid, uuid=str(uuid.uuid4()), isSidechain=False)
    row.update(fields)
    handle.write((json.dumps(row, ensure_ascii=True) + "\n").encode("utf-8"))


SEED_PARAGRAPH = "This paragraph stands in for a long assistant answer with enough words to wrap across several lines of the chat column, so every message needs real text layout work when the transcript is shown. "


def fake_seed_many(rounds):
    value = state()
    home = Path(value["home"])
    for index, name in enumerate(value["sessions"]):
        pid = value["panes"][name]
        sid = value["sids"][name]
        cwd = f"C:/verify/work{index}"
        transcript = home / ".claude" / "projects" / re.sub(r"[^A-Za-z0-9]", "-", cwd) / f"{sid}.jsonl"
        meta = home / ".claude" / "sessions" / f"{pid}.json"
        process = Path(value["procRoot"]) / str(pid)
        for target in (transcript, meta):
            target.parent.mkdir(parents=True, exist_ok=True)
        meta.write_text(json.dumps(dict(sessionId=sid, cwd=cwd, pid=pid)), encoding="utf-8")
        process.mkdir(parents=True, exist_ok=True)
        (process / "stat").write_text(f"{pid} (claude) S 1 {pid} {pid} 0 -1", encoding="utf-8")
        (process / "cmdline").write_bytes(b"claude\0")
        with open(transcript, "wb") as output:
            for r in range(rounds):
                seed_event(output, sid, "user", message=dict(role="user", content=f"Session {index} question {r}: please explain the next step in detail and show the checks to run."))
                body = f"Session {index} answer {r}\n\n" + (SEED_PARAGRAPH * 3 + "\n\n") * 3
                body += "- first point with some explanatory words\n- second point with some explanatory words\n- third point with some explanatory words\n\n"
                body += "```python\n" + "".join(f"value_{k} = compute({k}, {r})\n" for k in range(8)) + "```\n"
                if r % 10 == 0:
                    body += "\n| name | value |\n| --- | --- |\n" + "".join(f"| row {k} | {k * r} |\n" for k in range(5))
                seed_event(output, sid, "assistant", message=dict(role="assistant", id="msg_" + uuid.uuid4().hex[:12], model="claude-opus-5-5", content=[dict(type="text", text=body)]))
                identity = f"seed-{index}-{r}"
                seed_event(output, sid, "assistant", message=dict(role="assistant", id="msg_" + uuid.uuid4().hex[:12], content=[dict(type="tool_use", id=identity, name="Bash", input=dict(command="echo seeded"))]))
                seed_event(output, sid, "user", message=dict(role="user", content=[dict(type="tool_result", tool_use_id=identity, content="seeded tool output " * 100, is_error=False)]))
    fake_write(dict(mode="idle", box="", queue=[], suggestion=value["suggestion"]))
    return 0


def shell():
    op = ARGS[0] if ARGS else ""
    if op == "resume" and len(ARGS) == 2:
        value = state()
        value["sid"] = ARGS[1]
        value["transcript"] = str(Path(value["transcript"]).with_name(value["sid"] + ".jsonl"))
        (ROOT / "state.json").write_text(json.dumps(value), encoding="utf-8")
        return fake_init()
    if op == "turn" and len(ARGS) == 2:
        question, answer = "Remote question " + ARGS[1], "Remote answer " + ARGS[1]
        fake_event("user", message=dict(role="user", content=question))
        fake_event("assistant", message=dict(role="assistant", content=[dict(type="text", text=answer)]))
        return 0 if fake_run("shell", op, ARGS, lambda claude: claude.setdefault("turns", []).append([question, answer]) is None) else 3
    if op == "detach-console":
        (ROOT / "console-detached").touch()
        return 0
    if op == "init":
        return fake_init()
    if op == "reply-reference":
        original = "The original message starts here.\nSecond original line for context.\nThird original line stays on the wire.\nFourth original line ends the quote."
        fake_event("assistant", message=dict(role="assistant", content=[dict(type="text", text=original)]))
        for i in range(20):
            fake_event("user", message=dict(role="user", content=f"Intervening question {i}"))
            fake_event("assistant", message=dict(role="assistant", content=[dict(type="text", text=f"Intervening answer {i}")]))
        quoted = "\n".join("> " + line for line in original.split("\n"))
        fake_event("user", message=dict(role="user", content=quoted + "\n\nMy compact answer"))
        fake_event("assistant", message=dict(role="assistant", content=[dict(type="text", text="Reply received.")]))
        return 0
    if op == "session-notes":
        senders = ["Hax Runner 10", "Chief Of Staff", "Poteto", "hax-runner-6", "hax-runner-2"]
        for sender in senders:
            body = "IGSH-975 native journey is now fully green. " + "Details follow in a very long machine message that used to fill the whole screen. " * 6 + "Run: https://example.com/run"
            fake_event("user", message=dict(role="user", content=f"[from {sender}] {body}"))
        return 0
    if op == "seed-many" and len(ARGS) == 2:
        return fake_seed_many(int(ARGS[1]))
    if op == "messages" and len(ARGS) == 2:
        for i in range(int(ARGS[1])):
            fake_event("assistant", message=dict(role="assistant", id="msg_" + uuid.uuid4().hex[:12], model="claude-opus-5-5", content=[dict(type="text", text="New message " + str(i) + "\n" + "Readable transcript paragraph with enough text to paint a full message row.\n\n" * 32)]))
        return 0
    if op in ("retention-init", "retention-burst"):
        count = 1998 if op == "retention-init" else int(ARGS[1])
        counter = ROOT / "retention-count"
        start = int(counter.read_text()) if counter.exists() else 0
        for i in range(start, start + count):
            fake_event("assistant", message=dict(role="assistant", id=f"retention-{i}", content=[dict(type="text", text=f"IGSH934 message {i:05d}")]))
        counter.write_text(str(start + count))
        transcript = Path(state()["transcript"])
        with (ROOT / "retention-expected.jsonl").open("ab") as output:
            rows = transcript.read_bytes().splitlines(keepends=True)
            output.write(b"".join(rows if op == "retention-init" else rows[-count:]))
        return 0
    if op == "retention-reset":
        transcript = Path(state()["transcript"])
        tail = b"".join(transcript.read_bytes().splitlines(keepends=True)[-20:])
        replacement = transcript.with_suffix(".replacement")
        replacement.write_bytes(tail)
        os.replace(replacement, transcript)
        return 0
    if op == "retention-empty":
        transcript = Path(state()["transcript"])
        (ROOT / "retention-source-backup").write_bytes(transcript.read_bytes())
        transcript.write_bytes(b"")
        return 0
    if op == "retention-restore":
        Path(state()["transcript"]).write_bytes((ROOT / "retention-source-backup").read_bytes())
        return 0
    if op == "switch-history":
        for i in range(2000):
            text = f"IGSH954 message {i:04d}\n\n" + "A realistic long conversation paragraph with **readable words** and enough detail to wrap within the chat column. " * 8
            fake_event("assistant", message=dict(role="assistant", id="switch-" + str(i), content=[dict(type="text", text=text)]))
        return 0
    if op == "history":
        for i in range(24):
            fake_event("user", message=dict(role="user", content=f"IGSH815 user {i:02d}"))
            fake_event("assistant", message=dict(role="assistant", id="msg_" + uuid.uuid4().hex[:12], model="claude-opus-5-5", content=[dict(type="text", text=f"IGSH815 assistant {i:02d}")]))
            identity = "history-" + str(i)
            fake_event("assistant", message=dict(role="assistant", id="msg_" + uuid.uuid4().hex[:12], content=[dict(type="tool_use", id=identity, name="Bash", input=dict(command="echo history"))]))
            fake_event("user", message=dict(role="user", content=[dict(type="tool_result", tool_use_id=identity, content="synthetic tool output " * (40000 if state().get("longChatProof") else 12000), is_error=False)]))
        return 0
    if op == "forget-message" and len(ARGS) == 2:
        transcript = Path(state()["transcript"])
        rows = transcript.read_bytes().splitlines(keepends=True)
        kept = [row for row in rows if json.loads(row).get("message", {}).get("id") != ARGS[1]]
        if len(kept) != len(rows) - 1:
            raise ValueError("Expected one source message to disappear")
        transcript.write_bytes(b"".join(kept))
        return 0
    if op == "todo":
        fake_event("assistant", message=dict(role="assistant", id="msg_" + uuid.uuid4().hex[:12], model="claude-opus-5-5", content=[dict(type="tool_use", id="activity-todo", name="TodoWrite", input=dict(todos=[dict(content="Prove the status row", status="pending", activeForm="Proving the status row")]))]))
        fake_event("user", message=dict(role="user", content=[dict(type="tool_result", tool_use_id="activity-todo", content="verified", is_error=False)]))
        return 0
    if op == "activity":
        descriptions = ["Check app-smoke state", "Inspect app-smoke run details", "Read commit statuses on PR head"]
        for i in range(11):
            identity = "activity-" + str(i)
            fake_event("assistant", message=dict(role="assistant", id="msg_" + uuid.uuid4().hex[:12], model="claude-opus-5-5", content=[dict(type="tool_use", id=identity, name="Bash", input=dict(command="echo verified", description=descriptions[i % len(descriptions)]))]))
            fake_event("user", message=dict(role="user", content=[dict(type="tool_result", tool_use_id=identity, content="verified", is_error=False)]))
        return 0
    if op == "reaction-fallback":
        fake_event("user", message=dict(role="user", content="👍 to: Unavailable reply [mp:0000000000000000]"))
        return 0
    if op == "show":
        sys.stdout.write(json.dumps(fake_locked(fake_read)) + "\n")
        return 0
    if op == "text" and len(ARGS) == 2:
        change = lambda claude: claude.__setitem__("box", claude["box"] + ARGS[1]) is None
    elif op == "key" and len(ARGS) == 2:
        change = lambda claude: fake_key(claude, ARGS[1])
    elif op == "accept":
        def change(claude):
            text = claude["queue"].pop(0)
            fake_queue_event("remove", text, reason="absorbed_mid_turn")
            (ROOT / "accepted.json").write_text(json.dumps(dict(text=text, ms=time.time_ns() // 1_000_000)), encoding="utf-8")
            return True
    elif op == "idle":
        change = lambda claude: fake_take(claude) is None
    elif op == "busy":
        change = lambda claude: claude.__setitem__("mode", "busy") is None
    else:
        record("unsupported.jsonl", operation="shell input", argv=ARGS)
        return 2
    return 0 if fake_run("shell", op, ARGS, change) else 3


class COORD(ctypes.Structure):
    _fields_ = [("X", ctypes.c_short), ("Y", ctypes.c_short)]


class RECT(ctypes.Structure):
    _fields_ = [("Left", ctypes.c_short), ("Top", ctypes.c_short), ("Right", ctypes.c_short), ("Bottom", ctypes.c_short)]


class INFO(ctypes.Structure):
    _fields_ = [("size", COORD), ("cursor", COORD), ("attributes", wintypes.WORD), ("window", RECT), ("maximum", COORD)]


def attach(session):
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.GetStdHandle.restype = wintypes.HANDLE
    kernel.GetConsoleScreenBufferInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(INFO)]
    kernel.FillConsoleOutputCharacterW.argtypes = [wintypes.HANDLE, wintypes.WCHAR, wintypes.DWORD, COORD, ctypes.POINTER(wintypes.DWORD)]
    kernel.FillConsoleOutputAttribute.argtypes = [wintypes.HANDLE, wintypes.WORD, wintypes.DWORD, COORD, ctypes.POINTER(wintypes.DWORD)]
    kernel.ReadConsoleOutputCharacterW.argtypes = [wintypes.HANDLE, wintypes.LPWSTR, wintypes.DWORD, COORD, ctypes.POINTER(wintypes.DWORD)]
    kernel.ReadConsoleOutputAttribute.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.WORD), wintypes.DWORD, COORD, ctypes.POINTER(wintypes.DWORD)]
    kernel.SetConsoleCursorPosition.argtypes = [wintypes.HANDLE, COORD]
    kernel.SetConsoleTextAttribute.argtypes = [wintypes.HANDLE, wintypes.WORD]
    kernel.WriteConsoleW.argtypes = [wintypes.HANDLE, wintypes.LPCWSTR, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD), wintypes.LPVOID]
    handle = kernel.GetStdHandle(-11)
    previous = None
    (ROOT / f"transport-{os.getpid()}.txt").write_text(session, encoding="utf-8")
    while True:
        value = state()
        info = INFO()
        count = wintypes.DWORD()
        if not kernel.GetConsoleScreenBufferInfo(handle, ctypes.byref(info)):
            raise ctypes.WinError(ctypes.get_last_error())
        geometry = (info.size.X, info.size.Y, info.window.Top, info.window.Bottom)
        if (value, geometry) != previous:
            lines = len(screen(value).splitlines())
            top = max(0, info.window.Bottom - lines)
            size = info.size.X * info.size.Y
            if not kernel.FillConsoleOutputCharacterW(handle, " ", size, COORD(0, 0), ctypes.byref(count)):
                raise ctypes.WinError(ctypes.get_last_error())
            kernel.FillConsoleOutputAttribute(handle, 7, size, COORD(0, 0), ctypes.byref(count))
            kernel.SetConsoleCursorPosition(handle, COORD(0, top))
            kernel.SetConsoleTextAttribute(handle, 7)
            text = screen(value).replace("\n", "\r\n")
            if not kernel.WriteConsoleW(handle, text, len(text), ctypes.byref(count), None):
                raise ctypes.WinError(ctypes.get_last_error())
            if value["mode"] == "idle":
                if not kernel.FillConsoleOutputAttribute(handle, 8, len(value["suggestion"]), COORD(2, top + 4), ctypes.byref(count)):
                    raise ctypes.WinError(ctypes.get_last_error())
            kernel.SetConsoleCursorPosition(handle, COORD(2, top + 4))
            raw = ctypes.create_unicode_buffer(info.size.X * lines)
            if not kernel.ReadConsoleOutputCharacterW(handle, raw, len(raw), COORD(0, top), ctypes.byref(count)):
                raise ctypes.WinError(ctypes.get_last_error())
            rows = [raw[i * info.size.X:(i + 1) * info.size.X].rstrip() for i in range(lines)]
            if rows != [line.rstrip() for line in screen(value).splitlines()]:
                raise RuntimeError("Console screen readback mismatch")
            attribute = wintypes.WORD()
            if not kernel.ReadConsoleOutputAttribute(handle, ctypes.byref(attribute), 1, COORD(2, top + 4), ctypes.byref(count)):
                raise ctypes.WinError(ctypes.get_last_error())
            if value["mode"] == "idle" and attribute.value != 8:
                raise RuntimeError("Console suggestion is not grey")
            record("console.jsonl", session=session, screen=screen(value), rows=rows, suggestionAttribute=attribute.value, promptRow=top + 4, greySuggestion=value["mode"] == "idle")
            (ROOT / "ready.json").write_text(json.dumps(dict(pid=os.getpid(), session=session, screen=screen(value))), encoding="utf-8")
            previous = (value, geometry)
        time.sleep(0.1)


def box_send():
    buffer = box_buffer()
    submitted = None
    sent = ARGS[3:]
    if sent[:1] == ["-l"]:
        buffer += sent[sent.index("--") + 1] if "--" in sent else ""
    else:
        for name in sent:
            if name == "C-u":
                buffer = ctrl_u(buffer)
            elif name == "C-k":
                buffer = ctrl_k(buffer, len(buffer))
            elif name == "Enter":
                submitted = buffer if buffer.strip() else None
                buffer = ""
            else:
                record("unsupported.jsonl", operation="box key", argv=ARGS)
                return 95
    (ROOT / "box.json").write_text(json.dumps(dict(buffer=buffer)), encoding="utf-8")
    record("agent-buffer.jsonl", argv=ARGS, submitted=submitted, box=buffer)
    return 0


def console_kernel():
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.GetStdHandle.restype = wintypes.HANDLE
    kernel.GetConsoleScreenBufferInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(INFO)]
    kernel.FillConsoleOutputCharacterW.argtypes = [wintypes.HANDLE, wintypes.WCHAR, wintypes.DWORD, COORD, ctypes.POINTER(wintypes.DWORD)]
    kernel.FillConsoleOutputAttribute.argtypes = [wintypes.HANDLE, wintypes.WORD, wintypes.DWORD, COORD, ctypes.POINTER(wintypes.DWORD)]
    kernel.ReadConsoleOutputCharacterW.argtypes = [wintypes.HANDLE, wintypes.LPWSTR, wintypes.DWORD, COORD, ctypes.POINTER(wintypes.DWORD)]
    kernel.ReadConsoleOutputAttribute.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.WORD), wintypes.DWORD, COORD, ctypes.POINTER(wintypes.DWORD)]
    kernel.SetConsoleCursorPosition.argtypes = [wintypes.HANDLE, COORD]
    kernel.SetConsoleTextAttribute.argtypes = [wintypes.HANDLE, wintypes.WORD]
    kernel.WriteConsoleW.argtypes = [wintypes.HANDLE, wintypes.LPCWSTR, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD), wintypes.LPVOID]
    return kernel


def console_rows(lines, width):
    width = max(1, width)
    rows = []
    for line in lines:
        rows.extend(line[start:start + width] for start in range(0, max(len(line), 1), width))
    return rows


def attach_fake(session):
    if (ROOT / "console-detached").exists():
        return
    kernel = console_kernel()
    handle = kernel.GetStdHandle(-11)
    previous = None
    (ROOT / f"transport-{os.getpid()}.txt").write_text(session, encoding="utf-8")
    while True:
        if (ROOT / "console-detached").exists():
            return
        claude = fake_locked(fake_read)
        info = INFO()
        count = wintypes.DWORD()
        if not kernel.GetConsoleScreenBufferInfo(handle, ctypes.byref(info)):
            raise ctypes.WinError(ctypes.get_last_error())
        geometry = (info.size.X, info.size.Y, info.window.Top, info.window.Bottom)
        if (claude, geometry) != previous:
            shown = fake_screen(claude, False)
            lines = console_rows(shown.splitlines(), info.size.X - 1)
            top = max(0, info.window.Bottom - len(lines))
            row = next(i for i, line in enumerate(lines) if line.startswith("❯"))
            size = info.size.X * info.size.Y
            if not kernel.FillConsoleOutputCharacterW(handle, " ", size, COORD(0, 0), ctypes.byref(count)):
                raise ctypes.WinError(ctypes.get_last_error())
            kernel.FillConsoleOutputAttribute(handle, 7, size, COORD(0, 0), ctypes.byref(count))
            kernel.SetConsoleCursorPosition(handle, COORD(0, top))
            kernel.SetConsoleTextAttribute(handle, 7)
            text = "\r\n".join(lines) + "\r\n"
            if not kernel.WriteConsoleW(handle, text, len(text), ctypes.byref(count), None):
                raise ctypes.WinError(ctypes.get_last_error())
            grey = fake_suggestion_shown(claude)
            if grey and not kernel.FillConsoleOutputAttribute(handle, 8, len(claude["suggestion"]), COORD(2, top + row), ctypes.byref(count)):
                raise ctypes.WinError(ctypes.get_last_error())
            kernel.SetConsoleCursorPosition(handle, COORD(2, top + row))
            raw = ctypes.create_unicode_buffer(info.size.X * len(lines))
            if not kernel.ReadConsoleOutputCharacterW(handle, raw, len(raw), COORD(0, top), ctypes.byref(count)):
                raise ctypes.WinError(ctypes.get_last_error())
            rows = [raw[i * info.size.X:(i + 1) * info.size.X].rstrip() for i in range(len(lines))]
            if rows != [line.rstrip() for line in lines]:
                raise RuntimeError("Console screen readback mismatch")
            attribute = wintypes.WORD()
            if not kernel.ReadConsoleOutputAttribute(handle, ctypes.byref(attribute), 1, COORD(2, top + row), ctypes.byref(count)):
                raise ctypes.WinError(ctypes.get_last_error())
            if grey and attribute.value != 8:
                raise RuntimeError("Console suggestion is not grey")
            record("console.jsonl", session=session, screen=shown, rows=rows, suggestionAttribute=attribute.value, promptRow=top + row, greySuggestion=grey)
            (ROOT / "ready.json").write_text(json.dumps(dict(pid=os.getpid(), session=session, screen=shown)), encoding="utf-8")
            previous = (claude, geometry)
        time.sleep(0.05)


def tmux():
    fake = state().get("fake")
    if ARGS[:1] == ["capture-pane"]:
        if fake:
            shown = fake_locked(lambda: fake_screen(fake_read(), "-e" in ARGS))
        else:
            value = state()
            shown = screen(value, box_buffer() if stateful(value) else None)
        record("capture.jsonl", argv=ARGS, screen=shown)
        if not fake and "-e" in ARGS and state()["mode"] == "idle":
            suggestion = state()["suggestion"]
            shown = shown.replace("\u276f " + suggestion, "\u276f " + SGR_DIM + suggestion + SGR_RESET, 1)
        sys.stdout.reconfigure(newline="\n")
        sys.stdout.write(shown)
        return 0
    if ARGS[:1] == ["send-keys"] and state().get("sendingProof") and "-l" in ARGS:
        (ROOT / "send-blocked").touch()
        deadline = time.monotonic() + 30
        while not (ROOT / "release-send").exists():
            if time.monotonic() > deadline:
                return 96
            time.sleep(0.05)
    if ARGS[:1] == ["send-keys"]:
        if stateful(state()):
            return box_send()
        record("agent-buffer.jsonl", argv=ARGS)
        if fake and not fake_send(ARGS):
            record("unsupported.jsonl", argv=ARGS)
            return 95
        return 0
    if ARGS[:1] == ["list-panes"]:
        if fake:
            panes = state().get("panes")
            if panes:
                target = ARGS[ARGS.index("-t") + 1].lstrip("=") if "-t" in ARGS else ""
                if target in panes:
                    sys.stdout.write(str(panes[target]) + "\n")
            else:
                sys.stdout.write(str(state()["panePid"]) + "\n")
        return 0
    record("unsupported.jsonl", argv=ARGS)
    return 95


VPS_POLL_COMMAND = (
    "printf '@capacity|'; "
    "getconf _NPROCESSORS_ONLN 2>/dev/null | tr '\\n' '|'; "
    "cut -d' ' -f1 /proc/loadavg 2>/dev/null | tr '\\n' '|'; "
    "grep '^MemTotal:' /proc/meminfo | tr -s ' ' | cut -d' ' -f2 | tr '\\n' '|'; "
    "grep '^MemAvailable:' /proc/meminfo | tr -s ' ' | cut -d' ' -f2 | tr '\\n' '|'; "
    "grep '^SwapTotal:' /proc/meminfo | tr -s ' ' | cut -d' ' -f2 | tr '\\n' '|'; "
    "grep '^SwapFree:' /proc/meminfo | tr -s ' ' | cut -d' ' -f2 | tr '\\n' '|'; "
    "(head -1 /proc/pressure/cpu 2>/dev/null || printf 'some avg10=0.00') | cut -d' ' -f2 | cut -d= -f2 | tr '\\n' '|'; "
    "(head -1 /proc/pressure/memory 2>/dev/null || printf 'some avg10=0.00') | cut -d' ' -f2 | cut -d= -f2 | tr '\\n' '|'; "
    "(head -1 /proc/pressure/io 2>/dev/null || printf 'some avg10=0.00') | cut -d' ' -f2 | cut -d= -f2 | tr '\\n' '|'; "
    "printf '\\n'; "
    "~/.local/bin/tmux-list.sh 2>/dev/null || tmux list-sessions -F '#{session_name}|#{session_activity}|0|#{session_path}|#{pane_current_command}|#{pane_title}' 2>/dev/null"
)


def declined_remote(argv):
    pos = 0
    forward = None
    while pos < len(argv) and argv[pos].startswith("-"):
        option = argv[pos]
        if option in ("-o", "-R") and pos + 1 < len(argv):
            if option == "-R":
                forward = argv[pos + 1]
            pos += 2
        elif option in ("-T", "-N"):
            pos += 1
        else:
            return None
    if pos >= len(argv):
        return None
    remote = " ".join(argv[pos + 1:])
    if not remote and "-N" in argv[:pos] and forward and re.fullmatch(r"19548:127\.0\.0\.1:[0-9]{1,5}", forward):
        return "notification-forward", "", 255
    if forward is not None:
        return None
    if remote == "cat ~/.local/state/token-ladder/status.json":
        return "ladder-status", "", 1
    if re.fullmatch(r"if test -f ~/\.local/state/multiprompt/relay-v1; then mkdir -p -m 700 /tmp/mp-notify-\$\(id -u\) && rm -f /tmp/mp-notify-\$\(id -u\)/[A-Za-z0-9_-]{1,32}-[0-9a-f]{16}\.sock && printf MP_RELAY_UID: && id -u; else echo MP_RELAY_LEGACY; fi", remote):
        return "notification-relay", "MP_RELAY_LEGACY\n", 0
    if remote in (VPS_POLL_COMMAND, "while IFS= read -r _; do { " + VPS_POLL_COMMAND + "; } </dev/null; printf '@@ZS_END@@\\n'; done"):
        return "capacity-poll", "", 1
    return None


def completion(remote):
    spec = importlib.util.spec_from_file_location("mp_complete", Path(__file__).parents[1] / "agent-notifications/mp_complete.py")
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    helper.CACHE.parent.mkdir(parents=True, exist_ok=True)

    def reply(line):
        helper.CACHE.write_text(json.dumps({"key": helper.cache_key(), "at": time.time(), "commands": []}), encoding="utf-8")
        response = helper.request(line)
        rows = [row.split("\t")[1] for row in response.splitlines()[1:-1]]
        record("completion.jsonl", request=line.strip(), names=rows)
        time.sleep(0.8)
        return response

    if remote[2:] == ["--serve"]:
        for line in sys.stdin:
            sys.stdout.write(reply(line))
            sys.stdout.flush()
        return 0
    if len(remote) == 4 and remote[2] == "--once":
        import base64
        sys.stdout.write(reply(base64.b64decode(remote[3]).decode("utf-8")))
        return 0
    return 95


def ssh():
    if ARGS == ["-V"]:
        print("OpenSSH_verification")
        return 0
    command = " ".join(ARGS)
    declined = declined_remote(ARGS)
    if declined:
        kind, output, exit_code = declined
        record("declined.jsonl", operation="remote command", kind=kind, argv=ARGS, command=command, exitCode=exit_code)
        sys.stdout.write(output)
        return exit_code
    if state().get("binding") and "exec ${SHELL:-bash} -l" in command:
        record("invocations.jsonl", kind="login", session="workspace")
        attach("workspace")
        return 0
    python = re.search(r"\bpython3\s", command)
    if python:
        remote = shlex.split(command[python.start():])
        if remote[1].endswith("/mp_complete.py"):
            return completion(remote)
        record("invocations.jsonl", kind="reader", argv=remote)
        env = os.environ.copy()
        if state().get("remoteHome"):
            env.update(HOME=state()["remoteHome"], USERPROFILE=state()["remoteHome"])
        with (ROOT / f"reader-{os.getpid()}.stderr.log").open("ab", buffering=0) as error:
            return subprocess.call([sys.executable, *remote[1:]], stdin=sys.stdin.buffer, stdout=sys.stdout.buffer, stderr=error, env=env, creationflags=subprocess.CREATE_NO_WINDOW)
    if "tmux list-clients" in command:
        record("invocations.jsonl", kind="probe", operation="list-clients/list-sessions")
        names = session_names()
        identity = "".join(f"@@I {name}|{state().get('generation', '1700:123:$7')}\n" for name in names) if state().get("binding") else ""
        print("\n".join(names) + "\n" + identity + "".join(f"@@S {name}\n" for name in names) + "@@LS_OK@@\n@@MP_LIVE@@")
        return 0
    if "tmux list-sessions" in command:
        record("invocations.jsonl", kind="list", operation="list-sessions")
        for name in session_names():
            print(name + "\t1\t1")
        return 0
    if state().get("binding") and "tmux if-shell -F -t " in command:
        expected = re.search(r"#\{==:#\{start_time\}:#\{pid\}:#\{session_id\},([0-9:$]+)\}", command)
        current = state().get("generation", "1700:123:$7")
        if not expected:
            raise RuntimeError("Guarded attach omitted the expected generation")
        if expected[1] != current:
            record("invocations.jsonl", kind="refused", expected=expected[1], actual=current, command=command)
            print("Saved terminal session changed; refusing to attach.")
            return 0
        record("invocations.jsonl", kind="attach", session="workspace", identity=current, command=command)
        attach("workspace")
        return 0
    match = re.search(r"tmux attach -t ['\"]?=?([A-Za-z0-9._:-]+)", command)
    if match and match[1] in session_names():
        record("invocations.jsonl", kind="attach", session=match[1])
        (attach_fake if state().get("fake") else attach)(match[1])
        return 0
    record("unsupported.jsonl", operation="remote command", hasPython=bool(python), argv=ARGS, command=command)
    return 96


if __name__ == "__main__":
    sys.exit(tmux() if MODE == "tmux" else shell() if MODE == "shell" else ssh())
