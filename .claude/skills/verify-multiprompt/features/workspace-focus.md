# Workspace focus

Return to a workspace and resume typing in its Chat View typing box or shell without clicking.

## Sub-features

- `workspace-focus-chat`: keyboard return restores the selected session, Chat View and original typing box; bounded WM_GETTEXT verifies exact text.
- `workspace-focus-chat-pill`: pill return restores the same Chat View session and typing box.
- `workspace-focus-shell-pill`: pill return restores the console and executes the command staged before leaving.
- `workspace-focus-shell`: keyboard return restores the console and executes the command staged before leaving.

## How to get to it (user POV)

Use Ctrl+K `workspace switcher` to show workspace pills, Ctrl+K `chat view off everywhere` to establish the shell baseline, Alt+C for Chat View or the shell, Ctrl+N to create workspace 2, Alt+2 for workspace 1, and Alt+Right / Alt+Left or the pills to switch away and back.

## Driving it with control.ps1

Run `gh workflow run verify.yml -f feature=workspace-focus` against the proposed revision. Require all four `workspace-focus ... PASS` lines and a passed `result.json`. The harness never seeds saved state, writes shell markers itself or clicks the typing box after switching. Readiness readers and Type-Text do not set focus, but Press calls SetForegroundWindow before every chord, including workspace returns and Enter; this is not proof of wholly unassisted foreground restoration.

Every input requires Doctor's executable/window ownership check and the owned app's foreground ancestry. Console readiness also matches the native console title to the saved tab's shell ID, so an outgoing console cannot satisfy an incoming workspace's wait. The following is the complete journey, including each observable readiness condition. Waits poll every 200 ms and expire after 20 seconds unless stated otherwise; failure stops the journey and retains evidence, rather than sending input to an unready surface.

| Step | Input/action | Observable precondition and bounded resulting-state wait |
| --- | --- | --- |
| 1 | Launch isolated single-window CMD | Check executable hash/version before launch; owned main HWND and initialized shell publication within 60 s; foreground frame within 20 s; Doctor passes. |
| 2 | Read baseline | Initial saved CMD within 60 s; first workspace selected; saved tab identity, Chat View off and owned console foreground within 20 s. |
| 3 | Show switcher if hidden | Ctrl+K: new debug-log suffix reports initialized empty palette and native GUI-thread focus is exactly the owned frame within 20 s. Type `workspace switcher`: processed query length and selected target 6213 within 20 s before Enter. Saved explicit `hide_pills:false`, visible expanded sidebar within 20 s. Capture `pills-ready.png`. |
| 4 | Reset to shell view | Ctrl+K and query readiness as above, target 6347 for `chat view off everywhere`; Enter; saved state has neither `chat_view_mode` nor a test-session `chat_view_lock`, the test session has absent/false `cv`, and the owned CMD console is restored within 20 s. |
| 5 | Enable Chat View if off | Saved session `cv:true` within 20 s; visible owned native Edit child within 30 s. |
| 6 | Foreground initial Chat View frame | Setup only: restore/foreground frame; exact frame foreground and original owned Edit HWND focused within 20 s each. Later Press calls still foreground the frame before each chord; readiness readers and Type-Text do not set focus. |
| 7 | Type `before-` | Original Edit focused from step 6; exact original Edit text within 20 s, with a 1 s timeout per WM_GETTEXT; capture `action.png`. |
| 8 | Ctrl+N | Existing Chat View ready; new workspace count, active index and distinct saved CMD tab within 20 s; new owned console foreground within 20 s. Remember both tab indices. |
| 9 | Alt+2 | Second console ready; original workspace/tab, saved `cv:true`, visible original Edit and exact Edit focus within 20 s. |
| 10 | Alt+Right | Original Chat View ready; second workspace/tab, Chat View off and owned console foreground within 20 s. |
| 11 | Alt+Left | Second console ready; original workspace/tab, saved Chat View, visible original Edit and exact focus within 20 s. |
| 12 | Type `workspace-focus-chat` without clicking | Step 11 ready; original Edit text exactly `before-workspace-focus-chat` within 20 s. Assert unchanged HWND, selected tab and saved focus `chat`; record keyboard Chat PASS and `chat-returned.png`. |
| 13 | Click second pill | Explicit saved visible switcher, expanded visible sidebar, valid unsnoozed workspace indices and default scale within 20 s; flush drawing and click the source-defined pill center in the owned client. Second workspace/tab and console foreground within 20 s. |
| 14 | Click original pill | Same pill-layout preconditions; original workspace/tab, saved Chat View, visible original Edit and exact focus within 20 s. |
| 15 | Type `-pill` without a typing-box click | Step 14 ready; exact original text plus `-pill` within 20 s. Assert unchanged HWND/tab and saved focus `chat`; record pill Chat PASS. |
| 16 | Alt+C to shell | Original Chat View ready; original saved tab, Chat View off and owned console foreground within 20 s. Assert pill marker absent. |
| 17 | Stage `echo workspace-focus-shell-pill` | Original console ready; read-only console Document TextPattern shows the complete staged command within 20 s. No Enter yet. |
| 18 | Click second pill | Pill-layout preconditions from step 13; second workspace/tab and console foreground within 20 s. Assert original saved workspace focus `shell`. |
| 19 | Click original pill | Same pill-layout preconditions; original workspace/tab, Chat View off and owned console foreground within 20 s. |
| 20 | Append pill marker redirection, then Enter | Step 19 ready; console TextPattern shows the entire staged command plus redirection within 20 s before Enter. Previously absent marker contains exactly `workspace-focus-shell-pill` within 20 s; assert original tab and saved focus `shell`; record pill shell PASS. |
| 21 | Stage `echo workspace-focus-shell` | Original console remains ready; assert keyboard marker absent; console TextPattern shows complete staged command within 20 s. |
| 22 | Alt+Right | Staged command observed; second workspace/tab and console foreground within 20 s. |
| 23 | Alt+Left | Second console ready; original workspace/tab, Chat View off and owned console foreground within 20 s. |
| 24 | Append keyboard marker redirection, then Enter | Step 23 ready; console TextPattern shows entire staged command plus redirection within 20 s before Enter. Previously absent marker contains exactly `workspace-focus-shell` within 20 s; assert original tab and saved focus `shell`; record keyboard shell PASS and `after.png`. |
| 25 | Final Doctor and cleanup | Recheck owned executable/window; close for up to 10 s, stop the owned job tree within 10 s, copy evidence, remove scratch within 20 s and retain `result.json`. |

The source contracts check switcher setup, pill visibility/layout guards, readiness after every workspace transition, staged shell text, all four outcomes and absence of focus-repair input in readiness readers. Windows CI additionally parses PowerShell and runs the actual journey. Static checks do not substitute for that runtime result.

## Gotchas

- Workspace pills are hidden by default. Never infer their presence from the workspace count or title. A click at the absent pill's coordinates can collapse RECENTS instead of switching workspaces.
- The first stored workspace follows Starred: its pill center is client `(49,17)`, and the second is `(78,17)` at the guarded default layout. Snoozed pills invalidate that index-to-coordinate mapping.
- Off Everywhere switches every session to shell once, without locking subsequent Alt+C toggles. Per-session Chat View omits `chat_view_mode` from saved state; an off session can omit `cv`. A saved active index alone does not prove the console or typing box is input-ready.
- The custom-drawn palette has no native Edit or custom UIA focus provider. Its readiness requires both foreground HWND and GetGUIThreadInfo hwndFocus to equal the owned frame, not the UIA proxy's NativeWindowHandle. Snapshots retain both native and UIA observations in `*.focus.json`; the check never moves focus.
- Console staging uses its native Document TextPattern, not the unsupported Edit ValuePattern. Chat View continues to use the original Edit HWND's bounded WM_GETTEXT.
- This is local CMD/Chat View coverage, not an account, agent, browser, SSH, sync or relaunch journey. Readiness waits only observe restoration; Press still foregrounds the frame before chords. Require the Windows result, not a stronger no-setter claim.
