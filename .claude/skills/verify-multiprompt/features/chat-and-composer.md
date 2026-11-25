# Chat view and composer

Read conversations, compose replies, attach files, search, dictate, and switch supported terminal tabs between chat and shell.

Journeys: chat-focus, chat-view, chat-composer-text, chat-still
Release paths: src/chat*, src/agent*.zig, src/live*.zig, src/terminal*, src/skills*, src/voice*.zig, src/main.zig, src/app_state.zig, build.zig

## Sub-features
- `read` displays history, Find matches, selection, copied text, and unread boundaries.
- `compose` retains drafts and sends replies, reactions, attachments, and dictated text.
- `view-focus` switches supported terminal views and restores typing focus.

## How to get to it (user POV)
- Select a chat; type in its message box; Enter sends and Shift+Enter adds a line; Ctrl+F finds; Ctrl+D dictates; plus/paste/drop attaches; right-click replies/reacts; Alt+C switches terminal views.

## Driving it with drive.ps1
Preconditions: fresh hosted Windows desktop, matching executable/hash/version, isolated app data, and the selected legacy recipe’s prerequisites.
- The shared wrapper accepts these Journeys; automatic workflow migration remains partial. Run `gh workflow run verify.yml --ref <branch> -f feature=chat-focus`. [Chat focus](chat-focus.md), [Chat View](chat-view.md), and [composer text](chat-composer-text.md) provide exact key sequences and native text reads.
- Require typed draft equality, visible transcript/composer screenshots, saved tab/view state; received conversation text requires its own journey, and the named journey result. Only the selected journey is covered. Download `verify-chat-focus` after cleanup. This legacy workflow route does not yet use the video driver; see [inventory](../inventory.md).

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### read: Read, find, select and copy

Open a transcript with known Unicode, code, links and wide tables. Find exact text; move forward/backward through matches and close Find. Select in both directions, select all with transcript focus and copy, copy the latest code block, expand a table and scroll it. Navigate messages by keyboard, then type to return to the box.

Observable proof: Copied text equals the source including backslashes, accents and early/late messages. Find selects the correct match. Table expansion reveals the rightmost cell without changing draft or conversation scroll. Selection-menu Enter adds the chosen text without sending.

Journey: chat-view, chat-tables, chat-code-font, chat-newest. UNREACHABLE for every Unicode/search/selection/expand variant until the native driver exposes these exact inputs and clipboard/position assertions; painter checks alone do not prove them.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CHAT_COPY_CODE_OFFSET` | Ctrl+K, type **copy latest code block**, then select the matching action with Up/Down and Enter. Follow `read` above. |
| `SEARCH_CHAT_COPY_SELECTION_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_EXPAND_TABLE_OFFSET` | Ctrl+K, type **expand table**, then select the matching action with Up/Down and Enter. Follow `read` above. |
| `SEARCH_CHAT_FIND_OFFSET` | Ctrl+K, type **find in conversation**, then select the matching action with Up/Down and Enter. Follow `read` above. |
| `SEARCH_CHAT_FOCUS_MESSAGES_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_SELECTION_MENU_OFFSET` | Ctrl+K, type **add selection to chat**, then select the matching action with Up/Down and Enter. Follow `read` above. |
| `SEARCH_CHAT_SELECT_ALL_OFFSET` | Ctrl+K, type **select all text**, then select the matching action with Up/Down and Enter. Follow `read` above. |
| `SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET` | Ctrl+K, type **chat view on everywhere**, then select the matching action with Up/Down and Enter. Follow `read` above. |
| `SEARCH_CHAT_VIEW_MODE_NOWHERE_OFFSET` | Ctrl+K, type **chat view off everywhere**, then select the matching action with Up/Down and Enter. Follow `read` above. |
| `SEARCH_CHAT_VIEW_OFFSET` | Ctrl+K, type **switch to chat view**, then select the matching action with Up/Down and Enter. Follow `read` above. |
| `SEARCH_TABCTX_CHAT_VIEW` | Right-click the intended tab, then choose **chat view live chat switch to terminal alt c**. Follow `read` above. |

### quote: Quotes, reactions and presentation

Right-click a known agent message and Reply; remove the quote with x and Escape on an empty draft. React through the menu and double-click; toggle it off. Open/fold tool steps, todo and CLEAN presentation without changing underlying transcript data. Open Plus and More, choose a row and dismiss without losing the draft.

Observable proof: Quote refers to the intended source and never sends on cancellation. One reaction badge matches one host submission; removal remains removed after restart. Presentation toggles affect only their intended rows and retain all source text.

Journey: chat-double-click, chat-messages-only, chat-options, composer-buttons. UNREACHABLE for every quote/menu/todo/tool variant until the driver opens those native controls and reads exact source IDs; synthetic model/permission menus do not imply all More/Plus rows passed.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CHAT_MORE_MENU_OFFSET` | Ctrl+K, type **more menu**, then select the matching action with Up/Down and Enter. Follow `quote` above. |
| `SEARCH_CHAT_PLUS_MENU_OFFSET` | Ctrl+K, type **plus menu**, then select the matching action with Up/Down and Enter. Follow `quote` above. |
| `SEARCH_CHAT_REACT_DISLIKE_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_REACT_HEART_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_REACT_LIKE_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_REPLY_OFFSET` | Ctrl+K, search for **Chat View: Reply to latest agent message**. Follow `quote` above. |
| `SEARCH_CHAT_TODO_OFFSET` | Ctrl+K, search for **Chat View: Toggle todo list**. Follow `quote` above. |
| `SEARCH_CHAT_TOOL_STEPS_OFFSET` | Ctrl+K, type **open or fold all tool steps**, then select the matching action with Up/Down and Enter. Follow `quote` above. |
| `SEARCH_CLEAN_CHAT_OFFSET` | Ctrl+K, type **clean chat**, then select the matching action with Up/Down and Enter. Follow `quote` above. |

### attach: Attach, paste and upload

Use a disposable text file and image. Attach through plus/file picker, paste and drop onto the composer; put the caret between two markers first. Cancel a file dialog, then upload with a controlled slow receiver and a stalled receiver.

Observable proof: The receiving session has identical file bytes and the inserted path/link appears exactly at the caret without sending. Progress prevents idle timeout; an actual stall times out visibly and retains the draft. Cancel changes no remote file.

UNREACHABLE until Part B exposes a real upload receiver, image link endpoint and host-file inspection, and the native driver supplies picker/paste/drop plus stalled-progress assertions. Selecting a filename alone is not transfer proof.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CHAT_ATTACH_OFFSET` | Ctrl+K, type **attach file**, then select the matching action with Up/Down and Enter. Follow `attach` above. |

### skills: Commands, skills, model and permissions

Open slash suggestions, Ctrl+/ and Skills from Ctrl+K; choose a known skill, cancel another, and try an unknown command. In Codex also use dollar-prefixed skills. In a live chat use the Plus menu to choose model/effort and Plan/Ask/Accept edits/Bypass. For Pi, list models and choose a provider-qualified model; invoke /login separately. Answer real permission cards with 1/2/3 and Alt+Y/O/D.

Observable proof: The selected session receives the exact command once. Unsupported commands remain editable and never enter the outbox. Model/provider/effort and permission receipts match the menu, preserving draft/history. Each permission reply targets only its pending request.

Journey: chat-model, chat-slash, chat-skill-pill, permission-rows. UNREACHABLE for real providers, Pi login/model catalogue and filesystem skills until Part B has authenticated provider CLIs with discoverable skills/models and the driver asserts those receipts. SOFT-2563 owns Pi provider propagation.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CHAT_AC_OFFSET` | Ctrl+K, type **insert command or skill**, then select the matching action with Up/Down and Enter. Follow `skills` above. |
| `SEARCH_CHAT_ALLOW_OFFSET` | Ctrl+K, search for **chat view allow**. Follow `skills` above. |
| `SEARCH_CHAT_ALWAYS_OFFSET` | Ctrl+K, search for **chat view always allow**. Follow `skills` above. |
| `SEARCH_CHAT_DENY_OFFSET` | Ctrl+K, search for **chat view deny**. Follow `skills` above. |
| `SEARCH_CHAT_EFFORT_HIGH_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_EFFORT_LOW_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_EFFORT_MEDIUM_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_MODEL_ASTRA_OFFSET` | Ctrl+K, search for **chat view: model astra**. Follow `skills` above. |
| `SEARCH_CHAT_MODEL_FABLE_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_MODEL_HAIKU_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_MODEL_LUNA_OFFSET` | Ctrl+K, search for **chat view: model luna**. Follow `skills` above. |
| `SEARCH_CHAT_MODEL_OPUS_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_MODEL_SOL_OFFSET` | Ctrl+K, search for **chat view: model sol**. Follow `skills` above. |
| `SEARCH_CHAT_MODEL_SONNET_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_CHAT_MODEL_TERRA_OFFSET` | Ctrl+K, search for **chat view: model terra**. Follow `skills` above. |
| `SEARCH_CHAT_MODE_BYPASS_OFFSET` | Ctrl+K, search for **chat permission mode: bypass**. Follow `skills` above. |
| `SEARCH_CHAT_MODE_EDITS_OFFSET` | Ctrl+K, search for **chat permission mode: accept edits**. Follow `skills` above. |
| `SEARCH_CHAT_MODE_MANUAL_OFFSET` | Ctrl+K, search for **chat permission mode: ask**. Follow `skills` above. |
| `SEARCH_CHAT_MODE_PLAN_OFFSET` | Ctrl+K, search for **chat permission mode: plan**. Follow `skills` above. |
| `SEARCH_PI_LOGIN_OFFSET` | Ctrl+K, type **log in**, then select the matching action with Up/Down and Enter. Follow `skills` above. |
| `SEARCH_PI_MODELS_BACK_OFFSET` | Open the named submenu, then choose **Back**. Follow `skills` above. |
| `SEARCH_PI_MODELS_MENU_OFFSET` | Ctrl+K, type **pi model**, then select the matching action with Up/Down and Enter. Follow `skills` above. |
| `SEARCH_PI_MODEL_ROW_OFFSET` | In a Pi chat, open **Pi Model** or /model, then choose the displayed model/provider pair. Follow `skills` above. |
| `SEARCH_SKILLS_BACK_OFFSET` | Open the named submenu, then choose **back**. Follow `skills` above. |
| `SEARCH_SKILLS_MENU_OFFSET` | Ctrl+K, search for **skills**. Follow `skills` above. |
| `SEARCH_SKILL_ROW_OFFSET` | Open Ctrl+K **Skills**, then select the discovered /skill name. Follow `skills` above. |
| `SEARCH_TABCTX_CHAT_ALLOW` | Right-click the intended tab, then choose **chat view allow**. Follow `skills` above. |
| `SEARCH_TABCTX_CHAT_ALWAYS` | Right-click the intended tab, then choose **chat view always allow**. Follow `skills` above. |
| `SEARCH_TABCTX_CHAT_DENY` | Right-click the intended tab, then choose **chat view deny**. Follow `skills` above. |

### lifecycle: Reset, resync, fresh start and switch AI

Use separate disposable chats for Reset this chat, Resync chat, Fresh start and Switch AI to Claude/Codex/Pi. Keep an unsent marker. Observe a busy chat before requesting newest-version restart and restart-every-idle-live-chat; wait for the reply to end. Restart a stopped AI separately.

Observable proof: Reset/resync retain the exact unsent draft and never resend old messages. Fresh start and AI switch preserve name, photo, address and readable history while the new provider receives the handover. Deferred restart runs once after the current turn, not during it.

Switch AI (`SEARCH_CHAT_SWITCH_*` and tab-context Switch AI rows) needs public GitHub-hosted proof. Do not run `.claude/skills/verify-multiprompt/switch-ai-live.py` on a shared server or a user's computer. That script is not wired to a hosted workflow and does not drive the Windows UI.

The deterministic `server-chat` journey exercises real Windows OpenSSH, WSL Linux OpenSSH, tmux, and the production host with a deterministic provider. For real Pi `openai-codex/gpt-6.1-sol` fallback proof, dispatch `gh workflow run verify.yml --ref <branch> -f feature=server-chat-real-pi`. That mode converts `CODEX_AUTH_JSON` fail-closed on the runner into Pi's OAuth format without logging secrets, installs pinned Pi 1.5.0, Codex, and pinned `valentinyeo/vstack` (`valentin-mode` + `responsive-mode`), disables auto-switch through the real UI, selects `openai-codex/gpt-6.1-sol` through Pi Model with RPC acknowledgement, proves real replies, `/valentin-mode` skill body hash and version provenance, marker recall separately from ordered stored and copied/screenshot history, and a Pi-to-Codex-to-Pi roundtrip with an independent other-family verifier job. Claude and Antigravity return hops remain unsupported until approved runner credentials exist.

Reset, resync, fresh start, and deferred restart journeys remain UNREACHABLE until native driver controls exist for each path.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_CHAT_FRESH_START_OFFSET` | Ctrl+K, type **fresh start**, then select the matching action with Up/Down and Enter. Follow `lifecycle` above. |
| `SEARCH_CHAT_RESET_OFFSET` | Ctrl+K, type **reset this chat**, then select the matching action with Up/Down and Enter. Follow `lifecycle` above. |
| `SEARCH_CHAT_RESTART_ALL_OFFSET` | Ctrl+K, type **restart every idle live chat**, then select the matching action with Up/Down and Enter. Follow `lifecycle` above. |
| `SEARCH_CHAT_RESTART_OFFSET` | Ctrl+K, type **restart this chat**, then select the matching action with Up/Down and Enter. Follow `lifecycle` above. |
| `SEARCH_CHAT_RESYNC_OFFSET` | Ctrl+K, type **resync chat**, then select the matching action with Up/Down and Enter. Follow `lifecycle` above. |
| `SEARCH_CHAT_SWITCH_CLAUDE_OFFSET` | Ctrl+K, type **switch ai to claude**, then select the matching action with Up/Down and Enter. Follow `lifecycle` above. |
| `SEARCH_CHAT_SWITCH_CODEX_OFFSET` | Ctrl+K, type **switch ai to codex**, then select the matching action with Up/Down and Enter. Follow `lifecycle` above. |
| `SEARCH_CHAT_SWITCH_PI_OFFSET` | Ctrl+K, type **switch ai to pi**, then select the matching action with Up/Down and Enter. Follow `lifecycle` above. |
| `SEARCH_TABCTX_ADOPT_HOST` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_TABCTX_CHAT_RESET` | Right-click the intended tab, then choose **chat view reset this chat clear bubbles cache**. Follow `lifecycle` above. |
| `SEARCH_TABCTX_CHAT_RESTART_AI` | Right-click the intended tab, then choose **chat view restart the ai agent stopped claude resume**. Follow `lifecycle` above. |
| `SEARCH_TABCTX_FRESH_START` | Right-click the intended tab, then choose **Fresh start handover clear context same chat picture address**. Follow `lifecycle` above. |
| `SEARCH_TABCTX_SWITCH_CLAUDE` | Right-click the intended tab, then choose **Switch AI to Claude keep chat name picture address history**. Follow `lifecycle` above. |
| `SEARCH_TABCTX_SWITCH_CODEX` | Right-click the intended tab, then choose **Switch AI to Codex keep chat name picture address history**. Follow `lifecycle` above. |
| `SEARCH_TABCTX_SWITCH_PI` | Right-click the intended tab, then choose **Switch AI to Pi keep chat name picture address history**. Follow `lifecycle` above. |

## Gotchas
- Live chats have no shell toggle. Sending, attachments, provider login, and real delivery need their own live prerequisites; focus proof does not cover them.
