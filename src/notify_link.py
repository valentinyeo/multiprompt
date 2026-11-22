import base64
import errno
import os
import select
import signal
import socket
import stat
import sys
import threading

MAX_CHUNK = 65536
MAX_MESSAGE = 65536
MAX_REPLY = 20 * 1024 * 1024
IDLE = 0.3
REPLY_TIMEOUT = 900
SEND_TIMEOUT = 30
PORT = 19548
RELAY_STATE = "~/.local/state/multiprompt/relay-v1"
NAME = sys.argv[1] if len(sys.argv) > 1 else "laptop"
out_lock = threading.Lock()
waiters = {}
waiters_lock = threading.Lock()
counter_lock = threading.Lock()
counter = [0]
stopping = threading.Event()


def emit(line):
    try:
        with out_lock:
            sys.stdout.write(line + "\n")
            sys.stdout.flush()
    except (OSError, ValueError):
        stopping.set()


def next_id():
    with counter_lock:
        counter[0] += 1
        return counter[0]


def unix_server():
    directory = "/tmp/mp-notify-" + str(os.getuid())
    os.makedirs(directory, mode=0o700, exist_ok=True)
    info = os.lstat(directory)
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        raise OSError(errno.EACCES, "unsafe socket directory")
    path = os.path.join(directory, NAME + ".sock")
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        server.bind(path)
        server.listen()
    except OSError:
        server.close()
        raise
    os.chmod(path, 0o600)
    return server, path


def tcp_server():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        server.bind(("127.0.0.1", PORT))
        server.listen()
    except OSError:
        server.close()
        raise
    return server, None


def open_server():
    if os.path.exists(os.path.expanduser(RELAY_STATE)):
        server, path = unix_server()
        emit("rdy unix " + path)
        return server, path
    server, path = tcp_server()
    emit("rdy tcp")
    return server, path


def settle(cid, payload, done):
    with waiters_lock:
        slot = waiters.get(cid)
    if slot is None:
        return
    if payload:
        slot[1].extend(payload)
    if done:
        slot[0].set()


def read_command(text):
    kind, _, rest = text.partition(" ")
    if kind == "a":
        head, _, body = rest.partition(" ")
        try:
            settle(int(head), base64.b64decode(body), False)
        except ValueError:
            return
    elif kind == "x":
        try:
            settle(int(rest), b"", True)
        except ValueError:
            return


def read_stdin():
    buffer = bytearray()
    while not stopping.is_set():
        try:
            chunk = os.read(sys.stdin.fileno(), 65536)
        except OSError:
            break
        if not chunk:
            break
        buffer.extend(chunk)
        if len(buffer) > 2 * 1024 * 1024:
            break
        while b"\n" in buffer:
            line, _, rest = buffer.partition(b"\n")
            buffer[:] = rest
            text = line.decode("ascii", "replace").strip()
            if text:
                read_command(text)
    stopping.set()


def handle(conn, cid):
    try:
        conn.settimeout(IDLE)
        data = bytearray()
        while len(data) < MAX_MESSAGE:
            try:
                chunk = conn.recv(MAX_CHUNK)
            except socket.timeout:
                break
            except OSError:
                return
            if not chunk:
                break
            data.extend(chunk)
            if b"\n" in data:
                break
        if not data:
            return
        slot = [threading.Event(), bytearray()]
        with waiters_lock:
            waiters[cid] = slot
        emit("a " + str(cid) + " " + base64.b64encode(bytes(data)).decode("ascii"))
        slot[0].wait(REPLY_TIMEOUT)
        with waiters_lock:
            waiters.pop(cid, None)
        if slot[1]:
            conn.settimeout(SEND_TIMEOUT)
            conn.sendall(bytes(slot[1][:MAX_REPLY]))
    except OSError:
        pass
    finally:
        try:
            conn.close()
        except OSError:
            pass


def serve():
    try:
        server, path = open_server()
    except OSError as error:
        emit("err " + str(error))
        return 1
    reader = threading.Thread(target=read_stdin, daemon=True)
    reader.start()
    try:
        while not stopping.is_set():
            try:
                readable, _, _ = select.select([server], [], [], 0.5)
            except (OSError, ValueError):
                break
            if not readable:
                continue
            try:
                conn, _ = server.accept()
            except OSError:
                break
            threading.Thread(target=handle, args=(conn, next_id()), daemon=True).start()
    finally:
        try:
            server.close()
        except OSError:
            pass
        if path:
            try:
                os.unlink(path)
            except OSError:
                pass
    return 0


if __name__ == "__main__":
    for name in ("SIGHUP", "SIGTERM"):
        event = getattr(signal, name, None)
        if event is not None:
            signal.signal(event, lambda *_: sys.exit(0))
    sys.exit(serve())
