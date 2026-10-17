#!/usr/bin/env python3
import datetime
import json
import os
from pathlib import Path
import re
import shutil
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
        watcher = HOME / ".local/bin/zigshell-watcher.sh"
        if watcher.exists():
            changed = write(watcher, (BASE / "zigshell-watcher.sh").read_text(encoding="utf-8"))
            watcher.chmod(0o755)
            if changed:
                subprocess.run(["systemctl", "--user", "restart", "zigshell-watcher"], check=True)


if __name__ == "__main__":
    install("--with-eta" in sys.argv[1:])
