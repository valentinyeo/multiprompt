"""Slow-network boundary for the slow-network journey.

Two roles, both selected by the first argument:

  ssh <ssh args...>   the stand-in ssh client the app spawns. It connects to the
                      local slow proxy, hands over its ssh argv and relays the
                      app's stdin/stdout over that socket.

  proxy               listens on MP_VERIFY_SLOW_PORT. Every connection is paired
                      with a real boundary process for the host side on the next
                      port, and both directions are delayed by MP_VERIFY_SLOW_MS.
                      The app's remote traffic therefore crosses a real TCP
                      socket with an added one-way delay, while the remote host
                      itself stays the repository's SSH/tmux stand-in.

Nothing here writes app state. The boundary process is the same
tools/verify-chat-delivery/boundary.py the other journeys use.
"""
import json
import os
import socket
import subprocess
import sys
import threading
import time

DELAY = int(os.environ.get('MP_VERIFY_SLOW_MS', '2000')) / 1000.0
PORT = int(os.environ.get('MP_VERIFY_SLOW_PORT', '22391'))
HOST_PORT = PORT + 1
READY = os.environ.get('MP_VERIFY_SLOW_READY', '')
PYTHON = os.environ.get('MP_VERIFY_PYTHON') or sys.executable
REAL = os.environ.get('MP_VERIFY_REAL_BOUNDARY', '')


def read_frame(sock):
    head = b''
    while len(head) < 4:
        chunk = sock.recv(4 - len(head))
        if not chunk:
            return None
        head += chunk
    size = int.from_bytes(head, 'big')
    body = b''
    while len(body) < size:
        chunk = sock.recv(size - len(body))
        if not chunk:
            return None
        body += chunk
    return json.loads(body.decode('utf-8'))


def send_frame(sock, value):
    body = json.dumps(value).encode('utf-8')
    sock.sendall(len(body).to_bytes(4, 'big') + body)


def ssh_client(args):
    sock = socket.create_connection(('127.0.0.1', PORT), timeout=30)
    sock.settimeout(None)
    send_frame(sock, args)

    def upstream():
        try:
            while True:
                data = os.read(0, 65536)
                if not data:
                    break
                sock.sendall(data)
        except OSError:
            pass
        finally:
            try:
                sock.shutdown(socket.SHUT_WR)
            except OSError:
                pass

    thread = threading.Thread(target=upstream, daemon=True)
    thread.start()
    try:
        while True:
            data = sock.recv(65536)
            if not data:
                break
            view = memoryview(data)
            while view:
                wrote = os.write(1, view)
                view = view[wrote:]
    except OSError:
        pass
    thread.join(timeout=5)
    return 0


def pump(src, dst, delay):
    """Relay src to dst, holding every chunk for delay seconds without
    serialising the stream behind the sleep."""
    pending = []
    lock = threading.Lock()
    finished = threading.Event()

    def reader():
        while True:
            try:
                data = src.recv(65536)
            except OSError:
                data = b''
            with lock:
                pending.append((time.monotonic() + delay, data))
            if not data:
                finished.set()
                return

    thread = threading.Thread(target=reader, daemon=True)
    thread.start()
    while True:
        item = None
        with lock:
            if pending:
                item = pending.pop(0)
            exhausted = finished.is_set() and not pending
        if item is None:
            if exhausted:
                break
            time.sleep(0.005)
            continue
        due, data = item
        wait = due - time.monotonic()
        if wait > 0:
            time.sleep(wait)
        if not data:
            try:
                dst.shutdown(socket.SHUT_WR)
            except OSError:
                pass
            break
        view = memoryview(data)
        try:
            while view:
                wrote = dst.send(view)
                view = view[wrote:]
        except OSError:
            break
    thread.join(timeout=5)


def serve_host(conn):
    with conn:
        args = read_frame(conn)
        if args is None:
            return
        proc = subprocess.Popen(
            [PYTHON, '-u', REAL, 'ssh', *args],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=None,
            bufsize=0,
        )

        def upstream():
            try:
                while True:
                    data = conn.recv(65536)
                    if not data:
                        break
                    proc.stdin.write(data)
                    proc.stdin.flush()
            except OSError:
                pass
            finally:
                try:
                    proc.stdin.close()
                except OSError:
                    pass

        def downstream():
            try:
                while True:
                    data = os.read(proc.stdout.fileno(), 65536)
                    if not data:
                        break
                    conn.sendall(data)
            except OSError:
                pass
            finally:
                try:
                    conn.shutdown(socket.SHUT_WR)
                except OSError:
                    pass

        up = threading.Thread(target=upstream, daemon=True)
        down = threading.Thread(target=downstream, daemon=True)
        up.start()
        down.start()
        down.join()
        up.join(timeout=5)
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()


def serve_proxy(conn):
    with conn:
        host = socket.create_connection(('127.0.0.1', HOST_PORT), timeout=30)
        with host:
            first = threading.Thread(target=pump, args=(conn, host, DELAY), daemon=True)
            first.start()
            pump(host, conn, DELAY)
            first.join(timeout=10)


def listen(port, handler):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('127.0.0.1', port))
    server.listen(128)

    def accept_loop():
        while True:
            try:
                conn, _ = server.accept()
            except OSError:
                return
            threading.Thread(target=handler, args=(conn,), daemon=True).start()

    threading.Thread(target=accept_loop, daemon=True).start()
    return server


def proxy():
    if not REAL:
        raise SystemExit('MP_VERIFY_REAL_BOUNDARY is required')
    listen(HOST_PORT, serve_host)
    listen(PORT, serve_proxy)
    if READY:
        with open(READY, 'w', encoding='utf-8') as handle:
            handle.write(str(PORT))
    threading.Event().wait()
    return 0


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise SystemExit('usage: slow-network.py ssh <args...> | proxy')
    if sys.argv[1] == 'ssh':
        sys.exit(ssh_client(sys.argv[2:]))
    if sys.argv[1] == 'proxy':
        sys.exit(proxy())
    raise SystemExit(f'unknown role {sys.argv[1]}')
