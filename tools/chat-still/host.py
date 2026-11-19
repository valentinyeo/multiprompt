import datetime
import json
import os
import pathlib
import threading
import time
import uuid


def install(namespace, root, record):
    seed = json.loads((root / "state.json").read_text(encoding="utf-8-sig"))
    name = seed["sessions"][1]
    sid = seed["sids"][name]
    transcript = pathlib.Path(seed["home"]) / ".claude/projects/C--verify-work1" / (sid + ".jsonl")
    original_request = namespace["serve_request"]
    original_print = namespace["serve_print"]

    def stream():
        session = {"turn": "still-turn", "state": {}}
        identity = "msg_still_" + uuid.uuid4().hex
        chunks = []
        try:
            deadline = time.monotonic() + 45
            while not (root / "still-stream-start").exists():
                if time.monotonic() >= deadline:
                    raise TimeoutError("No streaming observation started")
                time.sleep(0.01)
            namespace["host_event"]("claude", sid, name, session, "turn.started")
            for chunk in range(30):
                text = "Streaming reply " + "more words " * (chunk + 1)
                namespace["host_event"]("claude", sid, name, session, "text.delta", {"text": text, "done": False}, identity + ":text:0")
                chunks.append({"chunk": chunk, "time_ns": time.time_ns()})
                time.sleep(0.1)
            namespace["host_event"]("claude", sid, name, session, "text.done", {"text": text, "done": True}, identity + ":text:0")
            row = {"type": "assistant", "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                   "sessionId": sid, "uuid": identity, "isSidechain": False,
                   "message": {"role": "assistant", "id": identity, "content": [{"type": "text", "text": text}]}}
            with transcript.open("ab") as output:
                output.write(json.dumps(row).encode() + b"\n")
            namespace["host_event"]("claude", sid, name, session, "turn.completed")
            temporary = root / "still-stream-receipt.tmp"
            temporary.write_text(json.dumps({"message": identity, "chunks": chunks, "canonical_time_ns": time.time_ns()}, indent=2))
            temporary.replace(root / "still-stream-receipt.json")
            record("chat-still-host.jsonl", stage="completed", sid=sid)
        except Exception as error:
            record("chat-still-host.jsonl", stage="error", error=repr(error))
        finally:
            if session.get("db") is not None:
                session["db"].close()

    def request(line, source, subscriptions, lock):
        original_request(line, source, subscriptions, lock)
        query = json.loads(line)
        if query.get("op") != "events_subscribe" or query.get("sid") != sid:
            return
        record("chat-still-host.jsonl", stage="subscribed", sid=sid)
        (root / "still-subscribed").touch()
        try:
            handle = os.open(root / "still-host-claimed", os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError:
            return
        os.close(handle)
        threading.Thread(target=stream, daemon=True).start()

    def send(value):
        original_print(value)
        result = value.get("result") if isinstance(value, dict) else None
        if not isinstance(result, dict):
            return
        events = [row for row in result.get("events", []) if row.get("event", {}).get("sid") == sid]
        if events:
            record("chat-still-host.jsonl", stage="pushed", sid=sid, events=events)

    namespace["serve_request"] = request
    namespace["serve_print"] = send
