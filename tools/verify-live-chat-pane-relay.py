import argparse
import concurrent.futures
import json
import pathlib
import socket

parser = argparse.ArgumentParser()
parser.add_argument('--app-port', type=int, required=True)
parser.add_argument('--ready', required=True)
args = parser.parse_args()
prefix = b'AUTH:live-chat-pane-fixture:ZSB:'


def forward(client):
    with client:
        client.settimeout(180)
        wire = bytearray()
        while not wire.endswith(b'\n'):
            chunk = client.recv(65536)
            if not chunk or len(wire) + len(chunk) > 65536:
                return
            wire.extend(chunk)
        if not wire.startswith(prefix):
            client.sendall(b'{"ok":false,"error":"invalid_fixture_auth"}\n')
            return
        with socket.create_connection(('127.0.0.1', args.app_port), timeout=180) as app:
            app.sendall(b'ZSB:' + wire[len(prefix):])
            while True:
                chunk = app.recv(65536)
                if not chunk:
                    return
                client.sendall(chunk)


with socket.socket() as listener, concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    listener.bind(('127.0.0.1', 0))
    listener.listen(4)
    ready = json.dumps({'port': listener.getsockname()[1]})
    pending = pathlib.Path(args.ready + '.tmp')
    pending.write_text(ready)
    pending.replace(args.ready)
    print(ready, flush=True)
    while True:
        client, _ = listener.accept()
        pool.submit(forward, client)
