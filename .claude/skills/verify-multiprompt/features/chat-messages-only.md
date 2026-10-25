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

IGSH-816 adds the CLEAN chat view option: the Ctrl+K entry `Chat View: Toggle CLEAN chat` hides read receipts, outbox status rows (including "Queued in Claude" chips), the status footer and empty/history status lines, so only message bubbles and the working indicator remain. It is off by default, persists across restarts, has no keyboard shortcut, and leaves the view unchanged when off. After `messages-only-after-tools.png`, the same messages-only plan opens Ctrl+K through the ownership-checked `Press` SendInput helper, types `clean chat` one key at a time, requires exactly one filtered result, and presses Enter without an arrow-key selection step. Search is a case-insensitive substring match against `chat view toggle CLEAN chat`, not the colon-bearing displayed label. Require the persisted setting to be on and the composer unchanged, then capture `clean-chat-on.png` and `clean-chat-on.bmp`. Repeat exactly that palette path, require the persisted setting to be off and the composer unchanged, and capture `clean-chat-off.png` and `clean-chat-off.bmp`, without sending or adding a message between the captures. The RGB oracle requires identical transcript message pixels in both modes, painted status/outbox/footer rows when off and background-only rows when on, a painted working/permission strip in both modes, nonblank messages in both images, and off-mode transcript and footer pixels identical to `messages-only-after-tools.bmp`. The current two-message scene exercises the model footer, not every possible outbox/receipt state; existing native CLEAN painter regressions cover those other states. The existing user-visible sentence in `changelog.d/IGSH-816-clean-chat.md` is retained; no version changes are needed.

## Driving it with control.ps1

- Dispatch exactly `gh workflow run verify.yml --ref ceo/IGSH-816-clean-proof -f feature=chat-messages-only` and download `verify-chat-messages-only`.
- The workflow runs `zig build test-main --summary all` on Windows, then builds the pinned pre-fix commit 42cecfd3e88e78f3c44f0b30917a8629c8e94f8f in a separate runner checkout. It requires the same journey to fail specifically because visible activity changes the transcript, with successful owned cleanup. Launch, identity, parsing, missing data or blank screenshots are not acceptable red controls.
- Exact workflow-side journey command:

```powershell
& .claude/skills/verify-multiprompt/control.ps1 -Feature $env:FEATURE -Exe "$pwd/verify-bin/multiprompt.exe" -ExpectedVersion $env:VERIFY_VERSION -ExpectedHash $env:VERIFY_SHA256 -Evidence "$pwd/evidence"
```

- `FEATURE=chat-messages-only` delegates to `tools/verify-chat-delivery/drive.ps1 -Feature chat-messages-only`, using its existing owned job, isolated profile, saved remote tab, Python reader and fake tmux boundary. The stand-in agent creates its own ordinary Claude JSONL transcript; the real app discovers and parses it. The harness never writes the app's chat cache.
- Genuine SendInput selects the tab with Ctrl+1, opens Chat View with Alt+C and types `composer stays usable`. Require the ownership-checked UI Automation transcript and composer focus, plus the app-written message cache.
- Capture `messages-only-before-tools.png` and its 32-bit BMP with two real rendered messages and the typed composer. Ask the stand-in agent to append twelve tool calls and twelve successful results. Wait for all twelve successful paired tool rows in the app-written cache and use Ctrl+0 to require the renderer's existing font/layout log to show fourteen blocks. Ctrl+0 is also applied before the baseline image.
- Capture `messages-only-after-tools.png` and BMP. `node tools/chat-messages-only-proof.mjs evidence --tools-only` first compares every RGB pixel in the owned transcript rectangle, rejects a blank baseline, checks the unchanged visible message data and all tool data, and requires zero changed pixels. This keeps the pinned IGSH-759 red control strict and stops it before the CLEAN palette steps, which that old executable does not support. This rejects both visible rows and reserved empty space. The whole-window screenshots also retain the real typed composer.
- Run the IGSH-816 on/off sequence above. Record the owned UI Automation status/footer rectangle directly above the transcript and the working strip between the transcript and composer card in `messages-only/observation.json` as `cleanChat.rows` and `cleanChat.working`. The collapsed footer is 28 scaled pixels high; its measured height scales the composer's 12-pixel top inset so the working rectangle excludes the composer card. Keep the original transcript rectangle fixed for both captures: do not crop out changed message pixels or align away a layout shift. `node tools/chat-messages-only-proof.mjs evidence` now requires the CLEAN pair as well as every original tool check, recording RGB measurements under `cleanChat` in `messages-only-measurement.json`. A painted footer in CLEAN fails with `IGSH-816 CLEAN chat ON still paints status/outbox/footer rows`. A changed or blank message rectangle fails with `IGSH-816 CLEAN chat messages changed, shifted or are blank`.
- For the unread journey, append twelve long messages with 32 separate paragraphs each. Require a fresh renderer font/layout log with content height greater than the current transcript viewport. Send ordinary ownership-checked mouse wheel input over the UI Automation transcript rectangle, not focus-dependent Home/End keys. Before injecting unread arrivals, require a fresh app log of count=0, visible=0, up=1 after the wheel input. Every subsequent count/visibility/up assertion also requires a fresh log after its action; partial downward scrolling, bottom reset, close, hidden arrivals and pill jump remain strict. Pill client coordinates are converted to screen coordinates before comparison with the UI Automation transcript bounds.
- After cleanup, `node tools/chat-messages-only-proof.mjs evidence --complete` additionally checks Doctor/hash/version/focus, source transcript, screenshots and zero owned processes. Inspect both screenshots, `messages-only-measurement.json`, `result.json`, `cleanup.json` and the retained cache/transcript yourself.
- The pre-fix evidence is under `negative/`, including its revision/hash in `build.json`. Its result must fail `IGSH-759 messages only` on changed transcript pixels, not an earlier prerequisite. The branch must pass the identical oracle.

The recomputed journey gate list is:

1. Doctor verifies the owned executable, version/hash, saved remote tab and composer focus.
2. The app-written cache preserves the two original messages and all twelve completed paired tool calls/results.
3. Before/after tool RGB pixels are identical and the transcript is nonblank; the composer draft is unchanged.
4. The same chat toggles on and off through Ctrl+K, `clean chat`, Enter; each saved setting and unchanged composer are checked.
5. CLEAN on/off transcript message RGB pixels are identical and nonblank, without alignment or layout-shift allowances.
6. The recorded status/outbox/footer region has ink when off and only the transcript background color when on.
7. The working/permission strip has painted pixels in both modes.
8. Off-mode transcript and footer RGB pixels restore the pre-toggle view exactly.
9. Every existing unread-pill transition, overflow and fresh-log assertion passes, with `new-messages-visible.png`, `new-messages-dismissed.png` and `new-messages-jumped.png` retained.
10. Complete evidence includes both CLEAN PNG/BMP pairs, the existing captures, source transcript and identity, zero owned processes and scratch cleanup; the pinned pre-fix control still fails specifically on visible activity pixels with successful cleanup.

`node --test tools/chat-messages-only-proof.test.js` locally proves the correct synthetic pair passes and the old-oracle input with footer rows still painted is rejected, plus one-pixel, blank, displacement, restoration and working-row negative controls. The existing Windows workflow runs the new `.test.js` and the unchanged `.test.mjs` entry in its same contract-check step, retaining all earlier regressions.

## Gotchas

- This is a synthetic agent/remote-shell boundary, not signed-in Claude, real SSH or live tool execution. It exercises the production transcript reader, cache, layout, painter and native composer.
- No Windows app, tests, copied fixtures or builds run on the VPS. All execution happens on GitHub's free Windows runner.
- The code-font journey's direct low-level diff painter proof is retained. It is not proof that tool previews remain visible in Chat View.
