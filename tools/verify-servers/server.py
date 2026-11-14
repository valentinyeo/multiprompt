import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import threading

import paramiko


root = Path(sys.argv[1]).resolve()
bash = sys.argv[2]
root.mkdir(parents=True, exist_ok=True)
host_key = paramiko.RSAKey.generate(2048)
log_lock = threading.Lock()


def record(event, **values):
    with log_lock, (root / "events.jsonl").open("a", encoding="utf-8") as stream:
        stream.write(json.dumps({"event": event, **values}) + "\n")


class Server(paramiko.ServerInterface):
    def __init__(self):
        self.ready = threading.Event()
        self.command = None

    def get_allowed_auths(self, username):
        return "publickey"

    def check_auth_publickey(self, username, key):
        authorized = root / ".ssh" / "authorized_keys"
        rows = authorized.read_text(encoding="utf-8").splitlines() if authorized.exists() else []
        allowed = username == "verify" and any(
            len(fields := row.split()) >= 2
            and fields[:2] == [key.get_name(), key.get_base64()]
            for row in rows
        )
        record("authentication", allowed=allowed)
        return paramiko.AUTH_SUCCESSFUL if allowed else paramiko.AUTH_FAILED

    def check_channel_request(self, kind, channel_id):
        return paramiko.OPEN_SUCCEEDED if kind == "session" else paramiko.OPEN_FAILED_ADMINISTRATIVELY_PROHIBITED

    def check_channel_exec_request(self, channel, command):
        text = command.decode("utf-8")
        if text != "true" and not text.startswith("umask 077 && if [ -f ~/.ssh/authorized_keys ]; then "):
            record("unexpected-command")
            return False
        self.command = text
        self.ready.set()
        return True


def connection(client):
    transport = paramiko.Transport(client)
    try:
        server = Server()
        transport.add_server_key(host_key)
        transport.start_server(server=server)
        channel = transport.accept(15)
        if channel is None or not server.ready.wait(15):
            return
        environment = dict(os.environ, HOME=root.as_posix())
        result = subprocess.run(
            [bash, "--noprofile", "--norc", "-c", server.command],
            cwd=root, env=environment, capture_output=True, timeout=15,
        )
        record("command", kind="probe" if server.command == "true" else "remove", exit=result.returncode)
        if result.stdout:
            channel.sendall(result.stdout)
        if result.stderr:
            channel.sendall_stderr(result.stderr)
        channel.send_exit_status(result.returncode)
        channel.shutdown_write()
        channel.close()
        transport.join(10)
    except (paramiko.SSHException, EOFError, OSError):
        record("connection-closed")
    finally:
        transport.close()


with socket.socket() as listener:
    listener.bind(("127.0.0.1", 0))
    listener.listen(8)
    (root / "port.txt").write_text(str(listener.getsockname()[1]), encoding="ascii")
    while True:
        client, _ = listener.accept()
        threading.Thread(target=connection, args=(client,), daemon=True).start()
