# Rooms

Source files: src/main.zig, src/sidebar.zig, src/command_palette.zig, src/shortcuts.zig, src/app_state.zig, src/dialog.zig, src/room*, .claude/skills/verify-multiprompt/rooms*

SOFT-2581 uses approved [variant A](https://multibot-rooms-proto.pages.dev/). Each Room is a sidebar group containing real session rows, followed by New room. Existing session rows, composer chips, themed menus, and confirmation overlays provide the controls.

## Sub-features

- Create a Room with Ctrl+Shift+N or New room. Type a name, select sessions, and confirm. Require the exact name, two persisted identities, and one new Room.
- Send using To: Everyone or one session. The chip selects recipients without changing message text. Require one stored message and exactly the chosen deliveries.
- Read Replied, Working, Queued, and Not asked yet from stored replies and delivery progress. Per-message chips identify the sessions asked. Never infer a reply from online presence.
- Switch between Rooms and return. Require the selected title while loading, the same saved Room ID, and complete generated history. Loading is not an empty conversation or Action unavailable.
- Open Room menu to add/remove sessions or rename. Existing membership editing preserves earlier messages.
- Leave hides the Room in this app profile, without deleting it or stopping its sessions. Undo leave room restores it. Hidden Rooms remain hidden after restart.
- Delete asks first, with Cancel selected. Cancel and Escape preserve the Room. Confirm removes that Room's history and saved command text, preserving other Rooms and sessions. Retrying the same deletion cannot recreate the Room.

## How to get to it (user POV)

Rooms appear above ordinary sessions. Click a Room heading for its conversation, or a member row for that actual session. Click New room or press Ctrl+Shift+N. Click the Room title for its menu. Click To: in the message box to select everyone or one session. All actions also have Ctrl+K rows.

## Driving it with control.ps1

The automatic **Rooms regression** workflow runs the same Windows journey against the PR's master base and candidate. Failed or blocked exercised steps fail the candidate. Master failures remain recorded as the negative comparison.

```powershell
& .claude/skills/verify-multiprompt/drive.ps1 rooms rooms -Exe $exe -ExpectedVersion $version -ExpectedHash $hash -Evidence $evidence
```

Run only on hosted GitHub Windows. The build enables `-Drooms-preview=true`. The driver uses SendInput, native foreground and Edit reads, screenshots, saved profile state, and read-only SQLite inspection. It does not repair product focus after opening New room.

The fixture generates 12 Rooms, 32 candidate sessions, and 1,476 events. The largest history has 1,201 events. The real account Worker and production RoomStore/RoomBridge run behind disclosed synthetic SSH and agent-runtime boundaries. This does not prove real SSH, real AI timing, authentication, or POSIX file permissions.

The initial creation/add/send/reply steps retain the typing regression. Switching requires the native selected title. Independent To, leave/undo, and delete/cancel steps start from seeded Rooms even when creation fails. The real-session-row step clicks the first member row using the default sidebar geometry, then requires that actual published session ID and a hidden Room view. Each step records its own failure. `rooms-steps.json`, timestamped findings, screenshots, and `journey.mp4` remain after owned-process cleanup. Review sidebar rows and status chips in the video; database assertions alone do not prove their appearance.

The independent `send-while-away` step sends to a seeded Room, switches to Inbox before the receipt returns, and requires both replies without reopening it. The synthetic transport holds that receipt for two seconds and agent completion for five seconds. The product dispatches accepted posts immediately and uses bounded pending-reply reads while the conversation is hidden. This is not proof of real-agent timing.

### recipients

Open the seeded Room, choose **Room recipients**, then Home, Down, Enter to target its first session. Send ordinary text and require one delivery. Choose recipients again, Home then Enter for Everyone, and require two deliveries even when the message contains an at sign.

### leave and undo

Open a seeded Room and choose **Leave room**. Require the Room hidden and its profile preference saved. Choose **Undo leave room**. Require the same Room ID, members and history restored.

### delete confirmation

Open a disposable seeded Room and choose **Delete room**. Capture the overlay and press Escape. Require the Room unchanged. Open deletion again, press Right then Enter, and require only that Room removed while all session rows remain.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_ROOM_TO_OFFSET` | Ctrl+K **Room recipients** opens To:. Select Everyone or one session, then send ordinary text. Require matching deliveries in `to-one-and-everyone`. Follow `recipients` above. |
| `SEARCH_ROOM_LEAVE_OFFSET` | Ctrl+K **Leave room** hides the selected Room. Require saved hidden state and unchanged sessions/history in `leave-and-undo`. Follow `leave and undo` above. |
| `SEARCH_ROOM_UNDO_LEAVE_OFFSET` | Ctrl+K **Undo leave room** restores the same Room in `leave-and-undo`. Follow `leave and undo` above. |
| `SEARCH_ROOM_DELETE_OFFSET` | Ctrl+K **Delete room** opens the shared confirmation. Escape cancels; Right then Enter confirms. Require only the intended Room removed in `delete-confirmation`. Follow `delete confirmation` above. |

## Gotchas

- Creation failure blocks its dependent send/reply steps. The independent To journey still exercises a seeded Room. A blocked step is not a reproduced send defect.
- Leave is a reversible profile preference, not deletion or removal of an agent. It does not sync across devices.
- An old client can still use mention-based routing. The desktop To chip uses explicit recipients. To: Everyone sends to everyone even when text contains an at sign.
- The master typing failure was recorded in PR 1081 at 00:27–00:30. This PR preserves that repair and requires foreground ownership before typing.
- No screenshot, native-build result, or independent verdict has been accepted merely because portable checks pass.
