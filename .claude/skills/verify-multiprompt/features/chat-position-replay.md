# Long-chat position replay

Source files: src/chat*, src/main.zig, build.zig, build.zig.zon, src/console.zig, src/focus.zig, src/window_layout.zig, tools/verify-chat-delivery/*, .claude/skills/verify-multiprompt/control-feature-chat-switch-speed.ps1, .claude/skills/verify-multiprompt/control.ps1, .claude/skills/verify-multiprompt/drive.ps1, .claude/skills/verify-multiprompt/seed-profile.*

## Sub-features

- PR 1070's synthetic 64-session profile, eight workspaces and 2,400-message histories with images, tables and code.
- Opening and revisiting five long chats through native session shortcuts.
- Every successful visible chat paint, including unfinished layouts, saved with exact pixels, message identities, bounds and scroll.
- Native console SHOW/HIDE, foreground, parent, location and Z-order events recorded before launch through owned cleanup.
- A hosted long chat left open through idle refreshes, reading old history, a real send, streaming and completion below the reader.
- Native copied transcript receipts and zero surviving owned processes.

## How to get to it (user POV)

Open a long saved session, switch away and return. Scroll into older messages, leave the chat open, send a reply and keep reading while the answer streams below.

## Driving it with control.ps1

Select `feature=chat-position-replay` in the existing reusable Windows workflow. This verification alias enables the paint probe and runs the existing switch driver, then the production-host delivery driver. The original switch-speed benchmark is unchanged.

PR 1067 runs the same scripts automatically against master and head. The independent verifier can select this map itself. No extra dispatch or rerun is needed. Artifacts use `verify-chat-position-replay`; application-compare artifacts append the baseline SHA.

Before either journey, a separate process proves the observer catches a real native console reparented over a test chat window. Its expected failure is saved under `observer-control`. It cannot satisfy the app's failing-master requirement.

Done when both app journeys pass, copied text includes the seed's final answer and the sent/completed reply, and all stable phases preserve message positions. Every recorded paint must have its image. Both `native-console.json` files must pass with complete hook coverage and owned Chat View visibility intervals. `result.json.positionJourneys` must report switch and hosted success. Explicit scrolling and send-triggered scrolling retain their movement records without counting as spontaneous jumps. Console flashes fail regardless of the action's scroll policy.

Before a product fix, master must expose a native console over visible long-chat Chat View under these same scripts. Inspect its event timestamps, console screenshots and desktop video. A fixture timeout, missing evidence or short-chat jump cannot establish this reproduction.

## Gotchas

The runner supports 1920x1080, not the owner's 2560x1600 mode. Video starts before app launch. Paint bitmaps establish chat positions but cannot detect another window covering chat between paints.

The window observer includes child consoles reparented into the app. It retains original SHOW timestamps even when the console is already hidden at callback time. It records bounds, parent, owner, foreground and sibling Z-order. An intersecting console SHOW during an owned visible Chat View interval fails even when no chat paint occurs. Current hidden state or current Z-order cannot erase that historical SHOW. A missing hook, unobserved chat or incomplete journey interval is infrastructure failure, never a product reproduction.

Recording overhead is not a latency benchmark. SSH/provider I/O is synthetic. The app's archive, subscription, layout, input and scroll paths are real. No product fix is claimed until failing-master and passing-head evidence exists.
