#!/usr/bin/env python3
import argparse
import importlib.machinery
import importlib.util
import json
import sys
from pathlib import Path


def load_send():
    here = Path(__file__).resolve()
    source = here.with_name("mp_send.py")
    if not source.is_file():
        source = here.with_name("mp-send")
    loader = importlib.machinery.SourceFileLoader("mp_send", str(source))
    spec = importlib.util.spec_from_loader("mp_send", loader)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main(argv=None):
    parser = argparse.ArgumentParser(prog="mp-sessions", description="List the live chats on this server by the name shown in the desktop app.")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)
    send = load_send()
    chats = send.live_chats()
    if args.json:
        print(json.dumps(chats, separators=(",", ":")))
    else:
        print(send.table(chats))
    return 0


if __name__ == "__main__":
    sys.exit(main())
