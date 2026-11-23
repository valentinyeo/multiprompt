#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import sys
import threading
import time
import uuid

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import skills


def find_claude_cmd():
    override = os.environ.get("MUBO245_CLAUDE_CLI_JS", "").strip()
    node = shutil.which("node")
    if override and node and Path(override).is_file():
        return [node, override]
    npm_root = None
    npm = shutil.which("npm")
    if npm:
        try:
            proc = subprocess.run([npm, "root", "-g"], capture_output=True, text=True, timeout=15)
            if proc.returncode == 0 and proc.stdout.strip():
                npm_root = Path(proc.stdout.strip())
        except (OSError, subprocess.SubprocessError):
            npm_root = None
    candidates = []
    if npm_root:
        candidates.append(npm_root / "@anthropic-ai" / "claude-code" / "cli.js")
    local_root = os.environ.get("MUBO245_CLAUDE_PREFIX", "").strip()
    if local_root:
        candidates.append(Path(local_root) / "node_modules" / "@anthropic-ai" / "claude-code" / "cli.js")
    claude_bin = shutil.which("claude")
    if claude_bin:
        bin_dir = Path(claude_bin).resolve().parent
        candidates.extend([
            bin_dir / "node_modules" / "@anthropic-ai" / "claude-code" / "cli.js",
            bin_dir.parent / "lib" / "node_modules" / "@anthropic-ai" / "claude-code" / "cli.js",
        ])
    if node:
        for candidate in candidates:
            if candidate.is_file():
                return [node, str(candidate)]
    if claude_bin:
        return [claude_bin]
    raise RuntimeError("Claude Code CLI not found on PATH or npm global root")


def probe_claude_cli(base_cmd, out_dir):
    probe = {"base_cmd": base_cmd, "version": "", "has_output_style_flag": False, "has_append_system_prompt": False, "has_settings_flag": False}
    try:
        ver = subprocess.run(base_cmd + ["--version"], capture_output=True, text=True, timeout=20)
        probe["version"] = (ver.stdout or ver.stderr).strip()
    except (OSError, subprocess.SubprocessError) as exc:
        probe["version"] = f"error: {exc}"
    try:
        hlp = subprocess.run(base_cmd + ["--help"], capture_output=True, text=True, timeout=20)
        help_text = (hlp.stdout or "") + "\n" + (hlp.stderr or "")
        probe["has_output_style_flag"] = "--output-style" in help_text
        probe["has_append_system_prompt"] = "--append-system-prompt" in help_text
        probe["has_settings_flag"] = "--settings" in help_text
        (out_dir / "claude_help.txt").write_text(help_text, encoding="utf-8")
    except (OSError, subprocess.SubprocessError) as exc:
        probe["help_error"] = str(exc)
    return probe


class ClaudeStreamSession:
    def __init__(self, base_cmd, cwd, env, session_id, resume, append_prompt, model, extra_args=None):
        self.cwd = str(cwd)
        self.session_id = session_id
        self.native_session = session_id
        self.argv = list(base_cmd) + [
            "--permission-mode", "bypassPermissions",
            "--print",
            "--input-format", "stream-json",
            "--output-format", "stream-json",
            "--verbose",
            "--model", model,
            "--disallowedTools", "Bash,Edit,Write,Glob,Grep,WebFetch,WebSearch,Agent,NotebookEdit",
            "--append-system-prompt", append_prompt,
        ]
        if extra_args:
            self.argv.extend(extra_args)
        if resume:
            self.argv.extend(["--resume", session_id])
        else:
            self.argv.extend(["--session-id", session_id])
        self.started_at = time.perf_counter()
        self.proc = subprocess.Popen(
            self.argv,
            cwd=self.cwd,
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
        )
        self.lines = queue.Queue()
        self.stderr_lines = []
        self._out_thread = threading.Thread(target=self._read_stdout, daemon=True)
        self._err_thread = threading.Thread(target=self._read_stderr, daemon=True)
        self._out_thread.start()
        self._err_thread.start()
        self.init_event = None

    def _read_stdout(self):
        try:
            for raw in self.proc.stdout:
                self.lines.put(raw.decode("utf-8", errors="replace"))
        finally:
            self.lines.put(None)

    def _read_stderr(self):
        try:
            for raw in self.proc.stderr:
                line = raw.decode("utf-8", errors="replace").rstrip()
                if line:
                    self.stderr_lines.append(line)
        except OSError:
            pass

    def send_turn(self, text, timeout_s=120):
        t0 = time.perf_counter()
        msg_uuid = str(uuid.uuid4())
        payload = {
            "type": "user",
            "uuid": msg_uuid,
            "message": {
                "role": "user",
                "content": [{"type": "text", "text": text}],
            },
        }
        line = (json.dumps(payload, separators=(",", ":")) + "\n").encode("utf-8")
        self.proc.stdin.write(line)
        self.proc.stdin.flush()
        assistant_texts = []
        result_event = None
        hook_events = []
        deadline = time.perf_counter() + timeout_s
        while time.perf_counter() < deadline:
            remaining = max(0.05, deadline - time.perf_counter())
            try:
                raw = self.lines.get(timeout=min(remaining, 1.0))
            except queue.Empty:
                if self.proc.poll() is not None:
                    break
                continue
            if raw is None:
                break
            raw = raw.strip()
            if not raw:
                continue
            try:
                ev = json.loads(raw)
            except ValueError:
                continue
            kind = ev.get("type")
            if kind == "system":
                subtype = ev.get("subtype")
                if subtype == "init":
                    self.init_event = ev
                    if isinstance(ev.get("session_id"), str) and ev["session_id"]:
                        self.native_session = ev["session_id"]
                elif subtype and "hook" in str(subtype):
                    hook_events.append(ev)
            elif kind == "assistant":
                msg = ev.get("message") if isinstance(ev.get("message"), dict) else {}
                for block in msg.get("content") or []:
                    if isinstance(block, dict) and block.get("type") == "text" and isinstance(block.get("text"), str):
                        assistant_texts.append(block["text"])
            elif kind == "result":
                result_event = ev
                if isinstance(ev.get("session_id"), str) and ev["session_id"]:
                    self.native_session = ev["session_id"]
                break
        elapsed_ms = round((time.perf_counter() - t0) * 1000.0, 1)
        if result_event is None:
            raise RuntimeError(
                f"Claude stream ended without result (rc={self.proc.poll()}). "
                f"stderr tail: {' | '.join(self.stderr_lines[-8:])}"
            )
        reply = result_event.get("result")
        if not isinstance(reply, str) or not reply.strip():
            reply = "\n".join(assistant_texts).strip()
        usage = result_event.get("usage") if isinstance(result_event.get("usage"), dict) else {}
        return {
            "reply": reply,
            "elapsed_ms": elapsed_ms,
            "claude_duration_ms": result_event.get("duration_ms"),
            "is_error": bool(result_event.get("is_error")),
            "subtype": result_event.get("subtype"),
            "cost_usd": result_event.get("total_cost_usd"),
            "usage": {
                "input_tokens": usage.get("input_tokens", 0),
                "cache_creation_input_tokens": usage.get("cache_creation_input_tokens", 0),
                "cache_read_input_tokens": usage.get("cache_read_input_tokens", 0),
                "output_tokens": usage.get("output_tokens", 0),
            },
            "hook_events": hook_events,
            "native_session": self.native_session,
        }

    def close(self):
        try:
            if self.proc.stdin:
                self.proc.stdin.close()
        except OSError:
            pass
        try:
            self.proc.wait(timeout=8)
        except subprocess.TimeoutExpired:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def read_jsonl(path):
    if not path.is_file():
        return []
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except ValueError:
            pass
    return out


def find_transcript_for_session(native_sid):
    claude_projects = Path.home() / ".claude" / "projects"
    if not claude_projects.is_dir():
        return None
    target = f"{native_sid}.jsonl"
    for hit in claude_projects.rglob(target):
        return hit
    return None


def setup_option_a_workspace(workdir, sid, skill_cfg, pin_store_path, hook_log_path):
    claude_dir = workdir / ".claude"
    claude_dir.mkdir(parents=True, exist_ok=True)
    hook_cmd = f'"{Path(sys.executable).as_posix()}" "{(HERE / "hook_a.py").as_posix()}"'
    settings = {
        "hooks": {
            "UserPromptSubmit": [
                {
                    "hooks": [
                        {
                            "type": "command",
                            "command": hook_cmd,
                        }
                    ]
                }
            ]
        }
    }
    settings_path = claude_dir / "settings.local.json"
    write_json(settings_path, settings)
    store = {
        "by_sid": {
            sid: {
                "skill": skill_cfg["name"],
                "additional_context": skill_cfg["hook_context"],
            }
        },
        "by_cwd": {},
    }
    write_json(pin_store_path, store)
    return settings_path


def run_option_a_isolation_check(base_cmd, workdir, pin_store_path, hook_log_path, model):
    other_sid = str(uuid.uuid4())
    env = dict(os.environ)
    env["MULTIBOT_SID"] = other_sid
    env["MUBO245_PIN_STORE"] = str(pin_store_path)
    env["MUBO245_HOOK_LOG"] = str(hook_log_path)
    before = len(read_jsonl(hook_log_path))
    sess = ClaudeStreamSession(base_cmd, workdir, env, other_sid, False, skills.HOST_APPEND_PROMPT, model)
    try:
        res = sess.send_turn("Reply with only the single word ISOLATED and nothing else.")
    finally:
        sess.close()
    logs = read_jsonl(hook_log_path)[before:]
    passed, checks = skills.check_pinned_canary(res["reply"], pinned=False)
    return {
        "other_sid": other_sid,
        "reply": res["reply"],
        "passed": passed,
        "checks": checks,
        "hook_logs": logs,
    }


def run_skill_scenario(option, skill_name, base_cmd, workdir, model, probe):
    skill_cfg = skills.SKILLS[skill_name]
    turns_spec = skills.TURNS_BY_SKILL[skill_name]
    sid = str(uuid.uuid4())
    pin_store_path = workdir / "pins.json"
    hook_log_path = workdir / "hook_invocations.jsonl"
    env = dict(os.environ)
    env["MULTIBOT_SID"] = sid
    extra_args = []
    if option == "a":
        settings_path = setup_option_a_workspace(workdir, sid, skill_cfg, pin_store_path, hook_log_path)
        env["MUBO245_PIN_STORE"] = str(pin_store_path)
        env["MUBO245_HOOK_LOG"] = str(hook_log_path)
        if probe.get("has_settings_flag"):
            extra_args = ["--settings", str(settings_path)]
        append_prompt = skills.HOST_APPEND_PROMPT
    elif option == "b":
        append_prompt = skills.HOST_APPEND_PROMPT
    elif option == "c":
        append_prompt = skills.HOST_APPEND_PROMPT + "\n\n" + skill_cfg["system_append"]
    else:
        raise ValueError(f"Unknown option: {option}")

    isolation_result = None
    if option == "a" and skill_name == "pinned-canary":
        isolation_result = run_option_a_isolation_check(base_cmd, workdir, pin_store_path, hook_log_path, model)

    session = ClaudeStreamSession(base_cmd, workdir, env, sid, False, append_prompt, model, extra_args=extra_args)
    native_sid = sid
    turns_out = []
    restart_ms = None
    unpin_restart_ms = None
    option_c_unpin_stuck_check = None
    pinned = True

    try:
        for idx, (phase, user_prompt) in enumerate(turns_spec, 1):
            if idx == 11:
                t_restart = time.perf_counter()
                native_sid = session.native_session
                session.close()
                session = ClaudeStreamSession(
                    base_cmd, workdir, env, native_sid, True, append_prompt, model, extra_args=extra_args
                )
                restart_ms = round((time.perf_counter() - t_restart) * 1000.0, 1)

            if idx == 21:
                pinned = False
                if option == "a":
                    write_json(pin_store_path, {"by_sid": {}, "by_cwd": {}})
                elif option == "b":
                    pass
                elif option == "c":
                    if skill_name == "pinned-canary":
                        stuck_res = session.send_turn("Reply with only the single word STILLSTUCK and nothing else.")
                        stuck_ended_pinned = stuck_res["reply"].strip().split()[-1] == "PINNED" if stuck_res["reply"].strip() else False
                        option_c_unpin_stuck_check = {
                            "reply_without_restart": stuck_res["reply"],
                            "remained_stuck_without_restart": stuck_ended_pinned,
                        }
                    t_unpin = time.perf_counter()
                    native_sid = session.native_session
                    session.close()
                    append_prompt = skills.HOST_APPEND_PROMPT
                    session = ClaudeStreamSession(
                        base_cmd, workdir, env, native_sid, True, append_prompt, model, extra_args=extra_args
                    )
                    unpin_restart_ms = round((time.perf_counter() - t_unpin) * 1000.0, 1)

            if option == "b" and pinned:
                wire_prompt = skill_cfg["prepend_marker"] + "\n\n" + user_prompt
            else:
                wire_prompt = user_prompt

            hook_before = len(read_jsonl(hook_log_path)) if option == "a" else 0
            res = session.send_turn(wire_prompt)
            native_sid = res["native_session"]
            hook_logs_turn = read_jsonl(hook_log_path)[hook_before:] if option == "a" else []
            passed, checks = skills.verify_reply(skill_name, res["reply"], pinned=pinned)
            turns_out.append({
                "turn": idx,
                "phase": phase,
                "pinned": pinned,
                "ui_prompt": user_prompt,
                "wire_prompt": wire_prompt,
                "wire_prefixed": wire_prompt != user_prompt,
                "reply": res["reply"],
                "passed": passed,
                "checks": checks,
                "elapsed_ms": res["elapsed_ms"],
                "claude_duration_ms": res["claude_duration_ms"],
                "cost_usd": res["cost_usd"],
                "usage": res["usage"],
                "hook_fired": len(hook_logs_turn) > 0,
                "hook_injected": any(item.get("injected") for item in hook_logs_turn),
                "hook_elapsed_ms": hook_logs_turn[-1]["elapsed_ms"] if hook_logs_turn else None,
            })
            print(
                f"[option={option} skill={skill_name}] turn {idx:02d}/22 ({phase}) "
                f"pass={passed} ms={res['elapsed_ms']} in={res['usage']['input_tokens']} "
                f"cache_r={res['usage']['cache_read_input_tokens']} out={res['usage']['output_tokens']}",
                flush=True,
            )
    finally:
        session.close()

    transcript_path = find_transcript_for_session(native_sid)
    transcript_marker_hits = 0
    if transcript_path and transcript_path.is_file():
        raw_transcript = transcript_path.read_text(encoding="utf-8", errors="replace")
        transcript_marker_hits = raw_transcript.count("[Pinned skill:")

    pinned_turns = [t for t in turns_out if t["pinned"]]
    pre_turns = [t for t in turns_out if t["phase"] == "pre_restart"]
    post_turns = [t for t in turns_out if t["phase"] == "post_restart"]
    unpin_turns = [t for t in turns_out if t["phase"] == "post_unpin"]

    def avg(values):
        nums = [v for v in values if isinstance(v, (int, float))]
        return round(sum(nums) / len(nums), 1) if nums else 0.0

    summary = {
        "option": option,
        "skill": skill_name,
        "model": model,
        "sid": sid,
        "native_sid": native_sid,
        "pinned_pass": sum(1 for t in pinned_turns if t["passed"]),
        "pinned_total": len(pinned_turns),
        "pre_restart_pass": sum(1 for t in pre_turns if t["passed"]),
        "pre_restart_total": len(pre_turns),
        "post_restart_pass": sum(1 for t in post_turns if t["passed"]),
        "post_restart_total": len(post_turns),
        "unpin_pass": sum(1 for t in unpin_turns if t["passed"]),
        "unpin_total": len(unpin_turns),
        "avg_turn_ms": avg([t["elapsed_ms"] for t in turns_out]),
        "avg_hook_ms": avg([t["hook_elapsed_ms"] for t in turns_out if t["hook_elapsed_ms"] is not None]),
        "total_cost_usd": round(sum(t["cost_usd"] or 0.0 for t in turns_out), 6),
        "avg_input_tokens": avg([t["usage"]["input_tokens"] for t in pinned_turns]),
        "avg_cache_creation_tokens": avg([t["usage"]["cache_creation_input_tokens"] for t in pinned_turns]),
        "avg_cache_read_tokens": avg([t["usage"]["cache_read_input_tokens"] for t in pinned_turns]),
        "avg_output_tokens": avg([t["usage"]["output_tokens"] for t in pinned_turns]),
        "restart_ms": restart_ms,
        "unpin_restart_ms": unpin_restart_ms,
        "transcript_marker_hits": transcript_marker_hits,
        "isolation_result": isolation_result,
        "option_c_unpin_stuck_check": option_c_unpin_stuck_check,
        "hook_fired_count": sum(1 for t in turns_out if t["hook_fired"]),
        "hook_injected_count": sum(1 for t in turns_out if t["hook_injected"]),
    }
    return {"summary": summary, "turns": turns_out}


def probe_option_c_output_style(base_cmd, workdir, model):
    style_dir = workdir / ".claude" / "output-styles"
    style_dir.mkdir(parents=True, exist_ok=True)
    (style_dir / "pinned-canary.md").write_text(skills.SKILLS["pinned-canary"]["output_style_md"], encoding="utf-8")
    settings_path = workdir / ".claude" / "settings.local.json"
    write_json(settings_path, {"outputStyle": "pinned-canary"})
    sid = str(uuid.uuid4())
    env = dict(os.environ)
    sess = ClaudeStreamSession(base_cmd, workdir, env, sid, False, skills.HOST_APPEND_PROMPT, model, extra_args=["--settings", str(settings_path)])
    try:
        res = sess.send_turn("What is 2 + 2?")
        init_style = (sess.init_event or {}).get("output_style")
    finally:
        sess.close()
    passed, checks = skills.check_pinned_canary(res["reply"], pinned=True)
    return {
        "init_output_style": init_style,
        "reply": res["reply"],
        "passed": passed,
        "checks": checks,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--option", required=True, choices=["a", "b", "c"])
    parser.add_argument("--out", required=True)
    parser.add_argument("--model", default="haiku")
    args = parser.parse_args()

    out_dir = Path(args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    base_cmd = find_claude_cmd()
    probe = probe_claude_cli(base_cmd, out_dir)
    write_json(out_dir / "probe.json", probe)

    results = {
        "option": args.option,
        "model": args.model,
        "platform": sys.platform,
        "probe": probe,
        "skills": {},
        "output_style_probe": None,
        "error": None,
    }

    try:
        for skill_name in ("pinned-canary", "pospeak"):
            workdir = out_dir / f"work-{args.option}-{skill_name}"
            workdir.mkdir(parents=True, exist_ok=True)
            results["skills"][skill_name] = run_skill_scenario(
                args.option, skill_name, base_cmd, workdir, args.model, probe
            )
        if args.option == "c":
            style_dir = out_dir / "work-c-output-style"
            style_dir.mkdir(parents=True, exist_ok=True)
            results["output_style_probe"] = probe_option_c_output_style(base_cmd, style_dir, args.model)
    except Exception as exc:
        results["error"] = f"{type(exc).__name__}: {exc}"
        write_json(out_dir / "results.json", results)
        raise

    write_json(out_dir / "results.json", results)
    print(f"Completed option {args.option}: {out_dir / 'results.json'}", flush=True)


if __name__ == "__main__":
    main()
