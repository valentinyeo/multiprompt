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


def screen(value):
    return "Claude Code\n\n" + ("Working... (esc to interrupt)\n" if value["mode"] == "busy" else "Ready\n") + "\n\u276f " + (value["suggestion"] if value["mode"] == "idle" else "") + "\n" + "\u2500" * 50 + "\n"


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
            top = max(0, info.window.Bottom - 6)
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
            raw = ctypes.create_unicode_buffer(info.size.X * 6)
            if not kernel.ReadConsoleOutputCharacterW(handle, raw, len(raw), COORD(0, top), ctypes.byref(count)):
                raise ctypes.WinError(ctypes.get_last_error())
            rows = [raw[i * info.size.X:(i + 1) * info.size.X].rstrip() for i in range(6)]
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


def tmux():
    if ARGS[:1] == ["capture-pane"]:
        shown = screen(state())
        record("capture.jsonl", argv=ARGS, screen=shown)
        sys.stdout.write(shown)
        return 0
    if ARGS[:1] == ["send-keys"]:
        record("agent-buffer.jsonl", argv=ARGS)
        return 0
    if ARGS[:1] == ["list-panes"]:
        return 0
    record("unsupported.jsonl", argv=ARGS)
    return 95


def ssh():
    if ARGS == ["-V"]:
        print("OpenSSH_verification")
        return 0
    command = " ".join(ARGS)
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
    record("unsupported.jsonl", operation="remote command", hasPython=bool(python))
    return 96


if __name__ == "__main__":
    sys.exit(tmux() if MODE == "tmux" else ssh())
