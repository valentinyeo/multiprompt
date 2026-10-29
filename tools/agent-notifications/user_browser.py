import base64
import json
import os
from pathlib import Path
import pwd
import re
import socket
import stat
import struct
import subprocess
import threading
import time

PANE_COMMANDS = frozenset((
    "open", "navigate", "status", "pane-info", "tabs", "url", "active-tab",
    "text", "get-text", "snapshot", "links", "frames", "find", "click", "type",
    "insert", "key", "back", "forward", "reload", "screenshot", "console",
    "activate", "close-tab", "tab", "eval", "script", "emulate",
))


def owners(uid, session):
    user = pwd.getpwuid(uid).pw_name
    result = subprocess.run([
        "tmux", "list-panes", "-a", "-F",
        "#{session_name}\t#{@owner_user}\t#{@owner_session}",
    ], check=True, capture_output=True, text=True)
    return {outer for row in result.stdout.splitlines()
            if len(parts := row.split("\t")) == 3
            for outer, owner, inner in [parts]
            if owner == user and inner == session}


def request(path, session, payload, relay):
    upstream = relay.connect(path, time.monotonic() + 0.8)
    if upstream is None:
        raise OSError("Browser tunnel unavailable")
    with upstream:
        upstream.settimeout(90)
        upstream.sendall(b"ZSB:" + session + b":" + payload + b"\n")
        chunks = []
        size = 0
        while chunk := upstream.recv(65536):
            size += len(chunk)
            if size > 16 * 1024 * 1024:
                raise ValueError("Browser reply exceeded transport limit")
            chunks.append(chunk)
        return b"".join(chunks)


def resolve_tab(layout, host, outer):
    if layout.get("ok") is not True:
        raise ValueError("Browser layout unavailable")
    tabs = []
    for workspace in layout["workspaces"]:
        tabs.extend(workspace.get("tabs", []))
        for group in workspace["groups"]:
            tabs.extend(group["tabs"])
    matches = [tab for tab in tabs if tab.get("host") == host and tab.get("tmux") in outer]
    if len(matches) != 1:
        raise ValueError("Owner session has no unambiguous desktop tab")
    key = "zss-" + str(matches[0]["id"])
    if any((tab.get("tmux") or "").lower() == key
           or re.match(re.escape(key) + r"(?:$|[: \-|·•])", tab.get("title", ""), re.I)
           for tab in tabs):
        raise ValueError("Desktop tab identity conflicts with a session name")
    return key.encode()


def handle(client, directory, host, relay):
    with client:
        try:
            _, uid, _ = struct.unpack("3i", client.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i")))
            wire = relay.read_message(client)
            prefix, session, payload = wire.rstrip(b"\n").split(b":", 2)
            if prefix != b"ZSB" or not re.fullmatch(rb"[A-Za-z0-9_.-]+", session):
                raise ValueError("Invalid browser session")
            raw = base64.b64decode(payload, validate=True).decode()
            args = raw.rstrip("\x1f").split("\x1f")
            if args[0] not in PANE_COMMANDS or any(arg in ("--profile", "--window", "--window-id") for arg in args):
                raise ValueError("Only this user's pane commands are allowed")
            if args[0] in ("open", "navigate") and len(args) > 1:
                if not args[1].startswith(("https://", "http://", "about:blank", "data:text/html")):
                    raise ValueError("Only web pages may open through the owner channel")
            outer = owners(uid, session.decode())
            if not outer:
                raise ValueError("Session does not belong to this Unix user")
            inventory = base64.b64encode(b"workspace-list\x1f")
            targets = []
            for path in relay.sockets(directory):
                try:
                    layout = json.loads(request(path, b"workspace", inventory, relay))
                    targets.append((path, resolve_tab(layout, host, outer)))
                except (OSError, ValueError, KeyError, TypeError):
                    continue
            if len(targets) != 1:
                raise ValueError("Owner session has no unambiguous connected desktop")
            path, target = targets[0]
            client.sendall(request(path, target, payload, relay))
        except (OSError, ValueError, KeyError, LookupError, subprocess.SubprocessError):
            try:
                client.sendall(b'{"ok":false,"error":"owner_scope_denied","message":"Browser access requires your own session and pane command"}\n')
            except OSError:
                pass


def start(directory, host, relay, root=None):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", host):
        raise ValueError("Invalid configured browser host")
    root = Path(f"/tmp/mp-browser-{os.getuid()}") if root is None else Path(root)
    root.mkdir(mode=0o755, exist_ok=True)
    info = root.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o755:
        raise PermissionError("Unsafe owner browser directory")
    endpoint = root / "control.sock"
    if endpoint.exists() or endpoint.is_symlink():
        info = endpoint.lstat()
        if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid() or relay.listening(endpoint):
            raise PermissionError("Owner browser endpoint is already in use or unsafe")
        endpoint.unlink()
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(str(endpoint))
    endpoint.chmod(0o666)
    server.listen()

    def serve():
        with server:
            while True:
                client, _ = server.accept()
                threading.Thread(target=handle, args=(client, directory, host, relay), daemon=True).start()

    threading.Thread(target=serve, daemon=True).start()
