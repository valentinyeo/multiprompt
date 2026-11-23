# Formal Switch AI

Source files: .claude/skills/verify-switch-ai-formal/*, .github/workflows/chat-switch-ai-formal.yml
CI workflow: chat-switch-ai-formal.yml

## Sub-features

Check Switch AI in a bounded TLA+ model tied to `host_switch_ai` through native probes and Python replay. One address must keep one live chat; a failed start must not leave the old AI off.

## How to get to it (user POV)

An agent changing this skill or workflow runs [verify-switch-ai-formal](../../verify-switch-ai-formal/SKILL.md). Changes to covered product files still trigger this workflow separately from desktop journeys.

## Driving it with GitHub CI

Run the skill's one-command check with production replay and three planted mutations on GitHub's Linux runner. Read every model result with pstack /statechart.

The PR selector owns these files through `CI workflow:`. The verifier requires this workflow on the exact pull request head.

## Gotchas

`FailedSwitchKeepsOld` passes at the current sync commit; keep it because a start failure after the commit is the bug it was written for. `IdentityStable` and `HistoryReadable` are not always-pass: they fall on a doubled chat (two locators) and on a commit that opens the new chat without the earlier rows, and `--self-test` plants both. A replayed counterexample that finishes without showing its symptom is a red run, and makes `check.py` exit 2. Adding Antigravity is a row in `providers.json`, not a separate toolchain.