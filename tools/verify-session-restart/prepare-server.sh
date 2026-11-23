#!/usr/bin/env bash
set -euo pipefail
repo=$1
runuser -u mpverify -- env HOME=/home/mpverify bash "$repo/tools/install-mp-talk.sh"
runuser -u mpverify -- env HOME=/home/mpverify python3 -c "import importlib.util; p='$repo/src/chat_history_reader.py'; spec=importlib.util.spec_from_file_location('reader', p); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m); print('reader ok', m.__file__)"