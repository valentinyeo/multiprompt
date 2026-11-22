import base64
import fcntl
import json
import os
import pty
import selectors
import signal
import struct
import sys
import termios

MAX_INPUT = 2 * 1024 * 1024


def dimensions(value):
    if not isinstance(value, list) or len(value) != 2:
        raise ValueError("invalid terminal size")
    rows, cols = value
    if type(rows) is not int or type(cols) is not int or not 1 <= rows <= 512 or not 1 <= cols <= 1024:
        raise ValueError("invalid terminal size")
    return rows, cols


def emit(data):
    sys.stdout.buffer.write(base64.b64encode(data) + b"\n")
    sys.stdout.buffer.flush()


def run():
    incoming = bytearray(sys.stdin.buffer.read1(MAX_INPUT + 1))
    while b"\n" not in incoming:
        if len(incoming) > MAX_INPUT:
            raise ValueError("invalid terminal opening request")
        data = os.read(sys.stdin.fileno(), 65536)
        if not data:
            raise ValueError("incomplete terminal opening request")
        incoming.extend(data)
    first, _, rest = incoming.partition(b"\n")
    incoming[:] = rest
    opening = json.loads(first)
    command = opening.get("command")
    if not isinstance(command, str) or not command or len(command) > 16384 or "\0" in command:
        raise ValueError("invalid terminal command")
    rows, cols = dimensions(opening.get("size"))
    pid, master = pty.fork()
    if pid == 0:
        fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
        environment = dict(os.environ, TERM="xterm-256color", COLORTERM="truecolor")
        shell = "/bin/bash" if os.path.exists("/bin/bash") else "/bin/sh"
        os.execve(shell, [os.path.basename(shell), "-lc", command], environment)
    selector = selectors.DefaultSelector()
    pending = bytearray()

    def resize(size):
        height, width = dimensions(size)
        fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", height, width, 0, 0))

    try:
        resize([rows, cols])
        selector.register(master, selectors.EVENT_READ, "terminal")
        selector.register(sys.stdin.fileno(), selectors.EVENT_READ, "input")
        while True:
            while b"\n" in incoming:
                line, _, rest = incoming.partition(b"\n")
                incoming[:] = rest
                value = json.loads(line)
                if "size" in value:
                    resize(value["size"])
                elif "input" in value:
                    encoded = value["input"]
                    if not isinstance(encoded, str):
                        raise ValueError("invalid terminal input")
                    pending.extend(base64.b64decode(encoded, validate=True))
                    if len(pending) > MAX_INPUT:
                        raise ValueError("terminal input overflow")
                    selector.modify(master, selectors.EVENT_READ | selectors.EVENT_WRITE, "terminal")
                else:
                    raise ValueError("unknown terminal request")
            for key, mask in selector.select():
                if key.data == "input":
                    data = os.read(sys.stdin.fileno(), 65536)
                    if not data:
                        return
                    incoming.extend(data)
                    if len(incoming) > MAX_INPUT:
                        raise ValueError("terminal input overflow")
                else:
                    if mask & selectors.EVENT_READ:
                        try:
                            data = os.read(master, 65536)
                        except OSError:
                            return
                        if not data:
                            return
                        emit(data)
                    if mask & selectors.EVENT_WRITE and pending:
                        count = os.write(master, pending)
                        del pending[:count]
                        if not pending:
                            selector.modify(master, selectors.EVENT_READ, "terminal")
    finally:
        selector.close()
        os.close(master)
        try:
            os.killpg(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        try:
            os.waitpid(pid, 0)
        except ChildProcessError:
            pass


if __name__ == "__main__":
    for event in (signal.SIGHUP, signal.SIGTERM):
        signal.signal(event, lambda *_: sys.exit(0))
    run()
