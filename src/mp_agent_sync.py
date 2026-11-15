#!/usr/bin/env python3
import fcntl
import json
import os
import re
import subprocess
import sys
import uuid
from pathlib import Path

LINKS = "@agents"
TMUX_NAME = re.compile(r"[A-Za-z0-9_.:-]{1,64}\Z")


def agent_id(value):
    if not isinstance(value, str):
        return None
    try:
        parsed = uuid.UUID(value)
    except ValueError:
        return None
    text = str(parsed)
    return text if value.lower() == text else None


def names_path():
    return Path.home() / ".local/state/multiprompt/chat-names.json"


def load(path):
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return value if isinstance(value, dict) else {}


def save(path, records):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + "." + str(os.getpid()) + ".tmp")
    temporary.write_text(json.dumps(records, separators=(",", ":")), encoding="utf-8")
    os.replace(temporary, path)


def locked(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = (path.parent / "chat-names.lock").open("a")
    fcntl.flock(handle, fcntl.LOCK_EX)
    return handle


def chat_rows(records):
    rows = []
    for tmux, entry in records.items():
        if tmux == LINKS or not isinstance(tmux, str) or not isinstance(entry, dict):
            continue
        name = entry.get("name")
        if isinstance(name, str) and name.strip():
            rows.append((tmux, name))
    return rows


def assignments(records):
    raw = records.get(LINKS) if isinstance(records.get(LINKS), dict) else {}
    assigned = {}
    broken = False
    for tmux, entry in records.items():
        if tmux == LINKS or not isinstance(tmux, str) or not isinstance(entry, dict):
            continue
        mapped = agent_id(raw.get(tmux))
        stored = agent_id(entry.get("agent"))
        if mapped and stored and mapped != stored:
            broken = True
        agent = mapped or stored
        if agent:
            assigned[tmux] = agent
    for tmux, value in raw.items():
        agent = agent_id(value)
        if isinstance(tmux, str) and agent and tmux not in assigned:
            assigned[tmux] = agent
    return assigned, broken


def label(records, tmux):
    entry = records.get(tmux)
    if isinstance(entry, dict) and isinstance(entry.get("name"), str) and entry["name"].strip():
        return entry["name"]
    return tmux


def plan(records, remote):
    assigned, broken = assignments(records)
    groups = {}
    for tmux, agent in assigned.items():
        groups.setdefault(agent, []).append(tmux)
    clash_ids = {agent for agent, tmuxes in groups.items() if len(tmuxes) > 1}
    lines = []
    if broken or clash_ids:
        for agent in sorted(clash_ids):
            names = sorted(label(records, tmux) for tmux in groups[agent])
            lines.append("clash\t" + "\t".join(names))
        for tmux, name in sorted(chat_rows(records), key=lambda row: row[1]):
            if tmux not in assigned:
                lines.append("unlinked\t" + name)
        return lines, [], 1
    renames = []
    for tmux, name in sorted(chat_rows(records), key=lambda row: (row[1], row[0])):
        agent = assigned.get(tmux)
        if not agent:
            lines.append("unlinked\t" + name)
            continue
        current = remote.get(agent)
        if current is None:
            lines.append("missing\t" + name)
            continue
        if current != name:
            lines.append("rename\t" + name)
            renames.append((agent, name))
        else:
            lines.append("linked\t" + name)
    return lines, renames, 0


def remote_names():
    names = {}
    cursor = None
    for _ in range(20):
        command = ["hypertask", "--json", "agents", "list", "--limit", "100"]
        if cursor:
            command.extend(["--cursor", cursor])
        done = subprocess.run(command, capture_output=True, text=True, timeout=30)
        if done.returncode != 0:
            raise RuntimeError("could not list agents")
        try:
            data = json.loads(done.stdout)
        except ValueError as exc:
            raise RuntimeError("could not list agents") from exc
        agents = data.get("agents") if isinstance(data, dict) else None
        if not isinstance(agents, list):
            raise RuntimeError("could not list agents")
        for agent in agents:
            if not isinstance(agent, dict):
                continue
            identity = agent_id(agent.get("id"))
            if not identity:
                continue
            display = agent.get("display_name")
            names[identity] = display if isinstance(display, str) else ""
        cursor = data.get("nextCursor") if isinstance(data, dict) else None
        if not isinstance(cursor, str) or not cursor:
            break
    return names


def rename(agent, name):
    done = subprocess.run(["hypertask", "agents", "rename", "--id", agent, "--name", name], capture_output=True, text=True, timeout=30)
    if done.returncode != 0:
        raise RuntimeError("rename failed for " + name)


def sync_main(dry):
    records = load(names_path())
    try:
        remote = remote_names()
    except RuntimeError as exc:
        print(str(exc), file=sys.stderr)
        return 2
    lines, renames, code = plan(records, remote)
    if code == 0 and not dry:
        for agent, name in renames:
            try:
                rename(agent, name)
            except RuntimeError as exc:
                print(str(exc), file=sys.stderr)
                sys.stdout.write("".join(line + "\n" for line in lines))
                return 2
    sys.stdout.write("".join(line + "\n" for line in lines))
    return code


def link_main(argv):
    tmux = None
    identity = None
    index = 0
    while index < len(argv):
        if argv[index] == "--tmux" and index + 1 < len(argv):
            tmux = argv[index + 1]
            index += 2
        elif argv[index] == "--id" and index + 1 < len(argv):
            identity = argv[index + 1]
            index += 2
        else:
            print("usage: mp-agent-sync link --tmux SESSION --id AGENT", file=sys.stderr)
            return 2
    if not isinstance(tmux, str) or TMUX_NAME.fullmatch(tmux) is None or agent_id(identity) is None:
        print("usage: mp-agent-sync link --tmux SESSION --id AGENT", file=sys.stderr)
        return 2
    identity = agent_id(identity)
    path = names_path()
    handle = locked(path)
    try:
        records = load(path)
        assigned, broken = assignments(records)
        if broken or any(agent == identity and owner != tmux for owner, agent in assigned.items()):
            print("clash", file=sys.stderr)
            return 1
        links = dict(records.get(LINKS) if isinstance(records.get(LINKS), dict) else {})
        links[tmux] = identity
        records[LINKS] = links
        entry = records.get(tmux)
        if isinstance(entry, dict):
            entry = dict(entry)
            entry["agent"] = identity
            records[tmux] = entry
        save(path, records)
    finally:
        handle.close()
    print("linked\t" + label(records, tmux))
    return 0


def main(argv):
    if argv[:1] == ["link"]:
        return link_main(argv[1:])
    if argv == ["--dry-run"]:
        return sync_main(True)
    if argv:
        print("usage: mp-agent-sync [--dry-run]", file=sys.stderr)
        return 2
    return sync_main(False)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
