import base64
import json
import os
import subprocess
import sys
import time

MAX_LINE = 8 * 1024 * 1024


class Lines:
    def next(self):
        line = sys.stdin.buffer.readline(MAX_LINE)
        if not line:
            return None
        if len(line) >= MAX_LINE and not line.endswith(b"\n"):
            raise ValueError("terminal line too long")
        return line[:-1] if line.endswith(b"\n") else line


def emit(value):
    sys.stdout.buffer.write(json.dumps(value, separators=(",", ":")).encode() + b"\n")
    sys.stdout.buffer.flush()


def log_dir():
    return os.environ.get("HARNESS_MATRIX_LOG") or ""


def host_name():
    return os.environ.get("HARNESS_HOST") or "vps1"


def append(name, value):
    folder = log_dir()
    if not folder:
        return
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, name), "a", encoding="utf-8") as handle:
        handle.write(json.dumps(value) + "\n")


def note_size(text):
    try:
        value = json.loads(text)
    except ValueError:
        return
    size = value.get("size") if isinstance(value, dict) else None
    if isinstance(size, list) and len(size) == 2 and all(isinstance(item, int) for item in size):
        append(host_name() + "-size.jsonl", {"rows": size[0], "cols": size[1], "t": time.time()})


def allowed():
    raw = os.environ.get("HARNESS_VERSION_COMMANDS") or ""
    return {item for item in raw.split("\n") if item}


def version_output(command):
    if command not in allowed():
        return b""
    try:
        result = subprocess.run(command.split(" "), capture_output=True, timeout=8, stdin=subprocess.DEVNULL)
    except (OSError, subprocess.SubprocessError):
        return b""
    body = result.stdout + result.stderr
    append(host_name() + "-version.jsonl", {"command": command, "text": body.decode("utf-8", "replace")})
    return body


def trace(text):
    folder = log_dir()
    if not folder:
        return
    try:
        os.makedirs(folder, exist_ok=True)
        with open(os.path.join(folder, host_name() + "-host.log"), "a", encoding="utf-8") as handle:
            handle.write(text + "\n")
    except OSError:
        return


def main():
    lines = Lines()
    trace("boot")
    if lines.next() is None or lines.next() is None:
        trace("stdin ended before the channel was ready")
        return 1
    emit({"ready": True})
    trace("ready")
    typed = {}
    while True:
        raw = lines.next()
        if raw is None:
            return 0
        try:
            packet = json.loads(raw)
        except ValueError:
            continue
        if not isinstance(packet, dict):
            continue
        data = packet.get("data")
        if isinstance(data, str):
            note_size(data)
        if not packet.get("terminal") or not isinstance(data, str):
            continue
        try:
            value = json.loads(data)
        except ValueError:
            continue
        encoded = value.get("input") if isinstance(value, dict) else None
        if not isinstance(encoded, str):
            continue
        try:
            decoded = base64.b64decode(encoded, validate=True)
        except ValueError:
            continue
        channel = packet.get("channel")
        emit({"channel": channel, "data": base64.b64encode(decoded).decode("ascii")})
        buffer = typed.get(channel, b"") + decoded
        if b"\n" not in buffer and b"\r" not in buffer:
            typed[channel] = buffer
            continue
        line, _, rest = buffer.replace(b"\r\n", b"\n").replace(b"\r", b"\n").partition(b"\n")
        typed[channel] = rest
        output = version_output(line.decode("utf-8", "replace").strip())
        if output:
            emit({"channel": channel, "data": base64.b64encode(output).decode("ascii")})


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError):
        raise SystemExit(1)
