# Runner message parity

Desktop counterpart of Android IGSH-1005. Uses the existing chat-delivery boundary: synthetic agent transcript and simulated SSH/tmux, real Windows app history parsing, measurement, drawing and owned native mouse input. Never drive Valentin's desktop.

The public Runner message parity workflow reuses verify.yml. Manual equivalent:

```sh
gh workflow run verify.yml --ref <branch> -f feature=chat-delivery -f chat_notes_proof=true
```

The same driver must first reject the checksum-pinned released v0.28.946 app because five runner notes are not five compact rows. Cleanup must succeed. The current app then shows five dim rows in dark and light, opens the first row using native mouse input, retains its body through an ordinary transcript poll, and folds it with a second native click. Source controls retain the user's question and assistant reply. Expanded links use the production hit-testing contract in test-main; this journey does not launch an external browser.

Inspect all eight notes-<theme>-<state>.png screenshots and the independent pixel probes. Five compact painted labels must occupy at most 180 scaled pixels; expanded body spacing must exceed that span and remain after a source turn/poll. app-cache.jsonl retains all five full source notes. Check actions.json for four owned native clicks, doctor.json for exact app identity, result.json for passed, and cleanup.json for zero owned processes and removed scratch data. No screenshot alone certifies working body links or remote account synchronization.

Use the Android IGSH-1005 native chip screenshots beside desktop: the label is `sender to recipient · TICKET`, with existing dim text and an expansion arrow. Only viewport sizing differs. No Android product change is needed for this desktop parity ticket.
