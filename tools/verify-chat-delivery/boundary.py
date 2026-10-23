import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time

ROOT = Path(os.environ["MP_VERIFY_STATE"])
MODE = sys.argv[1]
ARGS = sys.argv[2:]


def state():
    return json.loads((ROOT / "state.json").read_text(encoding="utf-8-sig"))


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


def box_buffer():
    file = ROOT / "box.json"
    if file.exists():
        return json.loads(file.read_text(encoding="utf-8"))["buffer"]
    return state()["leftover"] + "\n"


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
    head = "Claude Code\n\n" + ("Working... (esc to interrupt)\n" if value["mode"] == "busy" else "Ready\n") + "\n"
    if "leftover" in value:
        rows = box_rows(value["leftover"] + "\n" if buffer is None else buffer)
        return head + "\u276f " + rows[0] + "\n" + "".join("  " + row + "\n" for row in rows[1:]) + "\u2500" * 50 + "\n"
    return head + "\u276f " + (value["suggestion"] if value["mode"] == "idle" else "") + "\n" + "\u2500" * 50 + "\n"


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


def tmux():
    if ARGS[:1] == ["capture-pane"]:
        value = state()
        shown = screen(value, box_buffer() if "leftover" in value else None)
        record("capture.jsonl", argv=ARGS, screen=shown)
        sys.stdout.write(shown)
        return 0
    if ARGS[:1] == ["send-keys"]:
        if "leftover" in state():
            return box_send()
        record("agent-buffer.jsonl", argv=ARGS)
        return 0
    if ARGS[:1] == ["list-panes"]:
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
    python = re.search(r"\bpython3\s", command)
    if python:
        remote = shlex.split(command[python.start():])
        record("invocations.jsonl", kind="reader", argv=remote)
        with (ROOT / f"reader-{os.getpid()}.stderr.log").open("ab", buffering=0) as error:
            return subprocess.call([sys.executable, *remote[1:]], stdin=sys.stdin.buffer, stdout=sys.stdout.buffer, stderr=error, creationflags=subprocess.CREATE_NO_WINDOW)
    if "tmux list-clients" in command:
        record("invocations.jsonl", kind="probe", operation="list-clients/list-sessions")
        print("verify-agent\n@@S verify-agent\n@@LS_OK@@\n@@MP_LIVE@@")
        return 0
    if "tmux list-sessions" in command:
        record("invocations.jsonl", kind="list", operation="list-sessions")
        print("verify-agent\t1\t1")
        return 0
    match = re.search(r"tmux attach -t ['\"]?([A-Za-z0-9._:-]+)", command)
    if match and match[1] == "verify-agent":
        record("invocations.jsonl", kind="attach", session=match[1])
        attach(match[1])
        return 0
    record("unsupported.jsonl", operation="remote command", hasPython=bool(python), argv=ARGS, command=command)
    return 96


if __name__ == "__main__":
    sys.exit(tmux() if MODE == "tmux" else ssh())
