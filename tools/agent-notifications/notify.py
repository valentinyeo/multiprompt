#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import time

AGENTS = {"claude", "codex", "hax", "grok", "cursor", "pi"}
TOKEN = re.compile(r"[A-Za-z0-9_. /()-]{1,120}\Z")
STATE_OVERRIDE = "MULTIPROMPT_STATE_DIR"
ETA_LOG_MAX = 5000
ETA_LOG_KEEP = 2000


def target(env):
    if env.get("TMUX"):
        pane = env.get("TMUX_PANE", "")
        if not re.fullmatch(r"%[0-9]+", pane):
            return None
        result = subprocess.run(
            ["tmux", "display-message", "-p", "-t", pane, "#{session_name}"],
            capture_output=True, text=True, encoding="utf-8", timeout=0.5, check=True,
        )
        name = result.stdout.strip()
        return (name, 19548, True) if TOKEN.fullmatch(name) else None
    if env.get("MULTIPROMPT_TAB"):
        name = env["MULTIPROMPT_TAB"]
        return (name, 19548, True) if TOKEN.fullmatch(name) else None
    if os.name == "nt" and env.get("ZIGSHELL_SHELL_ID") and env.get("ZIGSHELL_NOTIFY_PORT"):
        import ctypes
        ctypes.windll.user32.IsWindow.argtypes = [ctypes.c_void_p]
        sid = int(env["ZIGSHELL_SHELL_ID"])
        rows = []
        for path in (Path(env["APPDATA"]) / "ZigShell").glob("inbox-*.json"):
            try:
                data = json.loads(path.read_text(encoding="utf-8-sig"))
                if not ctypes.windll.user32.IsWindow(data.get("hwnd", 0)):
                    continue
                rows.extend(data.get("shells", []))
            except (OSError, ValueError):
                continue
        matches = [r for r in rows if r.get("sid") == sid]
        if len(matches) != 1:
            return None
        name = matches[0].get("name", "")
        port = int(env["ZIGSHELL_NOTIFY_PORT"])
        if TOKEN.fullmatch(name) and sum(r.get("name") == name for r in rows) == 1 and 19548 <= port <= 19559:
            return name, port, False
    return None


def messages(agent, event, payload, name):
    if agent not in AGENTS or event not in {"session", "active", "done", "notify"}:
        return []
    if any(payload.get(k) for k in ("agent_id", "subagent_id", "subagentType", "subagent_type")):
        return []
    if event == "notify":
        if agent == "claude" and payload.get("notification_type") == "permission_prompt":
            return [f"NOTIFICATION:{name}"]
        if payload.get("type") != "agent-turn-complete":
            return []
        event = "done"
    if payload.get("sessionId") and not payload.get("session_id"):
        if agent != "grok":
            return []
    result = []
    if agent == "claude" and event in {"session", "done"}:
        sid = payload.get("session_id", "")
        cwd = payload.get("cwd", "")
        if re.fullmatch(r"[A-Za-z0-9_-]{1,100}", sid) and isinstance(cwd, str) and not any(c in cwd for c in "\r\n\0") and len(cwd) < 700:
            result.append(f"SESSION:{name}:{sid}:{cwd}")
    result.append(f"AGENT:{name}:{agent}")
    if event != "session":
        result.append(f"{event.upper()}:{name}")
    return result


def deliver_log_path():
    return state_dir() / "deliver-fail.log"


def log_deliver_failure(item, port, error):
    try:
        with open(deliver_log_path(), "a", encoding="utf-8") as handle:
            handle.write(f"{int(time.time())} port={port} item={item!r} error={error!r}\n")
    except OSError:
        pass


def deliver(items, port, attempts=3):
    token = None
    if os.name != "nt":
        try:
            token = os.environ.get("MULTIPROMP_NOTIFY_RELAY_TOKEN")
            if not token:
                token = subprocess.run([str(Path.home() / ".local/bin/yeo-key"), "Multiprompt Notify Relay Token", "MULTIPROMP_NOTIFY_RELAY_TOKEN"], check=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True).stdout.rstrip("\n")
            if not token:
                raise ValueError()
        except (OSError, subprocess.SubprocessError, ValueError):
            raise SystemExit(1) from None
    for item in items:
        last_error = None
        for attempt in range(attempts):
            if attempt:
                time.sleep(0.15)
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=0.3) as connection:
                    connection.sendall((f"AUTH:{token}:{item}" if token else item).encode("utf-8"))
                last_error = None
                break
            except OSError as error:
                last_error = error
        if last_error is not None:
            log_deliver_failure(item, port, last_error)
            raise last_error


def agent_name(env=None):
    env = os.environ if env is None else env
    explicit = str(env.get("MP_AGENT") or "").strip().lower()
    if explicit:
        return explicit
    if env.get("CLAUDE_CODE_SESSION_ID") or env.get("CLAUDECODE"):
        return "claude"
    if any(key.startswith("CODEX_") for key in env):
        return "codex"
    if any(key.startswith("HAX_") for key in env):
        return "hax"
    return "unknown"


def state_dir(env=None):
    env = os.environ if env is None else env
    override = env.get(STATE_OVERRIDE, "")
    if override:
        return Path(override)
    return Path(os.path.expanduser("~")) / ".local/state/multiprompt"


def lifecycle_path(session_id):
    return state_dir() / ("claude-lifecycle-" + session_id + ".json")


def lifecycle_state(name, session_id):
    if not isinstance(session_id, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,100}", session_id):
        return None
    entry = read_json(lifecycle_path(session_id), {})
    return entry.get("event") if isinstance(entry, dict) and entry.get("name") == name else None


def set_lifecycle(name, session_id, event):
    if not isinstance(session_id, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,100}", session_id):
        return
    write_json(lifecycle_path(session_id), {"name": name, "event": event})


def read_json(path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    os.replace(temporary, path)


def as_seconds(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return int(value)


def format_duration(seconds):
    seconds = max(0, int(seconds))
    if seconds < 60:
        return f"{seconds}s"
    hours, rest = divmod(seconds, 3600)
    minutes = rest // 60
    if hours:
        return f"{hours}h{minutes}m" if minutes else f"{hours}h"
    return f"{minutes}m"


TAB_STATE_MAX = 200
TAB_STATE_STALE = 24 * 60 * 60


def tab_state_path():
    return state_dir() / "tab-state.json"


def _lifecycle_state(item):
    if item.startswith("DONE:"):
        return "done"
    if item.startswith("ACTIVE:"):
        return "active"
    return None


def record_tab_states(items, now=None):
    now = int(time.time() if now is None else now)
    updates = {}
    for item in items:
        state = _lifecycle_state(item)
        if state is None:
            continue
        name = item.split(":", 1)[1]
        if name:
            updates[name] = {"state": state, "at": now}
    if not updates:
        return
    data = read_json(tab_state_path(), {})
    if not isinstance(data, dict):
        data = {}
    data.update(updates)
    fresh = {}
    for name, entry in data.items():
        if not isinstance(entry, dict):
            continue
        at = as_seconds(entry.get("at")) or 0
        if now - at > TAB_STATE_STALE:
            continue
        fresh[name] = entry
    if len(fresh) > TAB_STATE_MAX:
        ordered = sorted(fresh.items(), key=lambda pair: as_seconds(pair[1].get("at")) or 0)
        fresh = dict(ordered[-TAB_STATE_MAX:])
    write_json(tab_state_path(), fresh)


def eta_open_path():
    return state_dir() / "eta-open.json"


def eta_log_path():
    return state_dir() / "eta-log.jsonl"


def eta_open():
    data = read_json(eta_open_path(), {})
    return data if isinstance(data, dict) else {}


def set_eta_open(name, entry):
    data = eta_open()
    data[name] = entry
    write_json(eta_open_path(), data)


def eta_entry(name):
    entry = eta_open().get(name)
    return entry if isinstance(entry, dict) else None


def drop_eta(name):
    data = eta_open()
    if name in data:
        del data[name]
        write_json(eta_open_path(), data)


def append_eta_log(entry):
    path = eta_log_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, ensure_ascii=False) + "\n")
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
        if len(lines) > ETA_LOG_MAX:
            path.write_text("\n".join(lines[-ETA_LOG_KEEP:]) + "\n", encoding="utf-8")
    except OSError:
        pass


def finish_eta(name, finished_at):
    data = eta_open()
    entry = data.pop(name, None)
    if not isinstance(entry, dict):
        return
    write_json(eta_open_path(), data)
    final = as_seconds(entry.get("est_seconds"))
    first = as_seconds(entry.get("first_est_seconds"))
    estimate = first if first is not None and first > 0 else final
    started = as_seconds(entry.get("started_at"))
    if estimate is None or started is None or estimate <= 0:
        return
    append_eta_log({
        "agent": str(entry.get("agent", "unknown")),
        "est_seconds": estimate,
        "final_est_seconds": final if final is not None else estimate,
        "revisions": as_seconds(entry.get("revisions")) or 0,
        "actual_seconds": max(0, int(finished_at) - started),
        "finished_at": int(finished_at),
        "desc": str(entry.get("desc", "")),
    })


def eta_line(name, entry, now):
    started = as_seconds(entry.get("started_at")) or int(now)
    total = as_seconds(entry.get("est_seconds")) or 0
    remaining = max(0, started + total - int(now))
    return f"ETA:{name}:{remaining}:{entry.get('desc', '')}"


def eta_bookkeeping(items, now):
    extra = []
    for item in items:
        if item.startswith("DONE:"):
            name = item[5:]
            entry = eta_entry(name)
            if isinstance(entry, dict) and entry.get("carried"):
                continue
            if isinstance(entry, dict) and entry.get("background"):
                entry["background"] = False
                entry["carried"] = True
                set_eta_open(name, entry)
                extra.append(eta_line(name, entry, now))
            else:
                finish_eta(name, now)
        elif item.startswith("ACTIVE:"):
            name = item[7:]
            entry = eta_entry(name)
            if isinstance(entry, dict) and entry.get("carried"):
                drop_eta(name)
            elif isinstance(entry, dict):
                extra.append(eta_line(name, entry, now))
    return extra


def eta_stats(limit=20):
    try:
        lines = eta_log_path().read_text(encoding="utf-8").splitlines()
    except OSError:
        return {}
    ratios = {}
    for line in lines:
        try:
            row = json.loads(line)
        except ValueError:
            continue
        if not isinstance(row, dict):
            continue
        estimate = as_seconds(row.get("est_seconds"))
        actual = as_seconds(row.get("actual_seconds"))
        if estimate is None or actual is None or estimate <= 0 or actual < 120:
            continue
        agent = str(row.get("agent") or "unknown")
        ratios.setdefault(agent, []).append(actual / estimate)
    result = {}
    for agent, values in ratios.items():
        if len(values) < 3:
            continue
        sample = sorted(values[-limit:])
        middle = len(sample) // 2
        median = sample[middle] if len(sample) % 2 else (sample[middle - 1] + sample[middle]) / 2
        result[agent] = (median, len(sample))
    return result


def main():
    if os.environ.get("MP_COMPLETE_PROBE"):
        return
    if len(sys.argv) < 3:
        return
    resolved = target(os.environ)
    if not resolved:
        return
    agent, event = sys.argv[1:3]
    raw = sys.argv[3] if len(sys.argv) > 3 else sys.stdin.read(1024 * 1024)
    payload = json.loads(raw) if raw.strip() else {}
    if not isinstance(payload, dict):
        return
    name, port, remote = resolved
    if agent == "claude" and event == "session" and remote:
        subprocess.Popen([sys.executable, str(Path(__file__).with_name("mp_complete.py")), "--warm", "claude"],
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
    if (event == "done" or (event == "notify" and payload.get("type") == "agent-turn-complete")) and (eta_entry(name) or {}).get("carried"):
        if agent != "claude" or lifecycle_state(name, payload.get("session_id")) != "active":
            return
    items = messages(agent, event, payload, name)
    if not items:
        return
    extra = []
    try:
        extra = eta_bookkeeping(items, time.time()) or []
    except Exception:
        pass
    try:
        record_tab_states(items + extra, time.time())
    except Exception:
        pass
    deliver(items + extra, port)
    if agent == "claude" and event in {"active", "done"}:
        try:
            set_lifecycle(name, payload.get("session_id"), event)
        except OSError:
            pass
    if remote and items[-1].startswith("DONE:"):
        marker = Path("/tmp") / ("zigshell-semantic-" + name.replace("/", "_"))
        actual_agent = next(item.rsplit(":", 1)[1] for item in items if item.startswith("AGENT:"))
        if event == "notify" and marker.exists() and marker.read_text(encoding="utf-8") == actual_agent + " full":
            marker.touch()
            return
        marker.write_text(actual_agent + (" notify" if event == "notify" else " full"), encoding="utf-8")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
