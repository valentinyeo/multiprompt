# ISSUE-438 native Windows investigation

## Revisions

The native desktop driver compares master `cf4ac72` with release 0.28.779 `7a8704b`. Both contain the original selection fix `9984e3e` (released as 0.28.770).

## Input-path audit

Locations refer to master `cf4ac72`.

| Failure mode | Code evidence and remaining exposure |
| --- | --- |
| Wrong HWND, console above transcript, composer or overlay receives the drag | `src/chat_composer.zig:525` creates one `ZigShellChatTranscript` child of the main frame, without extended styles; `src/chat_composer.zig:504` places transcript and composer separately. The driver checks `WindowFromPoint` at the drag origin. Browser-enabled, full-width and other workspace configurations still need their own reproduction. |
| Transparent/layered overlay or non-client hit test turns selection into movement | The transcript has no custom `WM_NCHITTEST`; browser edge masks return `HTTRANSPARENT` in `src/browser_pane.zig:3321`. Main-frame non-client clicks use the default procedure (`src/main.zig:2357`). A click actually landing on a title bar would move the frame, not select text. |
| Low-level mouse hooks swallow down/up | `src/shortcuts.zig:1930` disables shell double-click toggling while Chat View is active. `src/shortcuts.zig:1981` intercepts physical Ctrl-clicks over eligible shell/browser surfaces; stale-Alt repair is browser-specific. `src/shortcuts.zig:2134` also handles browser Ctrl-clicks. Plain transcript drags have no intentional swallow path. Importantly, physical-input focus bookkeeping at `src/shortcuts.zig:1961` ignores `LLMHF_INJECTED`; SendInput does not prove that branch. |
| OLE/DragDetect starts a competing drag | No `DragDetect`, `DoDragDrop` or `RegisterDragDrop` call exists in the source. `DragAcceptFiles` at `src/chat_composer.zig:544` enables incoming file drops; it does not initiate a text drag. |
| Capture stolen or released too early | `src/chat_render.zig:2593` captures the transcript and starts a 50ms selection-scroll timer. Failed hit lookup and triple-click release immediately. `src/chat_render.zig:2910` stops dragging on `WM_CAPTURECHANGED`/`WM_CANCELMODE`; up releases capture. Another application, popup, touch/mouse utility or activation change could still steal capture. |
| Move lacks MK_LBUTTON | `src/chat_render.zig:2841` uses the stored dragging state, not `MK_LBUTTON`. Starting outside the transcript still cannot begin selection. |
| Refresh, streaming or workspace change clears selection | `src/chat_session.zig:958` preserves a selection only if the same shell and selected prefix survive. Append-only updates survive; replacing earlier text or switching sessions intentionally clears selection (`src/chat_session.zig:1094`). Refresh runs every 750ms (`src/main.zig:6728`); unchanged content returns early. The static console fixture cannot exclude live transcript replacement. |
| IGSH-401 reclassification | `7b0f2ad` changes only tool/activity-prefix classification in `src/chat_capture.zig`, not mouse handling. It may change which live console lines are selectable; tool cards are excluded by `src/chat_hit.zig:29`. |
| IGSH-440 full-width mode | `7e4c481` predates the selection fix. It retains Chat View while changing console visibility; full-width-specific overlap remains a different configuration from this fixture. Later IGSH-450 changes console restoration, not transcript input. |
| Font, wrap, DPI or screen/client coordinate mismatch | `src/main.zig:7696` opts into per-monitor-v2 awareness. `src/chat_render.zig:2357` consumes client-coordinate mouse lParam and the same layout/flow code used to paint. `src/chat_render.zig:285` measures prefix widths using GDI; later font commits change font and line height in both rendering and hit lookup. No `GetMessagePos` conversion is involved. The driver opts into per-monitor-v2 awareness and measures actual window DPI instead of assuming registry settings took effect. |
| Visible highlight but Ctrl+C goes to composer | `src/shortcuts.zig:841` routes Ctrl+C whenever Chat View owns input and a selection is active; it does not require transcript focus. Ctrl+A does require transcript focus. `src/main.zig:6755` avoids composer focus repair during a drag. The driver seeds the clipboard and asserts exact text, not merely a highlight. |
| Different HWND per workspace | The transcript HWND is global and reused, not one child per workspace. Switching replaces global capture/layout and clears selection; stale console/browser z-order or active-shell identity would need logs from that configuration. |
| Click starts on a link, image, Copy button or tool card | `src/chat_render.zig:2886` handles those actions before starting selection. The fixture uses plain prose; selecting a URL by starting directly on it is not equivalent to this test. |

## Coverage and limitations

The driver uses real Windows `SendInput`, not posted window messages. OCR locates the rendered words; the held-button trajectory crosses whitespace, a wrapped line end and the gap between messages. It asserts exact Ctrl+C and context-menu Copy clipboard contents and captures the full screen before, during and after the drag.

Setting `LogPixels=144` and `Win8DpiScaling=1` is only a scaling request. The recorded `GetDpiForWindow` value determines whether 150% was actually exercised. A fresh logon is unavailable on the hosted runner.

## Discriminating follow-up evidence if the native fixture passes

| Hypothesis on the affected machine | Evidence that separates it from this fixture |
| --- | --- |
| Installed update is not the running build | Capture the running window title/version and process start time, not just the installer version or the downloaded executable. Compare with the update/Relaunch card. Relaunch only with the user's permission. |
| 150% or mixed-monitor scaling | Record the transcript HWND's `GetDpiForWindow`, monitor configuration and Windows scaling; repeat on a single monitor at 100% and at the original scale. Registry values alone are insufficient. |
| A physical-input-only path | Record low-level mouse flags, `WindowFromPoint`, down/move/up dispatch, capture owner and capture-change messages during a physical drag. Compare with SendInput on that same machine. Mouse utilities, touch/pen input, remote desktop and stale modifiers are not represented by the hosted fixture. |
| Different surface or layout | A screen recording should include where the drag starts, full-width state, visible browser pane, workspace/tab, tool card versus prose, and whether the composer receives text afterward. Log the target class/rect and active shell identity. |
| Live refresh replaces the selected prefix | Repeat on a settled reply, then while streaming. Record selection anchor/caret and `keep_selection` decisions with before/after transcript revisions. A static console fixture does not exercise changing server/file history. |
| Link, image or tool action wins mouse-down | Start in ordinary non-link prose, then reproduce at the original starting point. A link opening, tool card expanding or Copy button activating distinguishes intentional action routing from failed selection. |
| Selection exists but copy is misrouted | Compare the during/after highlight, seeded clipboard after Ctrl+C, context-menu Copy and its menu label, foreground HWND and keyboard-hook events. Another clipboard manager may also replace the copied text. |

No machine-specific root cause should be asserted solely from a hosted-runner pass.

## Native results

[Successful Windows run](https://github.com/valentinyeo/multiprompt/actions/runs/39591968241), driver/workflow commit `d8d92ec`. Both jobs and both invocations per job exited 0. Screenshots visibly show the running versions 0.28.780 (pinned master) and 0.28.779 (release).

| Build | Source | Baseline drag / Copy | Requested-150% drag / Copy | Effective DPI in both invocations |
| --- | --- | --- | --- | --- |
| master | `cf4ac72ca4cc19a1b9300e4b197dd75657f685f0` | PASS / PASS | PASS / PASS | 96 |
| 0.28.779 | `7a8704b932287b493689f7a1e175ee7f56d05f37` | PASS / PASS | PASS / PASS | 96 |

Actual `DRAG_CLIPBOARD` was identical in all four invocations:

```json
"Anchor amber birch cedar drift elm forest garden hill island jasmine kettle lantern maple north ocean pine quiet river silver trail under violet willow yellow zenith across the valley until the winding road reaches its peaceful closing.\r\n\r\nSecond message reaches harbor meadow with enough additional words to show that copying a message is different from copying only the selected text."
```

Actual `MESSAGE_CLIPBOARD` was identical in all four invocations:

```json
"Second message reaches harbor meadow with enough additional words to show that copying a message is different from copying only the selected text."
```

Artifacts `ISSUE-438-master` and `ISSUE-438-release-0.28.779` each contain `before.png`, `during.png` (button held), `after.png`, `copy-menu.png`, `copied.png`, `result.json`, OCR coordinates, the driver transcript and isolated application logs. Their `scaling-request/` directories contain the repeat after setting `LogPixels=144` and `Win8DpiScaling=1`. Full-screen images are 1024×768. The scaling request did not take effect; these are not 150% results.

**No application root cause was reproduced for plain-prose drag selection. No speculative application fix or purported before-failing Zig test was added.** The physical-only hook path at `src/shortcuts.zig:1961`, 150%/mixed-DPI behavior and changing live history remain meaningful coverage gaps. The table above lists evidence needed to distinguish them on the affected machine.

The temporary workflow is removed after this run to avoid leaving an expensive investigation matrix on future pull requests. The PowerShell driver and this record remain reproducible; the exact workflow is available at `d8d92ec`.

### Investigation attempts, not passing evidence

| Run | Result |
| --- | --- |
| [39588640524](https://github.com/valentinyeo/multiprompt/actions/runs/39588640524) | Exit 1: checkout interpreted abbreviated source IDs as branch names; changed to complete IDs. |
| [39588895880](https://github.com/valentinyeo/multiprompt/actions/runs/39588895880), [39588988498](https://github.com/valentinyeo/multiprompt/actions/runs/39588988498) | Exit 1 before dragging: full-screen OCR read a spurious quote before Second; switched to the enlarged transcript crop used by Wine. |
| [39589913034](https://github.com/valentinyeo/multiprompt/actions/runs/39589913034) | Exit 1 before dragging: PowerShell's Move alias shadowed the helper; renamed it Move-Pointer. |
| [39590873704](https://github.com/valentinyeo/multiprompt/actions/runs/39590873704) | Exit 1: exact drag clipboard passed on both builds, but Home/Enter did not activate native menu Copy. Changed the driver to click the actual popup menu item; no application code changed. |

## Commands and check status

On Windows, each matrix job ran `zig build -Dtarget=x86_64-windows-gnu --summary all`, then `tools/ISSUE-438-realwin.ps1 -SourceRoot <source> -Output <evidence> -Label <build>`, repeated after the registry request: all exited 0 in run 39591968241. Zig 0.16.0 setup and checksum verification match the existing Windows CI job.

Locally, with `ZIG` pointing to Zig 0.16, `nice -n 10 tools/test-windows-wine.sh` exited 0: ARM64 compilation, desktop summary 1433/1433 tests and server summary 747/747 tests. Its Node suites retain pre-existing skips for private-history/public-export checks (three distinct tests, encountered in both desktop and server runs), and seven executed TODO failures in `tools/chat-view-gaps.test.js` (ISSUE-402–407 and ISSUE-376). No skip, TODO, assertion or test filter was added or changed here. A zero command exit is not a claim those pre-existing gaps are fixed.

The independent Windows CI [test run](https://github.com/valentinyeo/multiprompt/actions/runs/39589912943) also passed its test, test-vps and service jobs. Selection-specific Wine evidence is recorded separately after completion.

To reproduce the native driver on an isolated Windows desktop:

```powershell
zig build -Dtarget=x86_64-windows-gnu
choco install tesseract --no-progress -y
./tools/ISSUE-438-realwin.ps1 -SourceRoot . -Output ./selection-evidence -Label local
```

Use an isolated desktop with no existing Multiprompt instance: native HWND discovery assumes that isolation. The fixture needs permission to write its probe files at the drive root, matching the existing shared C agent. The driver uses an isolated APPDATA and force-stops only the application PID it launches.
