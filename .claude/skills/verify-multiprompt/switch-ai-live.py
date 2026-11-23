#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
MARKER = "SOFT-3056-SWITCH-MARKER"
PROVIDERS_PATH = Path(__file__).resolve().parent / "providers-switch-ai.json"
DEFAULT_ROUTE = ("claude", "codex", "pi", "claude")
WAIT_REPLY = 180.0
WAIT_HOST = 45.0
START_PAUSE = 3.0


def reader_path():
    configured = os.environ.get("MULTIPROMPT_READER_SOURCE")
    if configured:
        return Path(configured)
    runtime = Path.home() / ".multiprompt-runtime" / "active.json"
    try:
        active = json.loads(runtime.read_text(encoding="utf-8"))
        digest = active.get("sha256")
        if isinstance(digest, str) and len(digest) == 64:
            path = Path.home() / ".multiprompt-runtime" / (digest + ".py")
            if path.is_file():
                return path
    except (OSError, ValueError):
        pass
    return ROOT / "src/chat_history_reader.py"


def load_reader(path):
    import importlib.util
    spec = importlib.util.spec_from_file_location("switch_ai_live_reader", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("reader not loadable: " + str(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_cli(reader, args):
    result = reader.host_cli(args)
    if not isinstance(result, dict):
        raise RuntimeError("invalid host reply: " + repr(result))
    return result


def history_text(reader, provider, sid):
    paths = reader.host_paths(provider, sid)
    if not paths["history"].is_file():
        return ""
    return paths["history"].read_text(encoding="utf-8")


def message_dispatch(reader, provider, sid, tmux):
    store = dict(message_protocol=1, provider=provider, sid=sid, tmux=tmux, op="message_dispatch")
    try:
        reader.message_store_request(store)
    except (OSError, ValueError, KeyError, TypeError):
        pass
    try:
        reader.message_poll(tmux, provider, sid)
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        pass


def event_seq(reader, provider, sid):
    return reader.message_events_page(provider, sid, 0).get("seq", 0)


def wait_reply(reader, provider, sid, tmux, timeout, seen):
    deadline = time.monotonic() + timeout
    history_len = len(history_text(reader, provider, sid))
    while time.monotonic() < deadline:
        message_dispatch(reader, provider, sid, tmux)
        page = reader.message_events_page(provider, sid, seen)
        seen = page.get("seq", seen)
        for entry in page.get("events", []):
            event = entry.get("event") or {}
            if event.get("kind") == "text.done":
                payload = event.get("payload") or {}
                text = payload.get("text")
                if isinstance(text, str) and text.strip():
                    return text.strip(), seen
        body = history_text(reader, provider, sid)
        if len(body) > history_len:
            for line in body.splitlines()[history_len:]:
                try:
                    row = json.loads(line).get("row") or {}
                except ValueError:
                    continue
                if row.get("role") == "assistant" and isinstance(row.get("text"), str):
                    text = row["text"].strip()
                    if text and not text.startswith("---"):
                        return text, seen
            history_len = len(body)
        time.sleep(0.5)
    raise RuntimeError("no assistant reply from " + provider)


def wait_idle(reader, provider, sid, tmux, timeout):
    deadline = time.monotonic() + timeout
    busy = getattr(reader, "host_turn_busy", None)
    while time.monotonic() < deadline:
        message_dispatch(reader, provider, sid, tmux)
        status = run_cli(reader, ["status", provider, sid])
        inflight = status.get("inflight")
        if inflight is None and (not callable(busy) or not busy(provider, sid)):
            return True
        time.sleep(0.5)
    return False


def host_ready(reader, provider, sid, tmux, timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        page = reader.message_events_page(provider, sid, 0)
        for entry in page.get("events", []):
            event = entry.get("event") or {}
            if event.get("kind") == "host.status" and (event.get("payload") or {}).get("state") == "ready":
                return True
        message_dispatch(reader, provider, sid, tmux)
        time.sleep(0.5)
    return False


def live_chats(reader, tmux):
    return [chat for chat in reader.host_chats() if chat.get("name") == tmux]


def main():
    vps_state = Path.home() / ".local/bin/vps-state"
    if not vps_state.is_file() or subprocess.run([str(vps_state), "--can-launch", "worker"], capture_output=True).returncode != 0:
        raise RuntimeError("vps-state --can-launch worker refused this run")
    targets = json.loads(PROVIDERS_PATH.read_text(encoding="utf-8"))["switch_targets"]
    route = tuple(os.environ.get("SWITCH_AI_ROUTE", ",".join(DEFAULT_ROUTE)).split(","))
    for name in route:
        if name not in targets:
            raise RuntimeError("missing provider row: " + name)
    path = reader_path()
    reader = load_reader(path)
    tmux = "verify-switch-" + uuid.uuid4().hex[:10]
    sid = str(uuid.uuid4())
    folder = str(ROOT)
    state = {"tmux": tmux, "sid": sid, "provider": route[0], "steps": []}
    created = False
    seen = 0
    try:
        subprocess.run(["tmux", "new-session", "-d", "-s", tmux, "-c", folder], check=True)
        created = True
        reply = run_cli(reader, ["enable", route[0], sid, "--tmux", tmux, "--cwd", folder, "--permission-mode", "bypassPermissions"])
        if reply.get("status") != "enabled":
            raise RuntimeError("enable failed: " + json.dumps(reply))
        started = run_cli(reader, ["start", route[0], sid])
        if started.get("status") not in ("started", "already"):
            raise RuntimeError("start failed: " + json.dumps(started))
        time.sleep(START_PAUSE)
        host_ready(reader, route[0], sid, tmux, WAIT_HOST)
        seen = event_seq(reader, route[0], sid)
        run_cli(reader, ["send", route[0], sid, "--text", MARKER + ": reply with one short sentence acknowledging the marker.", "--tmux", tmux])
        _, seen = wait_reply(reader, route[0], sid, tmux, WAIT_REPLY, seen)
        state["steps"].append(dict(step="seed", provider=route[0], tmux=tmux, chats=len(live_chats(reader, tmux))))
        current_provider, current_sid = route[0], sid
        for target in route[1:]:
            if not wait_idle(reader, current_provider, current_sid, tmux, WAIT_REPLY):
                raise RuntimeError("chat still busy before switch to " + target)
            env_before = reader.host_agent_env(current_provider, current_sid)
            switched = run_cli(reader, ["switch-ai", current_provider, current_sid, "--to", target])
            if switched.get("status") != "switched":
                raise RuntimeError("switch failed: " + json.dumps(switched))
            current_provider = switched["provider"]
            current_sid = switched["sid"]
            if switched.get("tmux") != tmux:
                raise RuntimeError("address changed during switch")
            name = reader.host_chat_name(current_provider, current_sid)
            if name != tmux:
                raise RuntimeError("name changed during switch")
            env_after = reader.host_agent_env(current_provider, current_sid)
            for key in ("MULTIPROMPT_TAB", "ZSB_SESSION", "MULTIBOT_SESSION"):
                if env_before.get(key) != env_after.get(key):
                    raise RuntimeError("identity env changed: " + key)
            if MARKER not in history_text(reader, current_provider, current_sid):
                raise RuntimeError("marker missing after switch to " + target)
            chats = live_chats(reader, tmux)
            if len(chats) != 1 or chats[0]["provider"] != current_provider or chats[0]["sid"] != current_sid:
                raise RuntimeError("live chat count mismatch: " + json.dumps(chats))
            prompt = "SOFT-3056 follow-up on " + target + ": one short new sentence."
            host_ready(reader, current_provider, current_sid, tmux, WAIT_HOST)
            seen = event_seq(reader, current_provider, current_sid)
            run_cli(reader, ["send", current_provider, current_sid, "--text", prompt, "--tmux", tmux])
            reply_text, seen = wait_reply(reader, current_provider, current_sid, tmux, WAIT_REPLY, seen)
            state["steps"].append(dict(step="switch", provider=target, sid=current_sid, reply=reply_text[:120], chats=1))
        state["status"] = "passed"
        print(json.dumps(state, indent=2))
        return 0
    finally:
        try:
            run_cli(reader, ["disable", state.get("provider", route[0]), state.get("sid", sid)])
        except (OSError, ValueError, KeyError, RuntimeError):
            pass
        if created:
            subprocess.run(["tmux", "kill-session", "-t", tmux], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)