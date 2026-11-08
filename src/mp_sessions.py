#!/usr/bin/env python3
import argparse
import importlib.util
import json
import sys
from pathlib import Path


def load_send():
    source = Path(__file__).resolve().with_name("mp_send.py")
    spec = importlib.util.spec_from_file_location("mp_send", source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def table(chats):
    rows = [("NAME", "PROVIDER", "STATE", "TMUX", "SID", "CWD")]
    for chat in chats:
        rows.append((chat["name"] or "(no name yet)", chat["provider"], chat["state"], chat["tmux"], chat["sid"], chat["cwd"] or ""))
    widths = [max(len(row[i]) for row in rows) for i in range(5)]
    return "\n".join("  ".join(row[i].ljust(widths[i]) for i in range(5)) + "  " + row[5] for row in rows)


def main(argv=None):
    parser = argparse.ArgumentParser(prog="mp-sessions", description="List the live chats on this server by the name shown in the desktop app.")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)
    chats = load_send().live_chats()
    if args.json:
        print(json.dumps(chats, separators=(",", ":")))
    else:
        print(table(chats))
    return 0


if __name__ == "__main__":
    sys.exit(main())
