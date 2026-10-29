#!/usr/bin/env python3
import datetime
import json
import os
from pathlib import Path
import re
import shutil
import shlex
import subprocess
import sys
import tomllib

BASE = Path(__file__).resolve().parent
HOME = Path.home()
DEST = HOME / ".local/share/zigshell"
STAMP = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%d-%H%M%S-%f")


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        if path.read_text(encoding="utf-8-sig") == text:
            return False
        shutil.copy2(path, str(path) + ".pre-zigshell-" + STAMP)
    temporary = path.with_name(path.name + ".zigshell-tmp")
    temporary.write_text(text, encoding="utf-8", newline="\n")
    os.replace(temporary, path)
    print("updated", path)
    return True


def owned(command, kinds=("notify", "eta")):
    markers = {
        "notify": ("zigshell-session.sh", "zigshell-active.sh", "zigshell-done.sh", "zigshell-notify.sh", "zigshell/notify.py"),
        "eta": ("zigshell/eta_hook.py",),
    }
    return any(marker in command for kind in kinds for marker in markers[kind])


def merge_hooks(path, entries, cursor=False, kinds=("notify", "eta")):
    data = json.loads(path.read_text(encoding="utf-8-sig")) if path.exists() else {}
    hooks = data.setdefault("hooks", {})
    for event, groups in list(hooks.items()):
        if not isinstance(groups, list):
            continue
        kept = []
        for group in groups:
            if cursor:
                if not owned(group.get("command", ""), kinds):
                    kept.append(group)
            else:
                handlers = group.get("hooks")
                if not isinstance(handlers, list):
                    kept.append(group)
                    continue
                cleaned = [h for h in handlers if not owned(h.get("command", ""), kinds)]
                if cleaned:
                    kept.append({**group, "hooks": cleaned})
        hooks[event] = kept
    for event, command in entries.items():
        handler = {"command": command}
        if not cursor:
            handler.update(type="command", timeout=2)
            handler = {"hooks": [handler]}
        hooks.setdefault(event, []).append(handler)
    if cursor:
        data["version"] = 1
    return write(path, json.dumps(data, indent=2) + "\n")


def eta_commands(python, helper):
    return {
        "UserPromptSubmit": f'"{python}" "{helper}" prompt',
        "PreToolUse": f'"{python}" "{helper}" pretool',
        "PostToolUse": f'"{python}" "{helper}" posttool',
    }


HAX_ETA_FILE = "zigshell-eta.md"
HAX_ETA_NOTE = (
    "Before you start, estimate how long this request will take you and run: "
    'mp-eta <time> "<what you are doing>". When what you learn changes the '
    "picture, run mp-eta <time left> again. If you end your turn while "
    "background work continues, add --bg.\n"
)


def hax_config_dir():
    base = os.environ.get("XDG_CONFIG_HOME")
    return (Path(base) if base else HOME / ".config") / "hax"


def install_hax_eta():
    directory = hax_config_dir()
    config_path = directory / "config.json"
    if not config_path.exists():
        return False
    write(directory / HAX_ETA_FILE, HAX_ETA_NOTE)
    data = json.loads(config_path.read_text(encoding="utf-8-sig"))
    current = data.get("system_prompt_append")
    if current is not None and not isinstance(current, str):
        return False
    reference = "@" + HAX_ETA_FILE
    text = current or ""
    if reference in text:
        return False
    data["system_prompt_append"] = (text.rstrip() + "\n" if text.strip() else "") + reference
    return write(config_path, json.dumps(data, indent=2) + "\n")


def tmux_config(fifo):
    destination = shlex.quote(str(fifo))

    def emit(event):
        fields = f"{event} #{{q:session_name}}'' #{{q:pane_current_command}}'' #{{pane_pid}}'' #{{pane_id}}'' #{{q:socket_path}}''"
        command = f"if [ -p {destination} ]; then printf '%s\\0' {fields} 3<>{destination} >&3; fi"
        return "run-shell -b " + json.dumps(command, ensure_ascii=False)

    clear = "if-shell -F '#{==:#{session_attached},0}' { kill-session -C }"
    rearm = (
        "set-environment -h -t #{session_id} MULTIPROMPT_NOTIFY_READY 1; "
        "if-shell -F -t #{session_id}: '##{==:##{session_attached},0}' { kill-session -C -t #{session_id} }"
    )
    activity = (
        "if-shell -F '#{MULTIPROMPT_NOTIFY_READY}' { if-shell -F '#{window_active}' { "
        "set-environment -h MULTIPROMPT_NOTIFY_READY 0; "
        "if-shell -F '#{==:#{MULTIPROMPT_NOTIFY_STATE},0}' { set-environment -h MULTIPROMPT_NOTIFY_STATE 1; "
        "run-shell -bCd 3 " + json.dumps(rearm) + " } { "
        "if-shell -F '#{==:#{MULTIPROMPT_NOTIFY_STATE},1}' { set-environment -h MULTIPROMPT_NOTIFY_STATE 2 }; " + emit("activity") + "; "
        "run-shell -bCd 15 " + json.dumps(rearm) + " } } }"
    )
    silence = (
        "if-shell -F '#{&&:#{window_active},#{!=:#{MULTIPROMPT_NOTIFY_STATE},0}}' { " + clear + "; "
        "if-shell -F '#{==:#{MULTIPROMPT_NOTIFY_STATE},2}' { " + emit("silence") + " }; "
        "set-environment -h MULTIPROMPT_NOTIFY_STATE 0 }"
    )
    title = "if-shell -F '#{&&:#{&&:#{window_active},#{pane_active}},#{m:✳*,#{pane_title}}}' { " + emit("title") + " }"
    lines = [
        "set-option -g monitor-activity on",
        "set-option -gw monitor-silence 10",
        "set-option -g activity-action any",
        "set-option -g silence-action any",
        "set-option -g visual-activity off",
        "set-option -g visual-silence off",
        "set-environment -gh MULTIPROMPT_NOTIFY_STATE 0",
        "set-environment -gh MULTIPROMPT_NOTIFY_READY 1",
    ]
    for event, command in (
        ("alert-activity", activity), ("alert-silence", silence),
        ("pane-title-changed", title), ("session-created", emit("session")),
        ("client-attached", emit("attach")),
    ):
        lines.append(f"set-hook -g {event}[514] {{ {command} }}")
    return "\n".join(lines) + "\n"


def install_tmux_hooks():
    snippet = DEST / "tmux-notifications.conf"
    write(DEST / "tmux_notify.py", (BASE / "tmux_notify.py").read_text(encoding="utf-8"))
    write(snippet, tmux_config(Path(f"/tmp/mp-notify-{os.getuid()}/tmux-events")))
    config = HOME / ".tmux.conf"
    text = config.read_text(encoding="utf-8") if config.exists() else ""
    source = "source-file -q " + shlex.quote(str(snippet))
    if source not in text.splitlines():
        write(config, text + ("\n" if text and not text.endswith("\n") else "") + source + "\n")
    unit = HOME / ".config/systemd/user/zigshell-watcher.service"
    try:
        result = subprocess.run(["systemctl", "--user", "disable", "--now", "zigshell-watcher.service"], check=False)
        if result.returncode and unit.exists():
            raise RuntimeError("Legacy watcher service could not be stopped and disabled")
    except (OSError, subprocess.CalledProcessError) as error:
        if unit.exists():
            raise
        print("Legacy watcher service not disabled:", error)
    for path in (HOME / ".local/bin/zigshell-watcher.sh", HOME / ".config/systemd/user/zigshell-watcher.service"):
        if path.exists():
            shutil.copy2(path, str(path) + ".pre-zigshell-" + STAMP)
            path.unlink()
    try:
        subprocess.run(["tmux", "source-file", str(snippet)], check=True, capture_output=True, text=True)
    except (OSError, subprocess.CalledProcessError):
        print("Tmux hooks saved; a new tmux server will load them from ~/.tmux.conf.")


def install(with_eta=False):
    write(DEST / "notify.py", (BASE / "notify.py").read_text(encoding="utf-8"))
    for filename in ("mp_complete.py", "claude_interactive_builtins.tsv", "codex_slash.txt", "harvest_tui.sh"):
        write(DEST / filename, (BASE / filename).read_text(encoding="utf-8"))
    python = Path(sys.executable).as_posix()
    helper = (DEST / "notify.py").as_posix()
    eta_helper = (DEST / "eta_hook.py").as_posix()
    if with_eta:
        write(DEST / "mp_eta.py", (BASE / "mp_eta.py").read_text(encoding="utf-8"))
        write(DEST / "eta_hook.py", (BASE / "eta_hook.py").read_text(encoding="utf-8"))
        script = DEST / "mp_eta.py"
        if os.name == "nt":
            wrapper = HOME / ".local/bin/mp-eta.cmd"
            write(wrapper, f'@echo off\r\n"{python}" "{script}" %*\r\n')
        else:
            wrapper = HOME / ".local/bin/mp-eta"
            write(wrapper, f'#!/bin/sh\nexec "{python}" "{script}" "$@"\n')
            wrapper.chmod(0o755)
    def command(agent, event):
        return f'"{python}" "{helper}" {agent} {event}'

    for profile in (HOME / ".claude", HOME / ".claude-secondary"):
        if profile.is_dir():
            merge_hooks(profile / "settings.json", {
                "SessionStart": command("claude", "session"),
                "UserPromptSubmit": command("claude", "active"),
                "Stop": command("claude", "done"),
                "Notification": command("claude", "notify"),
            }, kinds=("notify",))
            if with_eta:
                merge_hooks(profile / "settings.json", eta_commands(python, eta_helper), kinds=("eta",))
    if (HOME / ".cursor").is_dir():
        merge_hooks(HOME / ".cursor/hooks.json", {
            "sessionStart": command("cursor", "session"),
            "beforeSubmitPrompt": command("cursor", "active"),
            "stop": command("cursor", "done"),
        }, cursor=True)
    if (HOME / ".grok").is_dir():
        merge_hooks(HOME / ".grok/hooks/zigshell.json", {
            "SessionStart": command("grok", "session"),
            "UserPromptSubmit": command("grok", "active"),
            "Stop": command("grok", "done"),
        })
    if (HOME / ".codex").is_dir():
        codex_changed = merge_hooks(HOME / ".codex/hooks.json", {
            "SessionStart": command("codex", "session"),
            "UserPromptSubmit": command("codex", "active"),
            "Stop": command("codex", "done"),
        })
        if with_eta:
            codex_changed = merge_hooks(
                HOME / ".codex/hooks.json", eta_commands(python, eta_helper), kinds=("eta",)
            ) or codex_changed
            if codex_changed:
                print("codex: approve the new hooks once in Codex before they run")
        cfg = HOME / ".codex/config.toml"
        if cfg.exists():
            text = cfg.read_text(encoding="utf-8-sig")
            parsed = tomllib.loads(text)
            previous = parsed.get("notify", [])
            if any("codex-zigshell-notify.sh" in x for x in previous):
                wrapper = HOME / ".local/bin/codex-zigshell-notify.sh"
                write(wrapper, '#!/bin/sh\nexec python3 "$HOME/.local/share/zigshell/notify.py" codex notify "$@"\n')
                wrapper.chmod(0o755)
    if with_eta:
        install_hax_eta()
    if (HOME / ".pi/agent").is_dir():
        write(HOME / ".pi/agent/extensions/zigshell.ts", (BASE / "pi-zigshell.ts").read_text(encoding="utf-8"))
    if os.name != "nt":
        install_tmux_hooks()
        write(DEST / "mp_notify_relay.py", (BASE / "mp_notify_relay.py").read_text(encoding="utf-8"))
        unit = HOME / ".config/systemd/user/mp-notify-relay.service"
        write(unit, (BASE / "mp-notify-relay.service").read_text(encoding="utf-8"))
        try:
            subprocess.run(["systemctl", "--user", "daemon-reload"], check=True)
            subprocess.run(["systemctl", "--user", "enable", "--now", "mp-notify-relay.service"], check=True)
            subprocess.run(["systemctl", "--user", "restart", "mp-notify-relay.service"], check=True)
            marker = HOME / ".local/state/multiprompt/relay-v1"
            write(marker, "1\n")
            result = subprocess.run(["loginctl", "show-user", str(os.getuid()), "-p", "Linger", "--value"],
                                    capture_output=True, text=True, check=False)
            if result.stdout.strip() != "yes":
                print("Note: user linger is off; the relay stops when you log out. Enable it manually if needed.")
        except (OSError, subprocess.CalledProcessError) as error:
            print("Relay service not enabled:", error)
        for name, event in (("active", "active"), ("done", "done"), ("session", "session"), ("notify", "notify")):
            path = HOME / f".claude/hooks/zigshell-{name}.sh"
            write(path, f'#!/bin/sh\nexec python3 "$HOME/.local/share/zigshell/notify.py" claude {event}\n')
            path.chmod(0o755)



if __name__ == "__main__":
    install("--with-eta" in sys.argv[1:])
