---
name: multi-bot-feedback
description: File a Multibot error report or feature request with chat identity, versions, recent steps and an optional reviewed screenshot. Use on /multi-bot-feedback or when reporting a Multibot failure yourself.
---

# Multi Bot feedback

Run this when the user types `/multi-bot-feedback [summary] [screenshot.png]`, or invoke it yourself after a Multibot failure. Do not ask for a token or log in. Do not file a separate ticket with another tool.

1. Describe what happened, what should have happened and what actually happened, using the current conversation. If the summary is omitted, report the most recent Multibot problem. Do not invent missing facts; say `Not observed` where needed.
2. Select up to six recent user/assistant turns or commands that explain the failure. Keep each short. Remove credentials, emails and unrelated private content before passing them as arguments. Never dump a whole transcript or environment.
3. Run the shared tool, quoting each value as data rather than executable shell text:

```sh
~/.multiprompt-runtime/multibot-feedback "Short problem title" --report \
  --why "What happened" --expected "Expected behavior" --actual "Observed behavior" \
  --step "User: recent action" --step "Assistant or command: relevant result"
```

Use `multibot-feedback` from PATH if the runtime executable is absent. If neither exists, report that the runtime tool must be installed; do not install anything yourself. The tool resolves the current name and session ID using `mp-sessions whoami --json`, records desktop and runtime versions, redacts text, routes the report and merges open duplicates. Keep the title stable for repeat reports; use `--signature "stable problem name"` when wording differs. Use `--kind feature` only for a requested capability, not a failure.

4. If a screenshot path was supplied, review the image for private text and credentials, then append `--attach "path.png"`. Only reviewed PNGs up to 8 MiB are accepted. Do not capture a screenshot or attach an unreviewed image. If unsafe, omit it and say why. File the text report even when no screenshot is available.
5. Relay the tool's result briefly. `filed URL` means confirmed; `queued, will be filed` means saved for the existing host intake to drain. Never call a queued report filed. If identity or version says `unavailable`, mention that limitation rather than inventing it. Do not run `--drain` or obtain credentials. Resume the original task afterward.
