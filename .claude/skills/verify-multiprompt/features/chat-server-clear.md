# Clear a server chat

## Sub-features

- Type a bare `/clear` in the real server-chat composer.
- Require the production host to replace its agent process and context.
- Keep the existing rendered conversation without a Not sent row or delivery tag.
- Send a follow-up through the real message store and host, then copy its rendered answer.

## How to get to it (user POV)

Open a server chat, type `/clear`, and press Enter. Send another question after clearing.

## Driving it with control.ps1

Run `gh workflow run verify.yml --ref soft-2420-clear-server-chat -f feature=chat-server-clear`.

The workflow selects the existing chat-delivery driver with its server-clear plan. The saved tab has an explicit, stable Claude session ID. The app supplies its embedded reader unchanged. The existing model fixture starts the production host and a synthetic Claude subprocess in an isolated home. Windows adapters provide locking, socket compatibility and a polling message worker. No provider call or real server is used.

The driver uses native keyboard input and bounded state waits, without fixed settling sleeps. It copies the rendered transcript before clearing, after clearing and after the follow-up answer. Independently read host state must show a different agent PID and context. The new subprocess must receive that context in its actual arguments, and the host log must contain a clear event.

Download `verify-chat-server-clear`. Inspect `clear-before.png`, `clear-after.png`, `clear-reply.png`, `server-clear/*-history.txt`, the before/after host state, actual agent arguments, host events, Doctor, actions and cleanup. `tools/chat-server-clear-proof.cjs` rejects unchanged contexts or processes, missing answers, visible delivery tags, Not sent rows and leaked owned processes.

## Gotchas

This proves hosted `/clear`, retained history and the next reply, not Claude-pane passthrough, unsupported arguments, refused-restart notices or badge pixels. Those remain separate reader and desktop contracts. The old chat-slash mode-picker and default chat-delivery cases fail identically on master in run 43722424060; this focused plan does not weaken or replace their assertions.
