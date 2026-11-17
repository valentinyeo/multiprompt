# Rooms

Source files: src/room*, .claude/skills/verify-multiprompt/rooms*

The SOFT-2581 rebuild uses design A, Room as a group-chat tab. This first repair restores keyboard input before rebuilding the layout and membership actions.

## Sub-features

- Create a room and select two sessions. Require exact typed name, two persisted identities, and one new room.
- Send and receive. Require exactly one human message and two ordered, attributed replies.
- Switch rooms and return. Require the saved room identity and complete generated history.
- Close the view for Inbox and reopen. Require unchanged history. This does not exercise membership leave.
- Design A's To switch, reply-status chips, Room menu, membership leave, and confirmed deletion remain unimplemented. No journey here claims those actions passed.

## How to get to it (user POV)

Press Ctrl+Shift+N or choose Ctrl+K **New room**. Type a name, Tab to search, select each session with Enter, then press Ctrl+Enter. Existing rooms appear above sessions and in Ctrl+K. **Edit room** changes the selected room's name and members.

## Driving it with control.ps1

The automatic **Rooms regression** workflow runs the same Windows journey against the PR's master base and candidate. The candidate must pass every exercised step. The master comparison retains failures and evidence without treating them as product acceptance.

```powershell
& .claude/skills/verify-multiprompt/drive.ps1 rooms rooms -Exe $exe -ExpectedVersion $version -ExpectedHash $hash -Evidence $evidence
```

Only run on hosted GitHub Windows. The build enables `-Drooms-preview=true`, as normal development builds omit Rooms. The driver uses SendInput, native foreground and Edit reads, screenshots, saved account state, and read-only SQLite inspection. It never moves focus back on behalf of the product after opening New room.

The fixture generates 12 rooms, 32 candidate sessions, and 1,476 events. The largest history contains 1,201 events. It runs the real account Worker and production RoomStore/RoomBridge methods behind synthetic SSH and agent-runtime boundaries. It does not prove real SSH, real AI timing, authentication, or POSIX storage permissions.

Artifact `verify-rooms-<app-sha>` retains executable provenance, `journey.mp4`, per-step screenshots, `rooms-steps.json`, generated timestamped findings, the final store, and owned-process cleanup. Review the video for layout, labels, attribution, and misleading loading states. A database assertion alone cannot prove those details.

## Gotchas

- Master's typing failure was recorded in PR 1081 at 00:27–00:30. Its foreground remained the hidden console. The native journey now asserts foreground ownership before typing.
- Creation failure blocks fresh send/reply coverage. A blocked step fails the candidate; it is not an independently reproduced send defect.
- Switching assertions cover identity/history, not the known blank-title/loading presentation defect.
- Leave-membership and delete are absent from the current service. Closing to Inbox is not either action.
- Zero remaining owned processes and removed disposable data are required even after failure.
