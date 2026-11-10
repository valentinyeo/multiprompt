import base64
import json
import os
import selectors
import signal
import subprocess
import sys

MAX_CHANNELS = 128
MAX_FRAME = 32 * 1024 * 1024
MAX_INPUT = 2 * 1024 * 1024
TERMINAL_SOURCE = globals().get("TERMINAL_SOURCE", "")


def serve(source):
    channels = {}
    selector = selectors.DefaultSelector()
    selector.register(sys.stdin.buffer, selectors.EVENT_READ, (None, "input"))
    incoming = bytearray()

    def emit(value):
        sys.stdout.write(json.dumps(value, separators=(",", ":")) + "\n")
        sys.stdout.flush()

    def close(cid):
        item = channels.pop(cid, None)
        if item is None:
            return
        child = item["child"]
        for pipe in (child.stdout, child.stdin):
            try:
                selector.unregister(pipe)
            except KeyError:
                pass
            pipe.close()
        try:
            os.killpg(child.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            child.wait(timeout=1)
        except subprocess.TimeoutExpired:
            os.killpg(child.pid, signal.SIGKILL)
            child.wait()

    emit(dict(ready=True))
    try:
        while True:
            for key, mask in selector.select():
                cid, kind = key.data
                if kind == "input":
                    chunk = os.read(sys.stdin.fileno(), 65536)
                    if not chunk:
                        return
                    incoming.extend(chunk)
                    if len(incoming) > MAX_INPUT:
                        return
                    while b"\n" in incoming:
                        line, _, rest = incoming.partition(b"\n")
                        incoming[:] = rest
                        packet = json.loads(line)
                        cid = packet["channel"]
                        if type(cid) is not int or cid < 1:
                            return
                        if packet.get("close"):
                            close(cid)
                            continue
                        if cid not in channels:
                            if not packet.get("open", True):
                                emit(dict(channel=cid, closed=True))
                                continue
                            if len(channels) >= MAX_CHANNELS:
                                emit(dict(channel=cid, closed=True))
                                continue
                            command = packet.get("command")
                            if command:
                                try:
                                    child = subprocess.Popen(["/bin/sh", "-c", command], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, start_new_session=True)
                                except OSError:
                                    emit(dict(channel=cid, closed=True))
                                    continue
                                opening = bytearray()
                            else:
                                mode = "--terminal" if packet.get("terminal") else "--watch" if packet.get("watch") else "--serve"
                                worker_source = base64.b64decode(TERMINAL_SOURCE) if packet.get("terminal") else source.encode()
                                bootstrap = "import base64,sys;s=base64.b64decode(sys.stdin.buffer.readline()).decode();exec(compile(s,'<reader>','exec'),dict(__name__='__main__',READER_SOURCE=s))"
                                child = subprocess.Popen([sys.executable, "-u", "-c", bootstrap, mode], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, start_new_session=True)
                                opening = bytearray(base64.b64encode(worker_source) + b"\n")
                            os.set_blocking(child.stdin.fileno(), False)
                            os.set_blocking(child.stdout.fileno(), False)
                            channels[cid] = dict(child=child, incoming=bytearray(), outgoing=opening, errors="replace" if command else "strict")
                            selector.register(child.stdout, selectors.EVENT_READ, (cid, "output"))
                            selector.register(child.stdin, selectors.EVENT_WRITE, (cid, "write"))
                        item = channels[cid]
                        data = packet.get("data")
                        if not isinstance(data, str):
                            close(cid)
                            emit(dict(channel=cid, closed=True))
                            continue
                        item["outgoing"].extend(data.encode() + b"\n")
                        if len(item["outgoing"]) > MAX_INPUT:
                            close(cid)
                            emit(dict(channel=cid, closed=True))
                            continue
                        try:
                            selector.modify(item["child"].stdin, selectors.EVENT_WRITE, (cid, "write"))
                        except KeyError:
                            selector.register(item["child"].stdin, selectors.EVENT_WRITE, (cid, "write"))
                elif cid in channels:
                    item = channels[cid]
                    try:
                        if kind == "write":
                            count = os.write(key.fd, item["outgoing"])
                            del item["outgoing"][:count]
                            if not item["outgoing"]:
                                selector.unregister(key.fileobj)
                        else:
                            chunk = os.read(key.fd, 65536)
                            if not chunk:
                                close(cid)
                                emit(dict(channel=cid, closed=True))
                                continue
                            item["incoming"].extend(chunk)
                            if len(item["incoming"]) > MAX_FRAME:
                                close(cid)
                                emit(dict(channel=cid, closed=True))
                                continue
                            while b"\n" in item["incoming"]:
                                line, _, rest = item["incoming"].partition(b"\n")
                                item["incoming"][:] = rest
                                emit(dict(channel=cid, data=line.decode(errors=item["errors"])))
                    except (OSError, UnicodeError):
                        close(cid)
                        emit(dict(channel=cid, closed=True))
    finally:
        for cid in list(channels):
            close(cid)
        selector.close()


if __name__ == "__main__":
    for name in ("SIGHUP", "SIGTERM"):
        event = getattr(signal, name, None)
        if event is not None:
            signal.signal(event, lambda *_: sys.exit(0))
    serve(base64.b64decode(sys.stdin.buffer.readline()).decode())
