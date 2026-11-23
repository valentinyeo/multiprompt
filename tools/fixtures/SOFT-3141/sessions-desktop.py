#!/usr/bin/env python3
import hashlib
import json
import os
from pathlib import Path
import sys

with open(os.environ["MP_SESSIONS_TEST_LOG"], "a") as stream:
    stream.write(json.dumps(["zsb", sys.argv[1:]]) + "\n")
path = Path(os.environ["MP_SESSIONS_TEST_STATE_FILE"])
state = json.loads(path.read_text())
listing = state.get("listing") or json.loads(os.environ["MP_SESSIONS_TEST_LIST"])
if "listing" not in state and state.get("tabs"):
    listing["workspaces"][0]["tabs"] = state["tabs"]
records = []
for workspace in listing.get("workspaces", []):
    position = 0
    for group in [dict(name=None, tabs=workspace.get("tabs", [])), *workspace.get("groups", [])]:
        for tab in group.get("tabs", []):
            sid = None
            for config_path in (Path(os.environ["HOME"]) / ".local/state/multiprompt/agent-host").glob("*.config.json"):
                config = json.loads(config_path.read_text())
                if config.get("tmux") == tab["tmux"]:
                    sid = config.get("sid")
            tab.setdefault("tab_state", dict(host=tab["host"], user="agent", workspace=workspace["name"], group=group["name"],
                                            position=position, kind=tab.get("kind") or ("shell" if tab.get("cv") is False else "chat"),
                                            sid=sid, pinned=tab.get("pinned", False), archived=False, waiting=False,
                                            closed=False, visible=True, hidden_reason=None, tmux=tab["tmux"], name=tab["title"]))
            records.append(tab["tab_state"])
            position += 1
listing["closed_tabs"] = state.get("closed_tabs", [])
verb = sys.argv[1]
if verb == "workspace-list":
    print(json.dumps(listing))
elif verb == "pc-state":
    print(json.dumps(dict(ok=listing.get("ok"), schema=1, hosts=listing.get("hosts", []), users=["agent"] * len(listing.get("hosts", [])),
                          workspaces=[ws["name"] for ws in listing.get("workspaces", [])], tabs=records + listing["closed_tabs"])))
elif verb == "tab-action":
    request = json.loads(sys.argv[2])
    desired = request["state"]
    workspace = next((ws for ws in listing.get("workspaces", []) if ws["name"] == desired["workspace"]), None)
    if workspace is None:
        print(json.dumps(dict(ok=False, error="UnknownWorkspace")))
        raise SystemExit(0)
    if os.environ.get("MP_SESSIONS_TEST_SHELL_TAB") == "1":
        desired["kind"] = "shell"
    for ws in listing["workspaces"]:
        ws["tabs"] = [tab for tab in ws.get("tabs", []) if tab["tmux"] != desired["tmux"]]
        for group in ws.get("groups", []):
            group["tabs"] = [tab for tab in group.get("tabs", []) if tab["tmux"] != desired["tmux"]]
    closed = [tab for tab in listing["closed_tabs"] if tab["tmux"] != desired["tmux"]]
    desired["hidden_reason"] = next((flag for flag in ("closed", "archived", "waiting") if desired[flag]), None)
    desired["visible"] = desired["hidden_reason"] is None
    if desired["closed"] or desired["archived"]:
        closed.append(desired)
    else:
        tabs = workspace.setdefault("tabs", [])
        if desired["group"]:
            group = next(group for group in workspace["groups"] if group["name"] == desired["group"])
            tabs = group.setdefault("tabs", [])
        tabs.insert(desired["position"], dict(id=state.get("next_tab", 55), title=desired["name"], tmux=desired["tmux"],
                                              host=desired["host"], kind=desired["kind"], cv=desired["kind"] == "chat", tab_state=desired))
        state["next_tab"] = state.get("next_tab", 55) + 1
    state.update(listing=listing, closed_tabs=closed, tabs=listing["workspaces"][0]["tabs"])
    path.write_text(json.dumps(state))
    print(json.dumps(dict(ok=True, state=desired)))
elif verb == "session-rename":
    tab_id = int(sys.argv[sys.argv.index("--tab") + 1])
    for ws in listing["workspaces"]:
        for group in [dict(tabs=ws.get("tabs", [])), *ws.get("groups", [])]:
            for tab in group["tabs"]:
                if tab["id"] == tab_id:
                    tab["title"] = sys.argv[sys.argv.index("--name") + 1]
                    tab["tab_state"]["name"] = tab["title"]
    state["listing"] = listing
    state["tabs"] = listing["workspaces"][0]["tabs"]
    path.write_text(json.dumps(state))
    print(json.dumps(dict(ok=True)))
else:
    print(json.dumps(dict(ok=False, error="unsupported_command")))
