# Messages only

## Sub-features

- Tool/activity blocks never paint ticks, summaries, details, diffs or images and reserve no height or surrounding gap.
- The transcript cache still contains all twelve completed calls and results, including the three reported app-smoke/status summaries.
- Real message rectangles and pixels stay unchanged when those calls stream in. The existing composer draft remains editable and unchanged.
- A centered compact pill above the composer counts new messages that arrive while the reader is scrolled up, with a down arrow, the full count and a separate close control. It reserves its own row outside the transcript, above the working/permission row.
- Only new transcript message starts count. Initial loads, older pages, repeated refreshes, streamed continuations, Markdown blocks and tool activity never count.
- Ordinary scrolling retains the count until the existing bottom threshold is reached. Reaching bottom clears it; clicking the pill follows the existing End-key scroll path and clears it; close hides the pill without clearing the counter. There is no setting, flag, shortcut or palette command.
- Native layout regressions cover leading, interleaved and trailing tools, all statuses, expanded details/diffs, incremental layout reuse, message copying, scroll coordinates and unchanged source data.

## How to get to it (user POV)

Open a conversation in Chat View with Alt+C. Assistant messages remain; tool activity does not appear. Scroll up and let messages arrive to see the unread pill above the composer; click it to jump to the newest message or its close control to dismiss it. The unread pill has no setting of its own.

IGSH-816 adds the CLEAN chat view option: the Ctrl+K entry `Chat View: Toggle CLEAN chat` hides read receipts, outbox status rows (including "Queued in Claude" chips), the status footer and empty/history status lines, so only message bubbles and the working indicator remain. It is off by default, persists across restarts, has no keyboard shortcut, and leaves the view unchanged when off.

## Driving it with control.ps1

- Dispatch exactly `gh workflow run verify.yml --ref ceo/IGSH-813 -f feature=chat-messages-only` and download `verify-chat-messages-only`.
- The workflow runs `zig build test-main --summary all` on Windows, then builds the pinned pre-fix commit 42cecfd3e88e78f3c44f0b30917a8629c8e94f8f in a separate runner checkout. It requires the same journey to fail specifically because visible activity changes the transcript, with successful owned cleanup. Launch, identity, parsing, missing data or blank screenshots are not acceptable red controls.
- Exact workflow-side journey command:

```powershell
& .claude/skills/verify-multiprompt/control.ps1 -Feature $env:FEATURE -Exe "$pwd/verify-bin/multiprompt.exe" -ExpectedVersion $env:VERIFY_VERSION -ExpectedHash $env:VERIFY_SHA256 -Evidence "$pwd/evidence"
```

- `FEATURE=chat-messages-only` delegates to `tools/verify-chat-delivery/drive.ps1 -Feature chat-messages-only`, using its existing owned job, isolated profile, saved remote tab, Python reader and fake tmux boundary. The stand-in agent creates its own ordinary Claude JSONL transcript; the real app discovers and parses it. The harness never writes the app's chat cache.
- Genuine SendInput selects the tab with Ctrl+1, opens Chat View with Alt+C and types `composer stays usable`. Require the ownership-checked UI Automation transcript and composer focus, plus the app-written message cache.
- Capture `messages-only-before-tools.png` and its 32-bit BMP with two real rendered messages and the typed composer. Ask the stand-in agent to append twelve tool calls and twelve successful results. Wait for all twelve successful paired tool rows in the app-written cache and use Ctrl+0 to require the renderer's existing font/layout log to show fourteen blocks. Ctrl+0 is also applied before the baseline image.
- Capture `messages-only-after-tools.png` and BMP. `node tools/chat-messages-only-proof.mjs evidence` compares every RGB pixel in the owned transcript rectangle, rejects a blank baseline, checks the unchanged visible message data and all tool data, and requires zero changed pixels. This rejects both visible rows and reserved empty space. The whole-window screenshots also retain the real typed composer.
- For the unread journey, append twelve long messages with 32 separate paragraphs each. Require a fresh renderer font/layout log with content height greater than the current transcript viewport. Send ordinary ownership-checked mouse wheel input over the UI Automation transcript rectangle, not focus-dependent Home/End keys. Before injecting unread arrivals, require a fresh app log of count=0, visible=0, up=1 after the wheel input. Every subsequent count/visibility/up assertion also requires a fresh log after its action; partial downward scrolling, bottom reset, close, hidden arrivals and pill jump remain strict. Pill client coordinates are converted to screen coordinates before comparison with the UI Automation transcript bounds.
- After cleanup, `node tools/chat-messages-only-proof.mjs evidence --complete` additionally checks Doctor/hash/version/focus, source transcript, screenshots and zero owned processes. Inspect both screenshots, `messages-only-measurement.json`, `result.json`, `cleanup.json` and the retained cache/transcript yourself.
- The pre-fix evidence is under `negative/`, including its revision/hash in `build.json`. Its result must fail `IGSH-759 messages only` on changed transcript pixels, not an earlier prerequisite. The branch must pass the identical oracle.

## Gotchas

- This is a synthetic agent/remote-shell boundary, not signed-in Claude, real SSH or live tool execution. It exercises the production transcript reader, cache, layout, painter and native composer.
- No Windows app, tests, copied fixtures or builds run on the VPS. All execution happens on GitHub's free Windows runner.
- The code-font journey's direct low-level diff painter proof is retained. It is not proof that tool previews remain visible in Chat View.
