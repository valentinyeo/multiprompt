# Session open

Open an existing remote tmux session as a named background tab through the agent's real `zsb` TCP entry point, without changing the user's selection.

## Sub-features

- `workspace-list`: discover real workspace, custom group and host names without a current tmux session.
- `session-open`: create one manually titled tmux tab in the requested workspace and group, in the background.
- `session-status`: report the tab connection state and the logged exit code after SSH fails.
- `session-open-repeat`: repeat the identical request and prove it returns the existing tab without duplicates or selection changes.

## How to get to it (user POV)

- With an active session, press Ctrl+K, search `move to group`, Enter, search `new group`, Enter. This creates a sidebar group with a default name such as `Group 1` and moves the active tab into it. The app attempts an inline rename, but keyboard focus is not reliable on this path; do not type a name without a focused EDIT control. `Rename group` is a group context-menu action, not a palette command.
- An agent runs `zsb workspace-list`, then `zsb session-open --workspace <workspace name> --group <group name> --host <reported host> --tmux verify-1 --name "Verify 1"`. Names match exactly; the group must already exist.
- Creation is not connection. Run `zsb session-status --tab <returned tab id>`; only `connected` confirms a live attachment. A failed attach returns `disconnected` and `exit_code`.
- The CLI is `tools/vps-multiprompt-browser.sh`. Normally it connects to the reverse tunnel at remote localhost port 19548 (`ZSB_PORT` overrides it). The tunnel leads to the owning app's ephemeral IPv4 loopback listener. This journey connects directly to that same local listener on the runner, not to a mock or private window message.

## Driving it with control.ps1

Preconditions:

- Baseline Doctor passes in single-window offline mode with a live initial CMD tab and app-written `session.json`.
- Use a branch or release containing the workspace bridge commands. No remote credentials, server or tmux session are supplied; SSH attachment is expected to fail.
- The normal tunnel-inbound listener starts even with `MULTIPROMPT_NO_LOGIN=1`. The helper reads its ephemeral port from the isolated app's `debug.log` and requires a listening `127.0.0.1` socket owned by that app PID.

- **Dispatch.** Run `gh workflow run verify.yml -f feature=session-open`; Windows selects `control.ps1 -Feature session-open`.
- **Group.** Follow the keyboard creation path above, then wait for exactly one additional saved group with a nonempty name and the initial active tab assigned to its ID. Identify the new group by excluding the initial group IDs; read its real default name and ID from `session.json` without typing into an unfocused editor or assuming `Group 1`. Record `groupSetup.customNameExercised: false` and the reason in `result.json` and `actions.json`: the custom name path is not exercised. Doctor precedes every keyboard input and bridge request.
- **Discover.** Save the active workspace, active tab, foreground HWND and window titles; capture `before.png`. Send `workspace-list` and require the saved active workspace and named group by both ID and name. Choose a host from the reply, never a hard-coded host.
- **Request.** Capture `action.png` with the named group visible. Send the CLI's exact wire format: `ZSB:workspace:<base64>\n`, with UTF-8 arguments separated by byte `0x1f` and a trailing separator. The helper uses .NET TCP directly so no separate Bash/Python process escapes the app's cleanup job. Require `ok:true`, `created:true` and a positive tab ID.
- **Repeat.** Immediately read the app's saved file with a bounded wait, retaining `session-created.json`. Send the identical request again; require `ok:true`, `existing:true`, the same tab ID and the same workspace name. Retain `session-repeated.json`.
- **Proof.** After creation, repetition and observed SSH failure, require exactly one `tmux_session: "verify-1"`, kind `tmux`, title/name `Verify 1`, the saved group ID and requested workspace. Total tabs increase by exactly one; group identity/count, active workspace, active tab index and its original name/kind remain unchanged. The exact foreground HWND, its title and the main window title must remain unchanged. A missing serialized tab workspace means workspace zero, as in the app's save format.
- **Boundary.** Within 60 seconds require an app log disconnect for the created tab with a known nonzero SSH exit code, excluding `STILL_ACTIVE`. Record the reason, exit code and log match in `result.json` under `sshBoundary`, with remote verification explicitly false. Then send `session-status --tab <created tab id>` once through the same wire path. Require `ok:true`, the created tab ID, state `disconnected` and an `exit_code` equal to the nonzero code in that log match. Save `session-status-failed.request.bin` and `session-status-failed.reply.json` and record the comparison in `result.json`. A missing command, missing field or mismatched code fails the journey; the app without session-status cannot pass. The current app preserves failed SSH/tmux tabs for reconnect; require the saved tab still exists, then capture `after.png` and `session-after.json`.
- **Evidence and cleanup.** Inspect all three screenshots and UIA snapshots, `actions.json`, `workspace-list`, both `session-open` `.request.bin`/`.reply.json` pairs and the `session-status-failed` pair, saved-session snapshots, `result.json` and `data/roaming/ZigShell/session.json`/`debug.log`. Connections have five-second connect/write and 90-second total reply limits plus a 16 MiB cap. Normal job-owned process cleanup and scratch removal still apply, including on failure.

## Gotchas

- This verifies the real local agent request handler and app persistence, not Bash argument validation, a reverse SSH tunnel, successful authentication, remote tmux existence or browser-extension behavior.
- Port 19548 is the remote CLI default, not the app's local inbound port. Do not use the separate notification listener or set an internal port/state value.
- Fresh groups are created through the palette, never by writing session JSON. Group persistence is not proof of rename-editor focus; this journey uses the saved default group name and does not verify custom naming. Workspace display names fall back to `Workspace N` when the saved name is empty.
- Idempotency is keyed by host and tmux session across all workspaces, not by the requested title. Both calls deliberately use the same arguments.
- If a future app removes failed SSH tabs, this preservation check fails rather than silently passing. Retain the immediate `session-created.json` evidence and update the journey's boundary explicitly before relying on a creation-only assertion.
- Screenshots show the unchanged local CMD selection and the background tab in the sidebar, not a working remote shell. A passing static Node contract test is not a Windows journey result; dispatch the workflow and inspect its artifact separately.
