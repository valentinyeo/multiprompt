import datetime
import os
import time
import uuid


PING_TEXT = "mp-sessions health ping"


def _label(row, send):
    return row.get("link") or row.get("name") or row["tmux"]


def _last_reply_time(reader, send, provider, sid, folder, tmux):
    chat = dict(provider=provider, sid=sid, cwd=folder or "")
    path = send.transcript_path(reader, chat)
    if path is None or not path.is_file():
        return None
    stamp = path.stat().st_mtime
    for raw in reversed(send.tail_lines(path, limit=65536)):
        try:
            event = __import__("json").loads(raw)
        except (ValueError, UnicodeError):
            continue
        row = reader.conversation_event(event, provider)
        if row and row.get("role") == "assistant":
            text = row.get("text") or ""
            if text.strip():
                ts = event.get("timestamp")
                if isinstance(ts, str):
                    try:
                        stamp = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp()
                    except ValueError:
                        pass
                break
    return datetime.datetime.fromtimestamp(stamp, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _desktop_tab(send, listing, tmux):
    if listing.get("ok") is not True:
        return None, "UNKNOWN desktop offline"
    tab = send.find_tab(listing, tmux)[2]
    if tab is None:
        return None, None
    cv = tab.get("cv")
    if cv is False:
        return tab, "shell tab"
    return tab, None


def _desktop_view(reader, listing, provider, sid, tmux, folder):
    if listing.get("ok") is not True:
        return "UNKNOWN desktop offline"
    try:
        q = dict(id=0, provider=provider, sid=sid, tmux=tmux, cwd=folder or os.getcwd())
        q = reader.pin_hosted_claude(q, provider)
        resolved = reader.resolve_response_path(q)
    except (OSError, ValueError, TypeError, AttributeError):
        return "history unreadable"
    path = resolved[2]
    delegated = resolved[3]
    if path is not None:
        return None
    if delegated is None:
        return "history unreadable"
    empty = reader.empty_history_response(q, resolved[1], tmux, provider)
    return None if delegated == empty else "history unreadable"


def _conversation_match(reader, provider, sid, tmux, folder):
    if not sid or not tmux:
        return "no session id"
    try:
        state = reader.host_session_state(provider, sid)
    except (OSError, ValueError, TypeError, AttributeError):
        state = {}
    registered = state.get("native_session") or sid
    try:
        bound = reader.resolve_tmux_agent(provider, tmux, require_bound=True)
    except (OSError, ValueError, TypeError, AttributeError, PermissionError):
        bound = None
    if bound is None:
        return "agent not bound"
    active_sid, path = bound
    try:
        expected = reader.conversation_path(provider, registered, folder or reader.host_cwd(provider, sid))
    except (OSError, ValueError, TypeError, AttributeError, PermissionError):
        expected = None
    if expected is not None and path.resolve() != expected.resolve():
        return "conversation mismatch"
    if active_sid != registered and active_sid != sid:
        return "conversation mismatch"
    return None


def _ping(send, row):
    token = "mp-health-" + uuid.uuid4().hex[:16]
    reader = send.reader_module()
    provider, sid, tmux = row["provider"], row["sid"], row["tmux"]
    try:
        send.check_rate(reader, provider, sid, None)
    except send.RateLimited:
        return "rate limited"
    message = send.submit(reader, provider, sid, tmux, PING_TEXT, token)
    send.dispatch(reader, provider, sid, tmux)
    final = send.handoff(reader, provider, sid, tmux, message.get("id"), 15.0)
    state = (final or {}).get("state")
    if state in ("failed", "cancelled") or state not in send.HANDOFF_STATES:
        return "ping failed"
    return None


def evaluate_row(send, listing, row, ping):
    label = _label(row, send)
    provider = row.get("provider") or "claude"
    sid = row.get("sid")
    tmux = row["tmux"]
    folder = row.get("folder")
    reader = send.reader_module()
    reasons = []
    if row.get("visible") is False and not (row.get("waiting") or row.get("archived") or row.get("closed") or row.get("user_hidden")):
        reasons.append("hidden: " + str(row.get("hidden_reason") or "not in sidebar layout"))
    tab_note = None
    view_note = None
    if not row.get("running"):
        reasons.append("host not running")
    elif sid:
        mismatch = _conversation_match(reader, provider, sid, tmux, folder)
        if mismatch:
            reasons.append(mismatch)
    else:
        reasons.append("no session id")
    if row.get("tab_open") or (row.get("running") and sid):
        _, tab_reason = _desktop_tab(send, listing, tmux)
        if tab_reason:
            tab_note = tab_reason
            if tab_reason == "shell tab" or tab_reason == "UNKNOWN desktop offline":
                reasons.append(tab_reason)
        view_reason = _desktop_view(reader, listing, provider, sid, tmux, folder)
        if view_reason:
            view_note = view_reason
            if view_reason != "UNKNOWN desktop offline":
                reasons.append(view_reason)
            elif not reasons:
                reasons.append(view_reason)
    last_reply = None
    if sid and provider not in ("hax", "cursor"):
        try:
            last_reply = _last_reply_time(reader, send, provider, sid, folder, tmux)
        except (OSError, ValueError, TypeError, AttributeError):
            last_reply = None
    if ping and not reasons and row.get("running"):
        ping_reason = _ping(send, row)
        if ping_reason:
            reasons.append(ping_reason)
    status = "OK" if not reasons else "BROKEN " + reasons[0]
    return dict(
        row,
        name=row.get("name"),
        link=label,
        tmux=tmux,
        sid=sid,
        provider=provider,
        status=status,
        reasons=reasons,
        last_reply=last_reply,
        tab=tab_note or "ok",
        view=view_note or "ok",
        ping=PING_TEXT if ping and not reasons else None,
    )


def health_report(send, listing, rows, ping, as_json):
    results = [evaluate_row(send, listing, row, ping) for row in rows]
    broken = any(row["status"] != "OK" for row in results)
    if as_json:
        import json
        print(json.dumps(results, separators=(",", ":")))
    else:
        for row in results:
            print(row["link"] + " " + row["status"])
    return 1 if broken else 0