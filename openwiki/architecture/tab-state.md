# Tab state

One `TabState` record describes a tab, including a closed tab. The desktop owns it. Shell windows, saved layout, account layout and the PC-state view are projections of this record, not independent placement records. `mp-sessions` and `mb` request changes through the desktop bridge.

| Field | Meaning and writer |
| --- | --- |
| `host`, `user` | Host target and remote user. Desktop resolves them at creation; only an explicit move may change them. |
| `workspace`, `group`, `position` | Workspace name, nullable group name and zero-based position within that workspace. Desktop applies moves and reports actual placement. |
| `kind`, `sid` | `chat` or `shell`, and nullable chat session id. Desktop owns identity; restart retains both and restores a chat as chat. |
| `pinned`, `archived`, `waiting`, `closed` | Explicit desired flags. Palette and CLI use the same desktop state. Close retains the record and its placement; only open or restore clears `closed`. |
| `visible`, `hidden_reason` | Desktop-only observations, never client requests. `visible` means a sidebar row is currently shown. Hidden reason is null or the first applicable reason: closed, archived, waiting, workspace, group, filter. |

The record also carries its stable terminal-session key (`tmux`) and display `name`. `(host, tmux)` identifies it. A record's revision is checked before applying a command. The PC-state view includes closed records and their last placement; an offline desktop is not an empty layout.

## Apply and acknowledge

1. Read PC-state from the connected desktop. Resolve one record, not a guessed host or front workspace.
2. Send a verb and expected record to the desktop. Validate identity, destination, capacity and all refusal conditions before changing anything. Verbs set values, never toggle. A second identical request is a no-op.
3. Apply on the UI thread, persist through the existing session/layout path, then return the same PC-state record. CLI reads PC-state again and compares the requested fields and preserved identity before reporting success. Refused or offline operations never edit account layout, host configuration or ownership files.
4. Restart uses the retained record, prepares the desktop first, restarts the existing reader session in place and verifies the chat tab. It never falls back to the front workspace. Reader configuration contains provider/runtime information, not a second tab-placement record.

## Conflicts and compatibility

The desktop serializes UI and CLI writes. An expected-state mismatch refuses without changes; callers reread and retry deliberately. Account sync may update a live record but cannot clear a close tombstone. Only an explicit open/restore can do that. Visibility always comes from the current desktop, never account sync or process health. If an acknowledgement is lost, report failure and reconcile with PC-state on retry; do not claim that a distributed timeout proves rollback.

Old clients may read the existing layout fields. New clients require the tab-state bridge and refuse to mutate through an older desktop. Android can keep reading portable layout fields; paired Android support must consume the optional tab-state record before offering these verbs.

## Implementation order

- Commit this contract before implementation, then merge SOFT-3131, SOFT-3130 and SOFT-3134/3140 without rebasing.
- Use a desktop-owned record rather than account-first asynchronous edits: only the desktop can acknowledge real visibility and refuse before a write.
- Add the PC-state protocol and one verb, fixtures and a failing hosted regression; push and open the PR immediately.
- Add the other verbs through the same state transition path, replace placement/health guesses, and preserve palette/shortcut rows.
- Refresh upstream branches before the PR and before final verification. Run unit and Windows builds on GitHub-hosted runners; the Verification team owns the per-verb Windows journeys.

Blocking work is the shared model and bridge. CLI adapters and fixtures follow that protocol. Shared record writes stay on the desktop UI thread; no parallel writer or implementation worker is needed for this coupled change.
