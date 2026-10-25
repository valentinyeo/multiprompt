# New messages below the fold

## Sub-features

- Only new transcript message starts arriving while the reader is scrolled up increase the count. Initial loads, older pages, repeated refreshes, streamed continuations, Markdown blocks and tool activity do not.
- A centered compact pill above the composer shows a down arrow, the full count and a separate close control. It reserves its own row outside the transcript, above the existing working/permission row.
- Ordinary scrolling retains the count until the existing bottom threshold is reached. Reaching bottom clears it; clicking the pill follows the existing End-key scroll path and clears it.
- Close hides the pill without clearing the counter. Later arrivals continue increasing the hidden count; its row stays reserved so dismissal cannot accidentally scroll the reader to bottom. Reaching bottom clears the hidden count and permits the next unread batch to show again.
- Native regression tests cover each transition, source-offset accounting, repeat/stream/load exclusions, no count cap, hit targets and non-overlapping centered geometry.

## How to get to it (user POV)

Open a conversation in Chat View with Alt+C, scroll up, and let new messages arrive. Click the pill to jump to the newest message, or its × to dismiss it without marking those messages read. Scrolling to bottom also clears it. There is no setting, flag, new shortcut or palette command: this is a passive indicator on the existing scroll path; End remains the keyboard jump.

## Driving it with control.ps1

- Use the existing registered journey, not this map's file stem: `gh workflow run verify.yml --ref ceo/IGSH-813 -f feature=chat-messages-only`. Also run the existing `feature=chat-view` journey for composer, focus, selection and toggle regressions. All execution is on GitHub Windows.
- `control.ps1` delegates `chat-messages-only` to `tools/verify-chat-delivery/drive.ps1`. Keep its existing source-reader, tool-pixel comparison and pinned pre-fix red control unchanged. After that comparison passes, the same owned app/profile runs the new-message transitions.
- Ask the existing synthetic agent boundary to append twelve long messages through its ordinary Claude transcript writer. Wait for the app-written cache, and require no unread count at bottom. Focus the ownership-checked transcript and press Home with genuine SendInput; already loaded messages must not count.
- Append two new assistant messages. Require the app's counter diagnostic to show two, visible and scrolled up. Independently read the real transcript's UI Automation rectangle and map the pill's client rectangle to screen coordinates; fail if it overlaps the transcript or is not centered. Capture `new-messages-visible.png`.
- PageDown once without reaching bottom and require the count to remain two. Ownership-check the main HWND at the close-control point and use genuine SendInput to click ×. Require the pill hidden with count two; capture `new-messages-dismissed.png`. Append one more message and require the hidden count to become three.
- Focus the owned transcript and press End. Require zero count and bottom state, then Home, one new arrival, and an ownership-checked SendInput click on the pill body. Require zero count and bottom state again; capture `new-messages-jumped.png`. Restore composer focus and run Doctor.
- The existing completion oracle now requires the new-message transition observation and all three screenshots in addition to the original tool/source/cache, executable identity and zero-owned-process cleanup assertions. Any incomplete transition fails the journey; the earlier tool regression still rejects its pinned pre-fix build before this extension runs.
- Inspect the three new screenshots, `actions.json`, `messages-only/observation.json`, retained transcript/cache, `result.json`, Doctor/build identity and cleanup. Record the exact branch revision and run URL. The counter diagnostic is state evidence, not independent proof of painted text; screenshot inspection must confirm the arrow, number and × are readable and do not obscure text.

## Gotchas

- This is the existing explicit synthetic-agent/fake-tmux boundary, not signed-in Claude, real SSH, live networking or a claim about agent consumption. The app still runs its production transcript reader, layout, painter, mouse routing and composer.
- Raw console screen capture has no stable message source offsets; this journey and the arrival accounting cover structured conversation transcripts, not arbitrary console redraws interpreted as new messages.
- The existing four-pixel bottom tolerance is unchanged. Hiding the indicator is not marking messages read; its reserved row remains until bottom is reached.
- The signed counter stores a hidden count as negative and a shown count as positive; there is no second count, dismissal flag, timer or persistence setting.
- No local build, test suite or app execution was run for this change. Windows compilation, native tests, no-comments CI, both existing journeys and visual screenshot review remain mandatory GitHub runner evidence; this map is not a claim that they passed.
