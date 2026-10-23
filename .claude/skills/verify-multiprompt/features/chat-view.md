# Chat View

Keep the real desktop entry journey separate from the deterministic received-message renderer proof and the [Chat delivery](chat-delivery.md) tmux-channel journey.

## Sub-features

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
- For a branch build, the workflow runs the native desktop tests with `MULTIPROMPT_CHAT_RENDER_PROOF=1` twice: `IGSH_610=1` writes `chat-markdown-render.png` using DirectWrite, and `IGSH_610=0` writes `chat-markdown-render-gdi.png` using the previous GDI painter. Both use the same synthetic envelope, dimensions and GDI layout. The job rejects identical painter images and checks that DirectWrite actually drew glyph runs.
- `chrome-reference.png` is installed headless Chrome rendering `chrome-reference.html` with the same first paragraph, bundled IBM Plex Sans Regular/Bold and inline-code font, physical pixel sizes, weights and colours read from the painter. It is a typography reference, not a duplicate of the full transcript layout. The HTML and its exact font files are retained with the images.
- `repaint-ms.json` contains `{gdi_ms, dwrite_ms, n}`: total wall-clock milliseconds for `n=200` warmed repaints of the same synthetic transcript, including a final GDI flush. `chat-render-dwrite.json` and `chat-render-gdi.json` retain geometry, font sizes, colours and actual glyph-run counts. All these files are uploaded in `verify-chat-view` through the existing `evidence/` artifact.
- The painter images come from the actual Windows bubble painter, not a screenshot of live delivery and not app-state seeding. The editable composer remains a native edit control; its custom placeholder and completion text use the same DirectWrite helper. `IGSH_610=0` restores GDI for all routed text.
- The driver starts the normal isolated, empty offline CMD tab. `before.png` shows the console baseline. Before reading saved state, use Ctrl+K, `interface`, Down twice and Enter to persist UI Size: Reset through the app; startup itself need not write session JSON.
- Alt+C opens Chat View. Require the visible `ZigShellChatTranscript` UI Automation control and the app-written active tab's `cv: true`. Capture `action.png` and `session-opened.json`.
- Submit each chord as one ordered SendInput batch so application-injected keys cannot split it. Wait past the app's 1.5-second toggle debounce before each repeated chord. Alt+C closes Chat View. Require `cv` to be absent or false, retain `closed.png` and `session-closed.json`.
- Alt+C reopens Chat View. Require `cv: true`, unchanged active tab and tab count. Capture `after.png` and `session-after.json`.
- Inspect the real desktop screenshots and the separate painter image. Require `result.json` to pass, Doctor identity, cleanup, and zero active owned processes. The renderer image must show readable formatting, a blue bubble and `from Agent Blue`, with no envelope tags.

## Gotchas

- For live composer-to-channel delivery, use [Chat delivery](chat-delivery.md). Its production ssh-path override runs the app-supplied reader against fake tmux and a scripted busy or suggested-input screen. It proves that typed text, Enter and steering reach the tmux system boundary, not real Claude consumption, networking, transcript discovery or agent responses.
- No signed-in agent exists on the fresh offline runner. This toggle journey itself still does not verify delivery; `agentBoundary` records that boundary rather than skipping a failed delivery action.
- The native painter test uses only synthetic public text and does not write session JSON, agent transcripts, settings or a test-only app setter.
- Release-tag runs exercise the desktop toggle only; the supplemental painter image is generated only for branch builds.
- Palette entry, theme variants, long-message scrolling and actual browser navigation are outside this selected journey. Link hit coordinates, nested-table scrolling, full-layout find positions, parse reuse and a body longer than a fixed block buffer are covered by regression tests.
