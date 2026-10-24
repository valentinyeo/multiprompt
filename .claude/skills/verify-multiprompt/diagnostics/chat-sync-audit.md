# Chat sync audit

Verify missing-message diagnostics without connecting to private sessions or filing tickets.

## Sub-features

- `codex-cloud-browser`: the `codex cloud` task browser is not a chat session and is not audited.
- `progress-banner`: terminal build-progress banners are not treated as chat turns.
- `task-notification`: helper notifications in queue records are not reported as missing conversation.
- `real-message`: actual assistant messages remain auditable, even with the same wording as a notification.
- `running-tool`: running-tool rows are not mistaken for conversation.
- `wrapped-tool-status` (IGSH-620): elapsed-time status lines are excluded even when hard-wrapped; real replies ending in a middle dot remain auditable.
- `wrapped-status-summary` (IGSH-633): live tool-group summaries that wrap over several rows before their elapsed time are excluded; real wrapped replies remain auditable.
- `single-file-tool-status` (IGSH-634): live "<verb>ing <path>…" tool status lines are excluded, also when the path wraps; real replies starting with a path remain auditable.
- `queued-prompt` (IGSH-643): a prompt that is only queued (queue enqueue, not yet delivered) is not reported as missing; once delivered as a queued command and absent from Chat View it is still reported.
- `system-notice`: transcript system notices explain terminal-only text rather than missing messages.
- `unsettled-line`: recheck unmatched lines after a short settling wait before reporting them.
- `background-task-status`: Claude background-command, idle-compaction, monitor and still-running status lines are excluded.
- `wrapped-background-task` (IGSH-735): a background task status row whose quoted command wraps past the pane edge is excluded even when the closing suffix lands on the next row and tmux does not join it; real replies starting with the same words remain auditable.
- `scrollback-above-question`: lines above the newest question in Chat View's first screen load on scroll up and are not reported.
- Existing audit fixtures also cover renderer drift, cold-tail evidence, thinking, tools and pending deliveries.

## How to get to it (user POV)

- The read-only `tools/chat-sync-audit.py --json` command compares live terminal panes with Chat View.
- A missing-message diagnostic should describe conversation, not a terminal progress banner or helper lifecycle notice.
- This verification does not run the live command or its ticket-filing option.

## Driving it with verify.yml

- Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-sync-audit`.
- The dedicated Linux job builds the real audit renderer on GitHub and runs `tools/chat-sync-audit.test.py -v` with synthetic fixtures.
- Require every audit fixture to pass, including the filters and settling rechecks listed above.
- Download `verify-chat-sync-audit`; inspect `fixtures.log`, `renderer-file.txt` (static Linux executable) and match `revision.txt` to the branch commit.
- The server downloads the GitHub-built `chat-audit-linux` artifact into `zig-out/bin/` and makes it executable; it never builds the renderer locally. GitHub uses the baseline host CPU target.

## Gotchas

- This is diagnostic verification, not a Windows desktop journey. It does not claim screenshots, keyboard interaction, live agent delivery or desktop rendering have been exercised.
- The existing desktop journeys are unchanged and still require their full Doctor, input, side-effect and cleanup proof.
- Fixture text and paths are synthetic. Never upload real transcripts or live pane captures.
- Never invoke the ticket-filing option during verification.
