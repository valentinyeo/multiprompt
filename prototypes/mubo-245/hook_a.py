#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
import time


def normalize_cwd(value):
    if not isinstance(value, str) or not value.strip():
        return ""
    try:
        return str(Path(value).resolve()).lower()
    except OSError:
        return value.strip().lower()


def load_store(store_path):
    if not store_path or not store_path.is_file():
        return {}
    try:
        data = json.loads(store_path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def resolve_pin(store, payload, env):
    by_sid = store.get("by_sid") if isinstance(store.get("by_sid"), dict) else {}
    by_cwd = store.get("by_cwd") if isinstance(store.get("by_cwd"), dict) else {}
    env_sid = (env.get("MULTIBOT_SID") or "").strip()
    hook_sid = str(payload.get("session_id") or "").strip()
    cwd_key = normalize_cwd(payload.get("cwd") or "")
    if env_sid:
        if env_sid in by_sid:
            return by_sid[env_sid], "env_sid"
        return None, "env_sid_unpinned"
    if hook_sid and hook_sid in by_sid:
        return by_sid[hook_sid], "hook_sid"
    if cwd_key and cwd_key in by_cwd:
        return by_cwd[cwd_key], "cwd"
    return None, "none"


def append_log(log_path, record):
    if not log_path:
        return
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record, separators=(",", ":")) + "\n")
    except OSError:
        pass


def main():
    started = time.perf_counter()
    raw = sys.stdin.read(1024 * 1024)
    try:
        payload = json.loads(raw) if raw.strip() else {}
    except ValueError:
        payload = {}
    if not isinstance(payload, dict):
        payload = {}
    store_env = os.environ.get("MUBO245_PIN_STORE", "").strip()
    log_env = os.environ.get("MUBO245_HOOK_LOG", "").strip()
    store_path = Path(store_env) if store_env else None
    log_path = Path(log_env) if log_env else None
    store = load_store(store_path)
    entry, matched_by = resolve_pin(store, payload, os.environ)
    output = None
    if isinstance(entry, dict) and isinstance(entry.get("additional_context"), str) and entry["additional_context"].strip():
        output = {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": entry["additional_context"].strip(),
            }
        }
    elapsed_ms = round((time.perf_counter() - started) * 1000.0, 2)
    append_log(
        log_path,
        {
            "ts": round(time.time(), 3),
            "hook_event_name": payload.get("hook_event_name"),
            "session_id": payload.get("session_id"),
            "env_sid": os.environ.get("MULTIBOT_SID", ""),
            "cwd": payload.get("cwd"),
            "matched_by": matched_by,
            "skill": entry.get("skill") if isinstance(entry, dict) else None,
            "injected": output is not None,
            "elapsed_ms": elapsed_ms,
        },
    )
    if output is not None:
        sys.stdout.write(json.dumps(output) + "\n")
        sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
