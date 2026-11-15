#!/usr/bin/env python3
import base64
import importlib.util
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

STEPS = ("start", "reply", "skills", "working-start", "working-end", "stop", "reopen", "name")
PROVIDERS = ("claude", "pi", "cursor", "codex")
PROMPT = "reply with the word PARITY"
HOLD = "HOLD"
PREFIX = "live-parity2463-"
END = "@@MP_END@@"

AGENT = r'''#!/usr/bin/env python3
import json
import os
import sys

sys.stdout.reconfigure(line_buffering=True)
provider = os.environ.get("MULTIBOT_PROVIDER", "")

def emit(value):
    sys.stdout.write(json.dumps(value) + "\n")
    sys.stdout.flush()

def user_text(line):
    message = line.get("message") if isinstance(line.get("message"), dict) else {}
    content = message.get("content") if isinstance(message.get("content"), list) else []
    for block in content:
        if isinstance(block, dict) and isinstance(block.get("text"), str):
            return block["text"]
    return line.get("message") if isinstance(line.get("message"), str) else ""

if provider in ("claude", "cursor"):
    emit({"type": "system", "subtype": "init", "session_id": "parity-native", "uuid": "u0"})
    for raw in sys.stdin:
        try:
            line = json.loads(raw)
        except ValueError:
            continue
        if line.get("type") == "control_request":
            request = line.get("request") if isinstance(line.get("request"), dict) else {}
            emit({"type": "control_response", "response": {"subtype": "success", "request_id": line.get("request_id"), "response": {}}})
            if request.get("subtype") == "interrupt":
                emit({"type": "result", "subtype": "success", "stop_reason": "end_turn", "session_id": "parity-native", "usage": {}})
            continue
        if line.get("type") != "user":
            continue
        if HOLD_MARK in user_text(line):
            continue
        emit({"type": "assistant", "message": {"id": "msg-parity", "role": "assistant", "content": [{"type": "text", "text": "PARITY"}]}, "uuid": "u1"})
        emit({"type": "result", "subtype": "success", "stop_reason": "end_turn", "session_id": "parity-native", "usage": {}})
elif provider == "pi":
    holding = False
    for raw in sys.stdin:
        try:
            line = json.loads(raw)
        except ValueError:
            continue
        if line.get("type") == "abort":
            if holding:
                emit({"type": "agent_settled", "aborted": True})
                holding = False
            continue
        if line.get("type") != "prompt":
            continue
        emit({"type": "response", "command": "prompt", "id": line.get("id"), "success": True, "data": {}})
        text = line.get("message") if isinstance(line.get("message"), str) else ""
        if HOLD_MARK in text:
            holding = True
            continue
        emit({"type": "message_start"})
        emit({"type": "message_update", "assistantMessageEvent": {"type": "text_delta", "contentIndex": 0, "delta": "PARITY"}})
        emit({"type": "message_update", "assistantMessageEvent": {"type": "text_end", "contentIndex": 0, "content": "PARITY"}})
        emit({"type": "message_end", "message": {"role": "assistant", "stopReason": "stop"}})
        emit({"type": "agent_settled"})
elif provider == "codex":
    for raw in sys.stdin:
        try:
            line = json.loads(raw)
        except ValueError:
            continue
        method = line.get("method")
        if method == "initialized":
            continue
        if "id" not in line or not method:
            continue
        ident = line["id"]
        if method == "initialize":
            emit({"jsonrpc": "2.0", "id": ident, "result": {}})
            continue
        if method in ("thread/start", "thread/resume"):
            emit({"jsonrpc": "2.0", "id": ident, "result": {"thread": {"id": "parity-thread"}}})
            continue
        if method in ("turn/start", "turn/steer"):
            emit({"jsonrpc": "2.0", "id": ident, "result": {"turn": {"id": "parity-turn"}}})
            text = ""
            for block in (line.get("params") or {}).get("input") or []:
                if isinstance(block, dict) and isinstance(block.get("text"), str):
                    text += block["text"]
            emit({"jsonrpc": "2.0", "method": "turn/started", "params": {"turn": {"id": "parity-turn"}}})
            if HOLD_MARK in text:
                continue
            emit({"jsonrpc": "2.0", "method": "item/completed", "params": {"item": {"id": "parity-item", "type": "agentMessage", "text": "PARITY"}}})
            emit({"jsonrpc": "2.0", "method": "turn/completed", "params": {"turn": {"id": "parity-turn", "status": "completed"}}})
            continue
        if method == "turn/interrupt":
            emit({"jsonrpc": "2.0", "id": ident, "result": {}})
            emit({"jsonrpc": "2.0", "method": "turn/completed", "params": {"turn": {"id": "parity-turn", "status": "interrupted"}}})
            continue
        emit({"jsonrpc": "2.0", "id": ident, "result": {}})
'''.replace("HOLD_MARK", json.dumps(HOLD))


def compare(providers):
    claude = providers.get("claude") if isinstance(providers, dict) else None
    if not isinstance(claude, dict):
        return {"ok": False, "gaps": [{"provider": "claude", "step": "start", "detail": "missing"}]}
    gaps = []
    for name, steps in providers.items():
        if name == "claude" or not isinstance(steps, dict):
            continue
        for step in STEPS:
            left = (claude.get(step) or {}).get("pass") is True
            right = (steps.get(step) or {}).get("pass") is True
            if left and not right:
                gaps.append({"provider": name, "step": step, "detail": (steps.get(step) or {}).get("detail") or "failed"})
    return {"ok": not gaps, "gaps": gaps}


def table(report):
    names = [name for name in PROVIDERS if name in report["providers"]]
    names += [name for name in report["providers"] if name not in names]
    lines = ["| step | " + " | ".join(names) + " |", "| --- | " + " | ".join(["---"] * len(names)) + " |"]
    for step in STEPS:
        cells = ["pass" if (report["providers"][name].get(step) or {}).get("pass") else "fail" for name in names]
        lines.append("| " + step + " | " + " | ".join(cells) + " |")
    if report["gaps"]:
        lines.append("")
        lines.append("Differences:")
        for gap in report["gaps"]:
            lines.append(f"- {gap['provider']} {gap['step']}: {gap['detail']}")
    return "\n".join(lines) + "\n"


def slash_line(provider, session, cwd):
    return f"1\tslash\t{provider}\t{session}\t{cwd}\t"


def catalog_result(text):
    lines = [line for line in (text or "").splitlines() if line and line != END]
    if not lines:
        return False, "empty catalog"
    fields = lines[0].split("\t")
    if len(fields) < 6:
        return False, "bad catalog"
    status = fields[3]
    try:
        count = int(fields[5])
    except ValueError:
        return False, "bad catalog"
    rows = [line for line in lines[1:] if line.split("\t", 1)[0] in ("S", "C", "J", "P", "K", "B")]
    shown = count if count else len(rows)
    if status == "error" or shown < 1:
        return False, "no skills" if status in ("ok", "stale") else (status or "catalog error")
    return True, f"{shown} skills"


def stand_in_catalog(provider, session, cwd):
    if provider not in PROVIDERS or not session.startswith(PREFIX):
        return False, "catalog refused"
    body = "\n".join((f"@mp\t1\tslash\tok\t{cwd}\t1", "S\tparity-skill\t\tParity skill", END, ""))
    return catalog_result(body)


def real_catalog(provider, session, cwd):
    complete = Path.home() / ".local/share/zigshell/mp_complete.py"
    if not complete.is_file():
        return False, "catalog missing"
    encoded = base64.b64encode(slash_line(provider, session, cwd).encode()).decode()
    try:
        result = subprocess.run([sys.executable, str(complete), "--once", encoded], capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return False, "catalog failed"
    return catalog_result(result.stdout)


def load_reader(path):
    spec = importlib.util.spec_from_file_location("mp_parity_reader", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def install_standins(home):
    bindir = Path(home) / "bin"
    bindir.mkdir(mode=0o700)
    agent = bindir / "parity-agent.py"
    agent.write_text(AGENT)
    agent.chmod(0o755)
    for name in ("claude", "pi", "agent", "codex"):
        (bindir / name).symlink_to(agent)
    os.environ["PATH"] = str(bindir) + os.pathsep + os.environ.get("PATH", "")
    os.environ["HOME"] = str(home)
    os.environ["PYTHONDONTWRITEBYTECODE"] = "1"


def blank():
    return {step: {"pass": False, "detail": "not run"} for step in STEPS}


def clip(text, home):
    value = " ".join(str(text).split())
    if home:
        value = value.replace(str(home), "home")
    return value[:180]


def all_events(reader, provider, sid):
    rows = []
    after = 0
    while True:
        page = reader.message_events_page(provider, sid, after)
        batch = page.get("events") if isinstance(page, dict) else None
        if not batch:
            break
        rows.extend(batch)
        nxt = page.get("next_after", after)
        if nxt == after:
            break
        after = nxt
    return rows


def user_texts(reader, provider, sid):
    path = reader.message_store_path()
    if not path.is_file():
        return []
    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        return [row[0] for row in db.execute("SELECT text FROM shared_messages WHERE provider=? AND sid=? ORDER BY position", (provider, sid))]
    finally:
        db.close()


def message_state(reader, provider, sid, tmux, token):
    if not token:
        return None
    page = reader.message_store_request(dict(message_protocol=1, provider=provider, sid=sid, tmux=tmux, op="message_status", message_id=token))
    message = page.get("message") if isinstance(page, dict) else None
    return message.get("state") if isinstance(message, dict) else None


def send_text(reader, provider, sid, name, text, timeout):
    result = reader.host_send(provider, sid, text, name)
    token = result.get("id") if isinstance(result, dict) else None
    deadline = time.time() + timeout
    while isinstance(result, dict) and result.get("state") in (None, "queued") and result.get("status") not in ("refused", "error") and time.time() < deadline:
        time.sleep(0.2)
        reader.message_store_request(dict(message_protocol=1, provider=provider, sid=sid, tmux=name, op="message_dispatch"))
        state = message_state(reader, provider, sid, name, token)
        result = dict(result, state=state, status="queued" if state in (None, "queued") else "sent")
    return result if isinstance(result, dict) else {"status": "error", "reason": "send failed"}


def wait_rows(reader, provider, sid, predicate, timeout):
    deadline = time.time() + timeout
    rows = []
    while time.time() < deadline:
        rows = all_events(reader, provider, sid)
        if predicate(rows):
            return rows
        time.sleep(0.2)
    return all_events(reader, provider, sid)


def event_kind(row):
    event = row.get("event") if isinstance(row, dict) else None
    return event.get("kind") if isinstance(event, dict) else None


def payload_text(row):
    event = row.get("event") if isinstance(row, dict) else None
    payload = event.get("payload") if isinstance(event, dict) else None
    text = payload.get("text") if isinstance(payload, dict) else None
    return text if isinstance(text, str) else ""


def payload_status(row):
    event = row.get("event") if isinstance(row, dict) else None
    payload = event.get("payload") if isinstance(event, dict) else None
    return payload.get("status") if isinstance(payload, dict) else None


def parity_marks(rows):
    started = next((row.get("seq") for row in rows if event_kind(row) == "turn.started"), None)
    text_at = next((row.get("seq") for row in rows if event_kind(row) == "text.done" and "PARITY" in payload_text(row)), None)
    ended = next((row.get("seq") for row in rows if event_kind(row) == "turn.ended" and text_at is not None and row.get("seq", 0) > text_at), None)
    return started, text_at, ended


def interrupt(reader, provider, sid, timeout):
    last = {"status": "error", "reason": "not interrupted"}
    deadline = time.time() + timeout
    while time.time() < deadline:
        last = reader.host_request(provider, sid, {"op": "interrupt"})
        if isinstance(last, dict) and last.get("status") == "ok":
            return last
        time.sleep(0.15)
    return last if isinstance(last, dict) else {"status": "error", "reason": "interrupt failed"}


def error_tail(reader, provider, sid, home):
    path = reader.host_paths(provider, sid)["errors"]
    try:
        text = path.read_text(encoding="utf-8", errors="replace")[-300:]
    except OSError:
        return ""
    return clip(text, home)


def run_provider(reader, provider, cwd, real, catalog, home):
    sid = str(uuid.uuid4())
    name = f"{PREFIX}{provider}-{sid.split('-')[0]}"
    steps = blank()
    session = {"provider": provider, "sid": sid, "name": name}
    reply_wait = 90 if real else 15
    try:
        enable_args = ["enable", provider, sid, "--tmux", name, "--cwd", cwd]
        if provider == "claude":
            enable_args += ["--permission-mode", "bypassPermissions"]
        enabled = reader.host_cli(enable_args)
        if not isinstance(enabled, dict) or enabled.get("status") != "enabled":
            detail = enabled.get("reason") if isinstance(enabled, dict) else "enable failed"
            steps["start"] = {"pass": False, "detail": clip(detail or "enable failed", home)}
        else:
            started = reader.host_cli(["start", provider, sid])
            ok = isinstance(started, dict) and started.get("status") in ("started", "already")
            detail = started.get("reason") or started.get("status") if isinstance(started, dict) else "start failed"
            if not ok:
                tail = error_tail(reader, provider, sid, home)
                if tail:
                    detail = f"{detail}: {tail}"
            steps["start"] = {"pass": ok, "detail": clip(detail or "start failed", home)}
        skills_ok, skills_detail = catalog(provider, name, cwd)
        steps["skills"] = {"pass": skills_ok, "detail": clip(skills_detail, home)}
        if not steps["start"]["pass"]:
            for step in ("reply", "working-start", "working-end", "stop", "reopen"):
                steps[step] = {"pass": False, "detail": "not started"}
            status = reader.host_cli(["status", provider, sid])
            steps["name"] = {"pass": isinstance(status, dict) and status.get("tmux") == name, "detail": "shown" if isinstance(status, dict) and status.get("tmux") == name else "missing"}
            return session, steps
        sent = send_text(reader, provider, sid, name, PROMPT, 15 if real else 8)
        if sent.get("status") in ("refused", "error") or sent.get("state") in (None, "queued", "failed"):
            detail = sent.get("reason") or sent.get("state") or sent.get("status") or "send failed"
            steps["reply"] = {"pass": False, "detail": clip(detail, home)}
            for step in ("working-start", "working-end", "stop", "reopen"):
                steps[step] = {"pass": False, "detail": "no reply"}
        else:
            rows = wait_rows(reader, provider, sid, lambda found: parity_marks(found)[2] is not None, reply_wait)
            started_at, text_at, ended_at = parity_marks(rows)
            steps["working-start"] = {"pass": started_at is not None and (text_at is None or started_at < text_at), "detail": "started" if started_at is not None else "no working start"}
            steps["reply"] = {"pass": text_at is not None, "detail": "PARITY" if text_at is not None else "reply missing"}
            steps["working-end"] = {"pass": ended_at is not None, "detail": "ended" if ended_at is not None else "no working end"}
            if text_at is None:
                steps["stop"] = {"pass": False, "detail": "no reply"}
                steps["reopen"] = {"pass": False, "detail": "no reply"}
            else:
                before = max(row.get("seq", 0) for row in rows)
                held = send_text(reader, provider, sid, name, HOLD, 15 if real else 8)
                hold_id = held.get("id")
                def hold_started(found):
                    return any(event_kind(row) == "turn.started" and row.get("seq", 0) > before for row in found)
                held_rows = wait_rows(reader, provider, sid, hold_started, 20 if real else 8)
                if not hold_started(held_rows):
                    steps["stop"] = {"pass": False, "detail": clip(held.get("reason") or held.get("state") or "stop did not start", home)}
                else:
                    if provider in ("pi", "codex"):
                        deadline = time.time() + 8
                        while message_state(reader, provider, sid, name, hold_id) != "accepted" and time.time() < deadline:
                            time.sleep(0.15)
                    time.sleep(0.3)
                    stopped = interrupt(reader, provider, sid, 8)
                    def interrupted(found):
                        return any(event_kind(row) == "turn.ended" and row.get("seq", 0) > before and payload_status(row) == "interrupted" for row in found)
                    done = wait_rows(reader, provider, sid, interrupted, 20 if real else 8)
                    steps["stop"] = {"pass": interrupted(done), "detail": "interrupted" if interrupted(done) else clip(stopped.get("reason") or stopped.get("status") or "not interrupted", home)}
                restarted = reader.host_cli(["stop", provider, sid])
                again = reader.host_cli(["start", provider, sid])
                texts = user_texts(reader, provider, sid)
                replay = all_events(reader, provider, sid)
                has_prompt = any(isinstance(text, str) and PROMPT in text for text in texts)
                has_reply = any(event_kind(row) == "text.done" and "PARITY" in payload_text(row) for row in replay)
                up = isinstance(again, dict) and again.get("status") in ("started", "already")
                steps["reopen"] = {"pass": up and has_prompt and has_reply, "detail": "history kept" if up and has_prompt and has_reply else clip(again.get("reason") if isinstance(again, dict) else restarted, home) or "history missing"}
        status = reader.host_cli(["status", provider, sid])
        shown = isinstance(status, dict) and status.get("tmux") == name
        steps["name"] = {"pass": shown, "detail": "shown" if shown else "missing"}
    except Exception as exc:
        for step, row in steps.items():
            if row["detail"] == "not run":
                row["detail"] = clip(type(exc).__name__, home)
                row["pass"] = False
    return session, steps


def purge_store(reader, provider, sid):
    path = reader.message_store_path()
    if not path.is_file():
        return
    db = sqlite3.connect(path)
    try:
        tables = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        ids = []
        if "shared_messages" in tables:
            ids = [row[0] for row in db.execute("SELECT id FROM shared_messages WHERE provider=? AND sid=?", (provider, sid))]
        for table in ("message_events", "message_attempts", "connector_states", "connector_facts", "message_resets", "message_locators", "message_snapshots", "message_chats"):
            if table in tables:
                db.execute(f"DELETE FROM {table} WHERE provider=? AND sid=?", (provider, sid))
        if "shared_messages" in tables:
            db.execute("DELETE FROM shared_messages WHERE provider=? AND sid=?", (provider, sid))
        for token in ids:
            if "message_retries" in tables:
                db.execute("DELETE FROM message_retries WHERE id=?", (token,))
            if "message_attempt_history" in tables:
                db.execute("DELETE FROM message_attempt_history WHERE id=?", (token,))
            if "message_room_scopes" in tables:
                db.execute("DELETE FROM message_room_scopes WHERE id=?", (token,))
        db.commit()
    finally:
        db.close()


def cleanup(reader, sessions):
    removed = []
    for session in sessions:
        name = session["name"]
        provider, sid = session["provider"], session["sid"]
        if not name.startswith(PREFIX) or provider not in PROVIDERS:
            removed.append(dict(session, alive=True, enabled=True, skipped=True))
            continue
        paths = reader.host_paths(provider, sid)
        config = reader.host_read(paths["config"]) if paths["config"].exists() else None
        if isinstance(config, dict) and (config.get("tmux") not in (None, name) or config.get("sid") not in (None, sid)):
            removed.append(dict(session, alive=True, enabled=True, skipped=True))
            continue
        try:
            reader.host_cli(["disable", provider, sid])
        except Exception:
            pass
        try:
            if reader.host_alive(provider, sid):
                reader.host_stop(provider, sid, force=True)
        except Exception:
            pass
        for key in ("config", "lock", "owner", "state", "backoff", "restart", "history", "log", "errors", "socket"):
            path = paths.get(key)
            try:
                if isinstance(path, Path) and path.exists():
                    path.unlink()
            except OSError:
                pass
        try:
            purge_store(reader, provider, sid)
        except sqlite3.Error:
            pass
        status = reader.host_cli(["status", provider, sid])
        alive = isinstance(status, dict) and status.get("alive") is True
        enabled = isinstance(status, dict) and status.get("enabled") is True
        removed.append({"provider": provider, "sid": sid, "name": name, "alive": alive, "enabled": enabled})
    return {"ok": all(not row.get("skipped") and row["alive"] is False and row["enabled"] is False for row in removed), "sessions": removed}


def version_of(binary):
    found = shutil.which(binary)
    if not found:
        return {"binary": binary, "present": False, "version": ""}
    try:
        result = subprocess.run([found, "--version"], capture_output=True, text=True, timeout=8)
    except (OSError, subprocess.SubprocessError):
        return {"binary": binary, "present": True, "version": ""}
    line = ((result.stdout or result.stderr or "").strip().splitlines() or [""])[0]
    return {"binary": binary, "present": True, "version": line[:120]}


def doctor(real, reader_path):
    binaries = {
        "claude": "claude",
        "pi": "pi",
        "cursor": "agent",
        "codex": "codex",
    }
    report = {
        "reader": reader_path.is_file(),
        "providers": {name: version_of(binary) if real else {"binary": binary, "present": shutil.which(binary) is not None, "version": "stand-in"} for name, binary in binaries.items()},
    }
    return report


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def run(real, evidence):
    evidence.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[1]
    home = None
    if real:
        reader_path = Path.home() / ".multiprompt-runtime/reader.py"
        cwd = "/tmp/soft-2463-parity-cwd"
        Path(cwd).mkdir(mode=0o700, exist_ok=True)
        catalog = real_catalog
    else:
        home = tempfile.mkdtemp(prefix="parity-home-")
        os.chmod(home, 0o700)
        install_standins(home)
        reader_path = root / "src/chat_history_reader.py"
        cwd = str(Path(home) / "work")
        Path(cwd).mkdir(mode=0o700)
        catalog = stand_in_catalog
    checked = doctor(real, reader_path)
    write_json(evidence / "doctor.json", checked)
    if not checked["reader"]:
        report = {"mode": "real" if real else "stand-in", "ok": False, "gaps": [{"provider": "claude", "step": "start", "detail": "reader missing"}], "providers": {}, "sessions": []}
        write_json(evidence / "report.json", report)
        (evidence / "table.md").write_text("Reader is missing.\n")
        return 2
    reader = load_reader(reader_path)
    sessions = []
    providers = {}
    try:
        for provider in PROVIDERS:
            print(f"provider {provider}", file=sys.stderr)
            session, steps = run_provider(reader, provider, cwd, real, catalog, home)
            sessions.append(session)
            providers[provider] = steps
            write_json(evidence / "sessions.json", sessions)
    finally:
        verdict = compare(providers)
        report = {"mode": "real" if real else "stand-in", "ok": verdict["ok"], "steps": list(STEPS), "providers": providers, "gaps": verdict["gaps"], "sessions": sessions}
        write_json(evidence / "report.json", report)
        (evidence / "table.md").write_text(table(report))
        print(table(report), end="")
        cleaned = cleanup(reader, sessions)
        if not cleaned["ok"]:
            report["ok"] = False
            write_json(evidence / "report.json", report)
        write_json(evidence / "cleanup.json", cleaned)
        if home is not None:
            shutil.rmtree(home, ignore_errors=True)
    return 0 if report["ok"] else 1


def main(argv):
    if argv[1:2] == ["--compare"] and len(argv) == 3:
        loaded = json.loads(Path(argv[2]).read_text())
        report = compare(loaded.get("providers", loaded))
        print(json.dumps(report))
        return 0 if report["ok"] else 1
    real = "--real" in argv
    stand = "--stand-in" in argv
    if real == stand:
        print("usage: live-chat-parity.py --real|--stand-in --evidence DIR", file=sys.stderr)
        return 2
    if "--evidence" not in argv or argv.index("--evidence") + 1 >= len(argv):
        print("usage: live-chat-parity.py --real|--stand-in --evidence DIR", file=sys.stderr)
        return 2
    evidence = Path(argv[argv.index("--evidence") + 1])
    return run(real, evidence)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
