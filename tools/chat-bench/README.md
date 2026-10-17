# Isolated Chat View benchmark

This optional Linux/Wine harness generates synthetic Claude and Codex conversations and runs a Windows cross-build in a fresh Wine prefix. It does not use real conversations, SSH hosts, browser profiles or account credentials. It measures switching, idle CPU, incremental updates, restart and browser-split geometry; it is not live Windows acceptance.

Prerequisites: Zig 0.16, Node.js, Python 3, Wine (including `wineserver` and `wineboot`), Xvfb (`xvfb-run`), xdotool, ImageMagick (`import`, `convert`, `montage`) and standard Linux process tools.

```sh
zig build -Dtarget=x86_64-windows-gnu
node tools/chat-bench/run.mjs --exe zig-out/bin/multiprompt.exe --out .audit-chat-bench
```

Use a new output directory for every run. The runner exits nonzero if its acceptance rules fail. Results, logs, screenshots, synthetic histories and the disposable Wine prefix stay under the output directory; do not commit them. `config.json` contains the default workload and rules; `--config <file>` supplies overrides. Unit tests and fail-closed positive controls run with `node --test tools/chat-bench.test.js` and are included in `tools/public_audit.py --verify`. Private historical-build injection and release-scope checks are not included.
