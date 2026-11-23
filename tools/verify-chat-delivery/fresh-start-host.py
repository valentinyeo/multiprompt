import hashlib
import json
import threading
import time
from pathlib import Path

HANDOVER = "Finish the saved draft. Keep the same board login."
REPLIES = ("First fresh-start probe reply.", "Second fresh-start probe reply.",
           "Still the same chat, keeping the saved handover.")


def install(namespace, root, record):
    root = Path(root)
    seed = json.loads((root / "state.json").read_text(encoding="utf-8-sig"))
    tmux = "verify-fresh-start"
    sid = seed["sids"][tmux]
    provider = "claude"
    sent = {"count": 0}
    previous_deliver = namespace["host_deliver"]
    previous_switch = namespace["host_dispatch_switch"]
    previous_owned = namespace["host_owned"]
    previous_handle = namespace["host_handle_request"]
    previous_push = namespace["events_push"]

    def matches(p, s):
        return p == provider and s == sid

    def dispatch_switch(p, s):
        return matches(p, s) or previous_switch(p, s)

    def owned(p, s):
        return matches(p, s) or previous_owned(p, s)

    def deliver(p, s, token, attempt, epoch, text):
        if not matches(p, s):
            return previous_deliver(p, s, token, attempt, epoch, text)
        record("fresh-start-host.jsonl", stage="deliver", sid=s, id=token, text=text)
        reply = REPLIES[sent["count"]] if sent["count"] < len(REPLIES) else "Extra reply."
        sent["count"] += 1
        session = {"turn": token, "state": {}, "sends": [dict(id=token, attempt=attempt, accepted=False)]}
        namespace["host_event"](p, s, tmux, session, "turn.started",
                                dict(message_id=token, text_sha256=hashlib.sha256(text.encode()).hexdigest(), uuids=[]))
        namespace["host_accept"](p, s, tmux, session, dict(type="standin-accepted"), token)
        namespace["host_event"](p, s, tmux, session, "text.delta", dict(text=reply, done=False), "fresh-reply")
        namespace["host_event"](p, s, tmux, session, "text.done", dict(text=reply, done=True), "fresh-reply")
        namespace["host_event"](p, s, tmux, session, "turn.ended", dict(status="completed"))
        record("fresh-start-host.jsonl", stage="replied", sid=s, id=token, text=reply)
        if session.get("db") is not None:
            session["db"].close()
        return {"status": "sent"}

    def handle(p, s, t, session, request):
        if matches(p, s) and request.get("op") == "fresh_start":
            record("fresh-start-host.jsonl", stage="fresh_start_requested", sid=s)
        reply = previous_handle(p, s, t, session, request)
        if matches(p, s) and request.get("op") == "fresh_start" and reply.get("status") == "started":
            threading.Thread(target=lambda: automate_fresh(p, s, t, session), daemon=True).start()
        return reply

    def automate_fresh(p, s, t, session):
        record("fresh-start-host.jsonl", stage="automation_started", sid=s)
        saved = False
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            state = namespace["host_session_state"](p, s)
            fresh = state.get("fresh_start")
            if isinstance(fresh, dict) and fresh.get("phase") == "reset" and fresh.get("file") and not saved:
                path = namespace["host_paths"](p, s)["root"] / fresh["file"]
                body = namespace["host_read"](path)
                record("fresh-start-host.jsonl", stage="handover_saved", sid=s, file=fresh["file"],
                         text=(body or {}).get("text", ""))
                saved = True
            if "fresh_start" not in state and (state.get("native_session") or state.get("context_session")):
                record("fresh-start-host.jsonl", stage="completed", sid=s,
                        native_session=state.get("native_session") or state.get("context_session"))
                break
            time.sleep(0.1)

    def push(subscriptions):
        pages = [(sub, namespace["message_events_page"](sub["provider"], sub["sid"], sub["after"]))
                 for sub in subscriptions.values() if sub["sid"] == sid]
        previous_push(subscriptions)
        for sub, page in pages:
            if page["events"]:
                record("fresh-start-host.jsonl", stage="pushed", sid=sub["sid"], events=page["events"])
                for row in page["events"]:
                    event = row.get("event", {})
                    payload = event.get("payload") or {}
                    if event.get("kind") == "text.done" and HANDOVER in (payload.get("text") or ""):
                        record("fresh-start-host.jsonl", stage="handover_visible", sid=sub["sid"], text=payload.get("text"))

    namespace["host_deliver"] = deliver
    namespace["host_dispatch_switch"] = dispatch_switch
    namespace["host_owned"] = owned
    namespace["host_handle_request"] = handle
    namespace["events_push"] = push
    record("fresh-start-host.jsonl", stage="installed", sid=sid, tmux=tmux, handover=HANDOVER)