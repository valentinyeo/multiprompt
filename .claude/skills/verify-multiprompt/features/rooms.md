# Rooms

Source files: src/room*, src/roster*, src/main.zig, src/command_palette.zig, src/shortcuts.zig, build.zig, build.zig.zon, .claude/skills/verify-multiprompt/rooms*

This is a verification-first audit for SOFT-2581. It records broken and confusing actions for the wireframe and rebuild. A completed audit does not mean Rooms works.

## Sub-features

| Action | Person's route | Observable proof |
| --- | --- | --- |
| Create a room | Ctrl+Shift+N opens New room. Type its name. | An owned visible Rooms dialog accepts the exact name. Saving creates one new room ID. |
| Add agents | Tab to Search agents. Find and select each agent with Enter. Ctrl+Enter confirms. | The persisted new room has exactly the two selected agent identities. Capture the selected count before confirmation. |
| Send a message | Type into the room composer and press Enter. | Exactly one human event contains the sent text. The visible composer and resulting message are captured. |
| See replies in order | Stay in the room while both agents reply. | Two distinct member IDs reply to the same human event, once each, in increasing sequence. Review the video and reply screenshot for visible order and attribution. Backend order alone is insufficient. |
| Switch rooms | Ctrl+K, search each exact room name, Enter. Return to the first room. | Both different room histories appear, and the original room ID is selected on return. The large history has 1,201 events. Inspect screenshots for truncation, wrong selection, and confusing focus. |
| Leave or close | Ctrl+Shift+I leaves the room for Inbox. Reopen by room name. | The room view hides. Returning preserves the room ID and all 1,201 seeded events. This leaves the view, not membership. No dedicated leave-membership or delete-room operation exists in the current Rooms service. Record that distinction as a design gap, not an exercised deletion. |

## How to get to it (user POV)

Normal releases include Rooms. Build flag `rooms-preview` defaults to the release flag in `build.zig`. The standard development build disables Rooms, so this audit explicitly builds with `-Drooms-preview=true`. No product source is changed. New room is also available in Ctrl+K. Existing rooms appear under Rooms in the sidebar and by name in Ctrl+K. **Edit room** changes the name and members of the selected room.

## Driving it with control.ps1

The PR's automatic **Rooms master audit** calls `verify.yml` with `feature=rooms`, the PR harness revision, and the exact master commit captured by its event as `app_revision`. Do not manually dispatch or rerun workflows for this task. The independent PR verifier can select `rooms` to run the same audit against head.

Workflow entry:

```powershell
& .claude/skills/verify-multiprompt/drive.ps1 rooms rooms -Exe "$pwd/verify-bin/multiprompt.exe" -ExpectedVersion $env:VERIFY_VERSION -ExpectedHash $env:VERIFY_SHA256 -Evidence "$pwd/evidence"
```

`control.ps1` delegates to `rooms.ps1`. Only execute on a fresh GitHub Windows runner. The journey uses real SendInput, read-only native window identity, UI Automation, native Edit reads, screenshots, and the app's published files. It never sends private window messages or changes product state after launch.

Before launch, `rooms-fixture.py seed` generates 12 rooms, 32 saved candidate agents, and 1,476 events. The largest room contains 400 human messages and 800 replies with generated paragraphs, fenced code, and tables. Only generated text is used. This is a disclosed representative stress size, not a claim that it matches Valentin's private database distribution.

The account fixture reuses `service/journey/server.mjs`, the real account Worker, and private local D1. Its disposable HTTPS certificate and hostname mapping are removed in cleanup. Account layout is seeded through the public layout API before launch. Cached provider identities are seeded once in the private saved-session file. The SSH executable boundary reuses the existing launcher. It executes the embedded production RoomStore and RoomBridge methods, replacing only the POSIX SQLite opener and external agent runtime. No real SSH, paid model, account login, POSIX file permissions, or real-agent timing is verified. Never call a synthetic reply proof live-agent proof.

`rooms-fixture-test.py` exercises create, retry, send, ordered replies, and no duplicate replies through the embedded real bridge. The workflow runs it before desktop launch. These focused fixture tests do not replace the native journey.

### Evidence and interpretation

Artifact `verify-rooms-<app-sha>` contains `build.json` with both harness and master executable revision, `journey.mp4`, `journey.json`, `video.json`, and normal Doctor and cleanup evidence. `rooms-steps.json` records all six actions with start and end UTC timestamps, status, error, and screenshot. `rooms-steps.json` is written after each action, so a later failure does not erase earlier observations.

Use `recording-start.json` to convert each step timestamp into video offset. `rooms-findings.md` gives the generated timestamped findings list. Review the video yourself and add confusing behavior to the PR body with its video timestamp. An infrastructure failure is not a Rooms bug. A blocked action is not an independently reproduced defect. Missing screenshots are missing coverage, never a pass.

`result.json.status=passed` means the audit completed and preserved evidence. `productPassed` and each action's status report the product result separately. Do not use the audit's exit code as permission to rebuild or ship. A complete audit needs six step records, readable video, actual master provenance, and zero remaining owned processes. Screenshot review is required even when all persisted assertions pass.

## Gotchas

- Failure of create or add-agents blocks send and replies. The journey still attempts switching seeded rooms and leaving, without fabricating an empty successful conversation.
- Agent selection, visible reply order, long-history rendering, and affordance clarity require video review. The custom-painted room transcript does not expose its text through UI Automation.
- Ctrl+W is not a documented leave-room action. Do not close a private chat and label it leaving a room.
- Delete-room and leave-membership are absent from the current service operations. The wireframe must settle their meaning before product changes.
- No product repair or wireframe is included in this PR. The audit findings are the rebuild's bug list.
