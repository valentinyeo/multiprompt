#!/usr/bin/env python3
import json
import os


TAB_AGENTS = {"claude": 1, "codex": 2, "pi": 3, "hax": 5, "grok": 6, "cursor": 7}
TAB_VERBS = frozenset(("open", "close"))
TAB_FIELDS = ("host", "user", "workspace", "group", "position", "kind", "sid", "pinned", "archived", "waiting", "closed", "tmux", "name")


def pc_state(send):
    view = send.zsb("pc-state")
    if view.get("ok") is not True or view.get("schema") != 1 or not isinstance(view.get("tabs"), list):
        raise ValueError("desktop PC-state is unavailable; update or connect the desktop and retry")
    for row in view["tabs"]:
        if any(field not in row for field in (*TAB_FIELDS, "visible", "hidden_reason")):
            raise ValueError("desktop returned an incomplete tab state")
    return view


def same_tab_state(left, right):
    return all(left.get(field) == right.get(field) for field in (*TAB_FIELDS, "shell", "agent", "chat_id"))


def tab_target(view, name, host=None):
    if host is not None:
        try:
            host = view["hosts"][int(host)]
        except (ValueError, IndexError, KeyError):
            raise ValueError("host must be a configured slot")
    wanted = name.strip().casefold()
    if wanted.endswith("}") and "{" in wanted:
        wanted = wanted.rsplit("{", 1)[1][:-1]
    matches = [row for row in view["tabs"] if (host is None or row["host"] == host) and
               wanted in (row["name"].casefold(), row["tmux"].casefold(), (row["sid"] or "").casefold())]
    if len(matches) > 1:
        raise ValueError("more than one tab matches; pass --host and the terminal session name")
    return matches[0] if matches else None


def tab_command(send, args):
    verb = args.command
    view = pc_state(send)
    name = getattr(args, "name", None) or getattr(args, "tmux", None) or (getattr(args, "title", None) or ("Shell" if getattr(args, "kind", None) == "shell" else None) if verb == "open" else None)
    if not name:
        raise ValueError(verb + " needs a tab name or --tmux")
    target = tab_target(view, name, getattr(args, "host", None))
    if target is None:
        if verb != "open":
            raise ValueError("no tab named " + repr(name))
        slot = int(getattr(args, "host", None) or os.environ.get("MULTIPROMPT_HOST") or "0")
        if slot < 0 or slot >= len(view.get("hosts", [])):
            raise ValueError("host must be a configured slot")
        kind = getattr(args, "kind", None)
        workspace = getattr(args, "workspace", None)
        tmux = getattr(args, "tmux", None)
        if not tmux and kind == "shell":
            tmux = "@shell-" + str(view["instance"]) + "-" + str(view["next_shell_id"])
        if kind not in ("chat", "shell") or not workspace or not tmux:
            raise ValueError("new tabs need --kind chat|shell, --tmux and --workspace")
        provider = getattr(args, "provider", None)
        agent = TAB_AGENTS.get(provider, 1 if kind == "chat" else 0)
        shell = "tmux" if not tmux.startswith("@shell-") else "cmd" if view["hosts"][slot] == "local" else "vps" if slot == 0 else "vps2"
        target = dict(shell=shell, agent=agent, chat_id=0, cwd=getattr(args, "folder", None), host=view["hosts"][slot], user=(view.get("users") or [""] * 3)[slot],
                      workspace=workspace, group=getattr(args, "group", None),
                      position=getattr(args, "position", None) or 0, kind=kind,
                      sid=getattr(args, "sid", None), pinned=False, archived=False, waiting=False,
                      closed=False, visible=False, hidden_reason=None, tmux=tmux,
                      name=getattr(args, "title", None) or name)
        expected = None
    else:
        expected = dict(target)
        if verb == "open":
            if getattr(args, "provider", None) is not None and "agent" in target and TAB_AGENTS[args.provider] != target["agent"]:
                raise ValueError("open keeps the existing AI provider")
            for option, field in (("folder", "cwd"), ("title", "name")):
                requested = getattr(args, option, None)
                if requested is not None and field in target and requested != target[field]:
                    raise ValueError("open keeps the existing " + field)
            for field in ("kind", "sid", "workspace", "group", "position", "tmux"):
                requested = getattr(args, field, None)
                if requested is not None and requested != target[field]:
                    raise ValueError("open keeps the existing " + field + "; use move for placement changes")
    desired = dict(target)
    if verb in ("open", "restore"):
        desired.update(closed=False, archived=False, waiting=False)
    elif verb == "close":
        desired["closed"] = True
    elif verb in ("pin", "unpin"):
        desired["pinned"] = verb == "pin"
    elif verb == "archive":
        desired.update(archived=True, waiting=False)
    elif verb == "unarchive":
        desired["archived"] = False
    elif verb == "wait":
        desired.update(waiting=True, archived=False)
    elif verb == "move":
        if all(getattr(args, field, None) is None for field in ("workspace", "group", "position")):
            raise ValueError("move needs --workspace, --group or --position")
        for field in ("workspace", "group", "position"):
            value = getattr(args, field, None)
            if value is not None:
                desired[field] = None if field == "group" and value == "" else value
    else:
        raise ValueError("unknown tab verb")
    changed = expected is None or not same_tab_state(expected, desired)
    if changed:
        request = dict(verb=verb, expected=expected, state=desired)
        reply = send.zsb("tab-action", json.dumps(request, separators=(",", ":")))
        if reply.get("ok") is not True:
            raise ValueError("desktop refused " + verb + ": " + str(reply.get("error") or "no acknowledgement"))
        after = pc_state(send)
        actual = tab_target(after, desired["tmux"], str(view["hosts"].index(desired["host"])))
        if actual is None or not same_tab_state(actual, desired):
            raise ValueError("desktop PC-state did not confirm " + verb)
    else:
        actual = target
    result = dict(ok=True, verb=verb, changed=changed, state=actual)
    print(json.dumps(result, separators=(",", ":")) if getattr(args, "json", False) else verb + " " + actual["name"])
    return 0
