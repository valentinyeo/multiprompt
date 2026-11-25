# Multi Bot session verbs and server slots

Source files: src/mp_sessions.py, src/mp_send.py, src/mp_layout.mjs, tools/mp-sessions, tools/mp-sessions-test.py, tools/mp-layout.mjs, tools/mp-layout-host.test.js, tools/mb.mjs, tools/check-servers-slots.mjs, tools/check-servers-slots.test.js, tools/fixtures/MUBO-194/*, tools/fixtures/MUBO-294/*, tools/fixtures/MUBO-558/*, tools/fixtures/SOFT-3139/*, .github/workflows/mp-sessions-slots.yml
CI workflow: mp-sessions-slots.yml

## Sub-features

A verb aimed at a chat that already exists addresses it by tmux or tab name, so it never asks for a host slot: `mp-sessions send`, `list`, `health`, `whoami`, `restart`, `rename`, `move`, `close`, `mp-layout open` on an open tab and `mb` on an open tab.

Creating a tab resolves its server slot in one order: `--host`, the chat's recorded host, `MULTIPROMPT_HOST`, `multiprompt_slot` on this machine's entry in the installed `servers.json`, then the caller's own tab host or its recorded `spawn_host`. With none of those it stops and names the exact file and the field to add.

`mp-sessions start` also runs with the desktop closed. It keeps the keyless helper path: it writes the chat's host configuration, enables and starts the host, and matches `--workspace` against the synced `layout.json` and `chat-names.json` this map already lists. A name in neither file, with a non-empty synced workspace list, stops with `no workspace named <name>`. With the desktop closed it records the workspace on the chat and reports `"visible":false` with `visible_error` `desktop_offline` instead of opening a tab, and a second start reuses the same chat.

Every `servers.json` the repository ships names a slot for each server, and an installed file whose entries carry only `id` and `hostname` still lets an existing chat be messaged.

## How to get to it (user POV)

Nobody opens this from the app. An agent runs `mp-sessions send <chat> <text>` on the server the chats live on, and `mp-layout open --kind shell --tmux <session> --name <title>` to add a shell tab to a workspace. A change to the files above runs the `Multi Bot session verbs and server slots` workflow on GitHub, and the verifier reads its result instead of driving the desktop app.

## Driving it with GitHub CI

One Linux job runs `node --test --test-reporter=tap tools/mp-layout-host.test.js tools/check-servers-slots.test.js` and `python3 tools/mp-sessions-test.py` on the pull request head. It then checks out the base source into a worktree, copies the head test files and the `tools/fixtures/MUBO-294/servers.json` snapshot into it, and runs the same two commands there. Both exit codes and both logs go into `summary.json` as parts `layout` and `sessions`, with `repro` recording the base red and the head green.

On the base, which is master with 1302 reverted, the head tests fail: nothing reads `multiprompt_slot` from the installed servers file, a create with no slot does not name the file and the field, the reverted layout module has no recorded-host reopen, and `mp-sessions start` stops on an offline desktop before it writes the chat. On head the same tests pass. One artifact named `mp-sessions-slots` holds `summary.json` and both logs. The PR selector owns these files through `CI workflow:`, not a nearest desktop name. The verifier waits for this workflow on the exact PR head, requires success, and gives the independent judge its summary and run receipt.

## Gotchas

These are Linux command tests, not a desktop journey: they prove the verbs, the slot order and the shipped servers files, and say nothing about how the Windows window paints. The published sender, `src/mp_send.py`, is covered here too: `tools/mp-sessions-test.py` runs sends through the published tools, so a change to the sender is proven by this workflow rather than by a desktop journey. `server-open-group` and `session-open` still run for desktop import and the real `zsb` session-open path, and both are selected by `src/mp_sessions.py` and `src/mp_layout.mjs`.

Both older-shape snapshots, `tools/fixtures/MUBO-294/servers.json` and `tools/fixtures/SOFT-3139/servers.json`, stay in the guard's exception list, so a shipped file that only models an older install is allowed to lack a slot and a current one is not. The slot guard on its own passes on base because the shipped files were already valid; it fails only when a shipped `servers.json` loses a slot. The live `~/.local/share/vstack/config/servers.json` is fixed by the vstack installer and is not part of this receipt; the code refuses rather than guessing a server when it has no slot.
