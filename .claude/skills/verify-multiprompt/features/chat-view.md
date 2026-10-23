# Chat View

Keep the real desktop entry journey separate from the deterministic received-message renderer proof and the [Chat delivery](chat-delivery.md) tmux-channel journey.

## Sub-features

- `local-route-suggestion`: a local console-backed Claude stand-in renders a gray suggested reply with an inverse first character; a normal Chat View send must reach its stdin.
- `local-route-suggestion-attributes`: pure `ISSUE-599` Zig tests accept an inverse cursor at the first input cell followed by a non-default legacy gray foreground; they keep normal typed text, a trailing cursor, mixed text and missing attributes busy.
- `local-route-blank-prompt`: the same regression tests preserve blank and nonbreaking-space prompts even without attribute data.
- `local-route-typed`: normal-attribute draft text, including an inverse cursor after it, keeps a Chat View send queued without writing to stdin.
- `chat-view-toggle`: open, close and reopen the native Chat View with unchanged tab selection.
- `received-markdown-render`: native Windows tests render a synthetic received envelope through the production bubble painter, including a heading, bold text, a list, a table, a link, inline code and a fenced code block, plus separate short list, heading and link bubbles.
- `received-markdown-selection-copy`: native tests check source-coordinate selection and copying rendered text rather than Markdown syntax.
- `pending-message-selection-copy`: native tests check that messages still waiting to send can be selected, selected together with sent messages, and copied, and that the selection survives streamed transcript updates.
- `copy-link`: native tests check that right-clicking a link offers Copy link and copies only that URL, without trailing punctuation.
- `steer-send`: native tests check that Ctrl+X then Ctrl+S in Chat View sends the typed message and then presses Claude's own Ctrl+X Ctrl+S once it is typed, on both the tmux channel and direct input, that an empty composer presses it at once, that a failed paste presses nothing, and that only an adjacent plain Ctrl+X, Ctrl+S chord fires.

## How to get to it (user POV)

- Press Alt+C to switch the active tab between its console and Chat View.
- Ctrl+K, `chat view`, offers the palette alternative; this journey uses Alt+C.
- Received agent messages appear automatically in a real agent conversation, with a blue bubble and a `from` label. No new formatting action is required.
- Select text and use Ctrl+C or the message Copy action to copy visible text.

## Driving it with control.ps1

- Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-view`, watch at 60-second intervals and download `verify-chat-view`.
- For a branch build, the workflow runs the native desktop tests with `MULTIPROMPT_CHAT_RENDER_PROOF=1` and retains `chat-markdown-render.png`. This is a synthetic-envelope image from the actual Windows bubble painter, not a screenshot of live delivery and not app-state seeding.
- The driver starts the normal isolated, empty offline CMD tab. `before.png` shows the console baseline. Before reading saved state, use Ctrl+K, `interface`, Down twice and Enter to persist UI Size: Reset through the app; startup itself need not write session JSON.
- Alt+C opens Chat View. Require the visible `ZigShellChatTranscript` UI Automation control and the app-written active tab's `cv: true`. Capture `action.png` and `session-opened.json`.
- Submit each chord as one ordered SendInput batch so application-injected keys cannot split it. Wait past the app's 1.5-second toggle debounce before each repeated chord. Alt+C closes Chat View. Require `cv` to be absent or false, retain `closed.png` and `session-closed.json`.
- Alt+C reopens Chat View. Require `cv: true`, unchanged active tab and tab count. Capture `after.png` and `session-after.json`.
- The workflow builds `tools/chat-local-agent.c` as `claude.exe`, including on release-tag runs. Launch it by typing its command in two new local CMD tabs; the production process detector must publish Claude (`ag: 1`) before sending. No SSH, tmux, transcript seeding or app-state setters are involved.
- The typed stand-in renders `❯ user draft` with a trailing inverse blank. Send from the owned Chat View composer with Enter, require the app-written outbox entry to remain queued with no write started, and retain `local-route-typed.png`.
- The suggestion stand-in writes `❯ `, SGR 90 gray, SGR 7 on the first suggestion character, SGR 27, SGR 2 on the remainder, then SGR 22 and 39. Require its real console readback to retain the inverse first cell and gray foreground. Send from Chat View with Enter, require the message plus Enter in its stdin recording, and retain `local-route-suggestion.png`. This delivery assertion is RED on the text-only idle check.
- Record both exact names, `local-route-suggestion` and `local-route-typed`, in `result.json` checks, including failed delivery. Recheck the typed tab after the suggestion attempt, even on failure: it must still be queued and its stdin file must contain zero bytes. The other tab's delivery is the positive control; there is no new observation delay. Stand-in readiness JSON preserves actual console characters and attributes, and scratch evidence retains both stdin recordings.
- Inspect the real desktop screenshots and the separate painter image. Require `result.json` to pass, Doctor identity, cleanup, and zero active owned processes. The renderer image must show readable formatting, a blue bubble and `from Agent Blue`, with no envelope tags.

## Gotchas

- For live composer-to-channel delivery, use [Chat delivery](chat-delivery.md). Its production ssh-path override runs the app-supplied reader against fake tmux and a scripted busy or suggested-input screen. It proves that typed text, Enter and steering reach the tmux system boundary, not real Claude consumption, networking, transcript discovery or agent responses.
- No signed-in agent exists on the fresh offline runner. This toggle journey itself still does not verify delivery; `agentBoundary` records that boundary rather than skipping a failed delivery action.
- No signed-in agent exists on the fresh offline runner. Live cross-session delivery and transcript discovery are not verified by this journey; `agentBoundary` records that boundary rather than skipping a failed delivery action.
- The local stand-ins replace only Claude at the console boundary; they do not prove signed-in Claude behavior or cross-session delivery.
- Claude Code 2.1.309's shipped `Ze` placeholder renderer uses `invert(t[0]) + he.dim(t.slice(1))`; `foe` emits SGR 7/27. The bundled ANSI styles map dim to SGR 2/22 and gray to SGR 90/39. The fixture exercises the gray foreground form through actual VT processing, not manually assigned legacy attributes.
- [Microsoft's VT dispatcher](https://github.com/microsoft/terminal/blob/main/src/terminal/adapter/adaptDispatchGraphics.cpp) stores SGR 2 as `Faint`, SGR 90 as bright black and SGR 7 as reverse video. [`GetLegacyAttributes`](https://github.com/microsoft/terminal/blob/main/src/buffer/out/TextAttribute.cpp#L74-L80) does not export faint; [the retained metadata mask](https://github.com/microsoft/terminal/blob/main/src/inc/conattrs.hpp#L7-L10) preserves `COMMON_LVB_REVERSE_VIDEO` (`0x4000`). SGR 90 maps to foreground index 8 (`FOREGROUND_INTENSITY` alone), not the RGB foreground bits.
- The idle check reads attributes at the same trimmed prompt-row column. Nonblank suggestions require the inverse cursor exactly at the first input cell plus a legacy gray foreground different from the separator's foreground. The cursor cell may retain the default foreground. Plain default-color text, even with a cursor moved to its start, stays busy because dim alone cannot be distinguished safely through the legacy API. No send delays, queue policy or other routes change.
- The native painter test uses only synthetic public text and does not write session JSON, agent transcripts, settings or a test-only app setter.
- Release-tag runs exercise the desktop toggle and local console stand-ins; the supplemental painter image is generated only for branch builds.
- Palette entry, theme variants, long-message scrolling and actual browser navigation are outside this selected journey. Link hit coordinates, nested-table scrolling, full-layout find positions, parse reuse and a body longer than a fixed block buffer are covered by regression tests.
