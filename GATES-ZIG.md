Gates for IGSH-2314 Zig send path (untracked, never committed)

1. Capabilities: send room_messages 1, accept live_send true or false, remember per controller, submit unsupported when false, store_only hosts unchanged.
2. Real submit: validate room, revision, text; parse mentions exactly like Python; unknown or empty alias fails with no send; post_human body and receipt.
3. Journal kind post: same command_id retried after restart; validateRequest and evidence shapes; pending post blocks create and edit.
4. After accepted post: refresh events; poll on a timer while the room is visible and selected and a recent post or an unanswered human event exists; no busy loop; timer killed on hide, leave, deinit.
5. Draft clears only on accepted; kept on failed.
6. Harnesses in tools grep checked and updated.
7. Zig test blocks for mention parser and post journal round trip, no comments.
8. No shortcut or palette row, no version bump, smallest diff.

Evidence is filled in the final report.
