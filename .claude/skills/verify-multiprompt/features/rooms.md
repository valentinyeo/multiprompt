# Rooms

Source files: src/room*.zig, src/room_service.py, src/room_bridge.py, .claude/skills/verify-multiprompt/control-feature-rooms.ps1, .claude/skills/verify-multiprompt/rooms-*.py

## Sub-features

Create a shared conversation, add two live chats, send to everyone, mention one member, and compare reply order across the room and the members' own chats.

## How to get to it (user POV)

Ctrl+K **New room** (also available as Ctrl+Shift+N), enter a name and create. Ctrl+K **Edit room**, search each member and press Enter to select it, then Ctrl+Enter to save. Open the room by its name in Ctrl+K. Type into its composer and press Enter. Type `@Alpha TARGET534` to address Alpha alone. Open Alpha and Bravo through Ctrl+K to inspect their own Chat Views.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=rooms`. The workflow discovers this file automatically; there is no global pull-request smoke entry. Source mapping selects it for room files and its own driver only. The Rooms build profile uses `-Drooms-preview=true`, matching the shipped release feature without enabling it in other verification builds.

`drive.ps1 -Feature rooms` records the desktop with the existing FFmpeg recorder and delegates through `control.ps1` to `control-feature-rooms.ps1`. Only GitHub-hosted Windows, an isolated profile, the runner-owned account Worker, WSL2 OpenSSH/tmux, FFmpeg and Tesseract are supported. The production account service runs locally with disposable credentials, a runner-only certificate and two seeded saved chats. Initial saved chats and provider commands are fixture setup, not proof of room creation. The driver never seeds a room or sends a room command outside the app.

Before Rooms, send `PRIVATE534` through each chat's real composer and copy its visible reply. Both must pass. The deterministic stream-json provider replaces only paid Claude; Windows input, SSH, production host, connector, room bridge, persistence and transcript loading remain real. No model calls or shared servers are used.

| Step | Action and observable proof |
| --- | --- |
| 1 | Create Rooms534 with no members. Require the named native room view, screenshot/OCR, and exactly one room in the read-only server snapshot. |
| 2 | Edit it, select Alpha and Bravo using real search/Enter, save. Require two active persisted members and the reopened room screenshot. |
| 3 | Send BROADCAST534. Require a cleared composer, one saved human event, and visible message text. |
| 4 | Await both replies. Require exactly two saved agent replies with distinct member IDs, plus both attributed replies visible in the room. |
| 5 | Send @Alpha TARGET534. Require one recipient, one provider input for Alpha, one saved reply from Alpha, visible reply text and no Bravo reply. |
| 6 | Copy both member Chat Views and capture the room. Require every saved room reply in the same order in all three views; retain the comparison, member screenshots, copied text, provider transcripts and ordered room events. |

Each step writes `step-N.png`, `step-N-visible.txt`, `step-N-state.json` and a `result.json` case with PASS / FAIL / UNREACHABLE, symptom and recording-relative seconds. A failure does not stop independent later steps. UNREACHABLE names the missing saved prerequisite; it is not a pass. `driverErrors` distinguishes setup or evidence failures from product assertions. `journey.mp4`, `actions.json`, `doctor.json`, `build.json`, read-only server snapshots and sanitized `data/` survive cleanup in `verify-rooms`. Require six passes, no driver errors, readable video, zero owned app/service processes and removed scratch for a green gate.

Download with `gh run download <id> -n verify-rooms -D <directory>`. Inspect the screenshots as images and the recording, not just OCR. Timestamps in the cases use the child's clock, which starts just after the outer recorder; use the screenshots to locate the exact frame.

## Gotchas

- Room text is custom-painted and has no copy-all action. Tesseract reads actual desktop screenshots; saved room events independently prove what persisted. OCR failures need visual review before being called product bugs.
- Display names and the app's generated mention aliases are different. This journey deliberately checks the requested `@<name>` user path; do not replace it with a private generated ID to hide a failed name mention.
- A failed broadcast reply does not prevent testing a targeted send or opening both member views. No reply order can be proven when no replies exist; report that missing prerequisite explicitly.
- This proves one desktop plus both member chat views and saved server state, not a second authenticated physical desktop or Android.
- The journey is allowed to fail on master. Do not add it to unrelated PR smoke gates or change product code to make this verification PR green.
