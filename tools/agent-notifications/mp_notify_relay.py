#!/usr/bin/env python3
from concurrent.futures import ThreadPoolExecutor
import errno
import hmac
import json
import os
from pathlib import Path
import select
import socket
import stat
import subprocess
import sys
import threading
import time

PORT = 19548
MAX_MESSAGE = 65536
SWEEP_INTERVAL = 5
UNSAFE_DIRECTORY = 78
PROBE_TIMEOUT = 0.4
MAX_PROBE_REPLY = 4096
ROUTE_CACHE_TTL = 5
MAX_CACHED_ROUTES = 1024
NOTIFY_TOKEN = b""
route_cache = {}
route_cache_lock = threading.Lock()


def load_token():
    token = os.environ.get("MULTIPROMP_NOTIFY_RELAY_TOKEN")
    if not token:
        token = subprocess.run([str(Path.home() / ".local/bin/yeo-key"), "Multiprompt Notify Relay Token", "MULTIPROMP_NOTIFY_RELAY_TOKEN"], check=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True).stdout.rstrip("\n")
    if not token:
        raise ValueError("Notify relay token unavailable")
    return token.encode("utf-8")


def socket_dir():
    return Path(f"/tmp/mp-notify-{os.getuid()}")


def sockets(directory):
    found = []
    try:
        for path in directory.iterdir():
            try:
                info = path.lstat()
                if path.suffix == ".sock" and stat.S_ISSOCK(info.st_mode):
                    found.append((info.st_mtime_ns, path))
            except OSError:
                continue
    except OSError:
        pass
    return [path for _, path in sorted(found, reverse=True)]


def connect(path, deadline):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        return None
    conn = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        conn.settimeout(min(0.2, remaining))
        conn.connect(str(path))
        return conn
    except OSError as error:
        conn.close()
        if error.errno in (errno.ECONNREFUSED, errno.ENOENT) and not listening(path):
            try:
                path.unlink()
            except OSError:
                pass
        return None


def listening(path):
    try:
        with open("/proc/net/unix", encoding="utf-8", errors="replace") as table:
            return any(len(row) > 7 and row[7] == str(path) and int(row[3], 16) & 0x10000 for row in (line.split() for line in table))
    except OSError:
        return False


def read_message(conn):
    conn.settimeout(0.2)
    data = bytearray()
    wire_size = MAX_MESSAGE + len(NOTIFY_TOKEN) + len(b"AUTH::")
    try:
        while len(data) < wire_size:
            chunk = conn.recv(min(4096, wire_size - len(data)))
            if not chunk:
                break
            data.extend(chunk)
            if b"\n" in chunk:
                break
    except (OSError, TimeoutError):
        pass
    return bytes(data)


def proxy(client, upstream):
    client.settimeout(None)
    upstream.settimeout(None)
    deadline = time.monotonic() + 90
    while time.monotonic() < deadline:
        readable, _, _ = select.select([client, upstream], [], [], max(0, deadline - time.monotonic()))
        if not readable:
            break
        for source in readable:
            data = source.recv(65536)
            if not data:
                return
            (upstream if source is client else client).sendall(data)


def probe(path, session, deadline):
    conn = connect(path, deadline)
    if conn is None:
        return None
    try:
        with conn:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return None
            conn.settimeout(remaining)
            conn.sendall(b"ZSBWHO:" + session.hex().encode("ascii") + b"\n")
            data = bytearray()
            while len(data) < MAX_PROBE_REPLY:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    return None
                conn.settimeout(remaining)
                chunk = conn.recv(MAX_PROBE_REPLY - len(data))
                if not chunk:
                    return None
                data.extend(chunk)
                if b"\n" in data:
                    reply = json.loads(bytes(data).split(b"\n", 1)[0])
                    if (isinstance(reply, dict)
                            and type(reply.get("has_tab")) is bool
                            and type(reply.get("idle_ms")) is int
                            and reply["idle_ms"] >= 0
                            and isinstance(reply.get("host"), str)):
                        return reply
                    return None
    except (OSError, ValueError):
        pass
    return None


def rank_sockets(paths, replies):
    def rank(item):
        _, reply = item
        if reply is None:
            return (1, 0)
        return (0 if reply["has_tab"] else 2, reply["idle_ms"])

    return [path for path, _ in sorted(zip(paths, replies), key=rank)]


def zsb_sockets(paths, session):
    if len(paths) <= 1:
        return paths
    now = time.monotonic()
    inventory = tuple(paths)
    with route_cache_lock:
        for key, (expires, _, _) in list(route_cache.items()):
            if expires <= now:
                del route_cache[key]
        cached = route_cache.get(session)
        if cached is not None and cached[1] == inventory:
            return list(cached[2])
    deadline = now + PROBE_TIMEOUT
    with ThreadPoolExecutor(max_workers=len(paths)) as workers:
        replies = list(workers.map(lambda path: probe(path, session, deadline), paths))
    ranked = rank_sockets(paths, replies)
    with route_cache_lock:
        if session not in route_cache and len(route_cache) >= MAX_CACHED_ROUTES:
            del route_cache[min(route_cache, key=lambda key: route_cache[key][0])]
        route_cache[session] = (now + ROUTE_CACHE_TTL, inventory, tuple(ranked))
    return ranked


def handle(client, directory):
    try:
        with client:
            message = read_message(client)
            if not message:
                return
            prefix, separator, authenticated = message.partition(b":")
            token, separator, message = authenticated.partition(b":")
            if (prefix != b"AUTH" or not separator or not NOTIFY_TOKEN
                    or not hmac.compare_digest(token, NOTIFY_TOKEN)):
                return
            paths = sockets(directory)
            if message.startswith(b"ZSB:"):
                session = message.split(b":", 2)[1]
                paths = zsb_sockets(paths, session)
            deadline = time.monotonic() + 0.8
            for path in paths:
                upstream = connect(path, deadline)
                if upstream is None:
                    continue
                with upstream:
                    if message.startswith(b"ZSB:"):
                        upstream.sendall(message)
                        proxy(client, upstream)
                        return
                    upstream.sendall(message)
    except OSError:
        pass


def sweep(directory):
    for path in sockets(directory):
        conn = connect(path, time.monotonic() + 0.2)
        if conn is not None:
            conn.close()


def prepare_directory(directory):
    try:
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        info = directory.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
            raise PermissionError("directory is not owned by this user")
        if stat.S_IMODE(info.st_mode) != 0o700:
            directory.chmod(0o700)
            if stat.S_IMODE(directory.lstat().st_mode) != 0o700:
                raise PermissionError("directory must have mode 700")
    except OSError as error:
        print(f"Unsafe notification socket directory {directory}: {error}", file=sys.stderr)
        return False
    return True


def serve(directory=None, port=PORT, stop=None):
    directory = socket_dir() if directory is None else Path(directory)
    if not prepare_directory(directory):
        return UNSAFE_DIRECTORY
    next_sweep = time.monotonic()
    while stop is None or not stop.is_set():
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server:
                server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                server.bind(("127.0.0.1", port))
                server.listen()
                server.settimeout(0.5)
                while stop is None or not stop.is_set():
                    if time.monotonic() >= next_sweep:
                        sweep(directory)
                        next_sweep = time.monotonic() + SWEEP_INTERVAL
                    try:
                        client, _ = server.accept()
                    except socket.timeout:
                        continue
                    threading.Thread(target=handle, args=(client, directory), daemon=True).start()
        except OSError:
            if time.monotonic() >= next_sweep:
                sweep(directory)
                next_sweep = time.monotonic() + SWEEP_INTERVAL
            if stop is None:
                time.sleep(5)
            else:
                stop.wait(5)
    return 0


if __name__ == "__main__":
    from tmux_notify import start_sender

    directory = socket_dir()
    if not prepare_directory(directory):
        sys.exit(UNSAFE_DIRECTORY)
    try:
        NOTIFY_TOKEN = load_token()
    except (OSError, subprocess.SubprocessError, ValueError):
        print("Notify relay token unavailable", file=sys.stderr)
        sys.exit(UNSAFE_DIRECTORY)
    try:
        start_sender(directory)
    except OSError as error:
        print(f"Unsafe tmux notification FIFO: {error}", file=sys.stderr)
        sys.exit(UNSAFE_DIRECTORY)
    sys.exit(serve(directory))
