# Server tab after a fresh start

Verify on: push, pull_request

## Sub-features

- Open and send through the same real SSH/tmux setup and large saved-chat seed as `server-chat-busy`.
- Run the actual palette **Fresh start** action. Require a new native provider process and its handover receipt, with the old conversation still readable in the same tab.
- End that chat's host through the production host CLI. Start a replacement chat for the same real tmux pane, and independently prove its seed reached its provider.
- Keep the saved Windows tab untouched. Request Fresh start again and send from that tab. Require the replacement conversation and reply, not the old chat whose owner has ended.
- Retain public and native chat identities, process liveness, saved tab, outbox, provider receipts, screenshots, video and cleanup.

## How to get to it (user POV)

Open the server chat. Choose **Chat View: Fresh start** in Ctrl+K. Keep its tab open while the previous chat ends and a new live chat takes its place in the same server pane. Choose Fresh start and send from the existing tab. It must follow the current chat rather than keep an old chat selected or wait forever for its reply.

## Driving it with control.ps1

The automatic `server-chat-fresh-start` click-through job calls `verify.yml`. Do not dispatch extra runs. `control.ps1` calls `tools/verify-server-chat/drive.ps1 -FreshStart`, using the same runner-owned Windows OpenSSH, WSL Linux OpenSSH server, real tmux, production reader and deterministic paid-provider boundary as `server-chat-busy`.

The ended-owner scenario is explicit. `replace-chat.py` calls the production host CLI to disable the old chat and enable/start a different live chat on the same tmux pane. It does not edit the app's routing, tab, outbox or clock, drop SSH packets, or return a fake host status. This lifecycle setup models the ticket's dead old host and live replacement. Only the paid model process is synthetic.

Both application and server runtime use the selected `app_revision`; the driver and fixture remain identical for master and head. Application changes remain withdrawn until real product failures are captured.

Run `node tools/verify-server-chat/check-evidence.cjs <artifact> --repro` on the failing-master artifact. Admission requires successful open/send and native Fresh start, an ended old owner, a separately proven live replacement in the same tmux pane, a saved tab still pointing at the old public chat, and no delivery to the replacement. It also requires real palette actions, screenshots, video and complete cleanup. Inspect `replacement-fresh-start.png`, `replacement-after.png` and `journey.mp4`; a setup error or ordinary context rotation alone does not prove the Poteto case.

The identical positive check omits `--repro`. It requires the replacement's rendered seed, exactly one composer-message receipt at its current native provider and the painted reply. Inspect `fresh-*.json`, `replacement*.json`, copied transcripts and the video. No live pass is claimed until that artifact exists.

## Gotchas

This case is independent of the busy/Stop journey so a failed Stop cannot prevent the stale-tab observation. The busy journey must still prove both original symptoms. This synthetic-provider case does not establish every paid provider's fresh-start behavior or the separate reported `/rename` keystrokes.

If master follows the replacement, preserve that result and investigate the missing prerequisite. Never change a working result into a claimed reproduction.
