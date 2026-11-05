# Browser typing

## Sub-features

- The Multiprompt address Edit receives ordinary characters after repeated page and address focus changes.
- Alt+Q returns to the native browser page. Ctrl+L reaches an address input.
- A controlled lost release probes the effect of the address focus Alt tap.

## How to get to it (user POV)

Open Browser Pane, click its address bar, and type. Use Alt+Q to return to the browser page.

## Driving it with control.ps1

Run `gh workflow run verify.yml --ref <branch> -f feature=browser-typing` on a public GitHub Windows runner. The existing isolated Edge warmup, app launch, Doctor, Open-BrowserPane and owned-process cleanup apply.

The journey serves a synthetic localhost page with a full-viewport text area through a dedicated owned Python HTTP server. It waits for a real GET, opens the short URL, and clicks the owned browser content once before typing. Twenty native-browser cycles type `abc` into the page, check the cumulative page title, use Ctrl+L, require exact `abc` in the native omnibox, and return to the page. It saves the URL through the `browser url` palette action and checks the session value. It searches `browser mode` through Ctrl+K and selects `Browser: Use App Address Bar`, then waits for a new owned pane and the visible owned bar. Twenty more cycles use Alt+Q to leave the pane, then Ctrl+Shift+L to open the app-owned address Edit. Each requires focused Edit text `abc`, dismisses it and returns using Alt+Q. The server job stops in all cases and records its process cleanup receipt.

After the twenty address cycles, the driver keeps its own injected Ctrl pressed while requesting the address Edit through the registered native shortcut. The Edit must gain actual input focus without releasing that held Ctrl. The driver then releases only its fixture-created keys and requires exact `abc` typing in the same Edit. Expiry, mode changes, newer input, ownership loss and replacement-Edit cancellation are additionally exercised through executed production timer code in the portable suite, not live mode-switch journeys.

The final case installs a low-level keyboard hook on its own message-pump thread. From the owned console or frame, it arms only around the real Ctrl+Shift+L chord. It records an app-injected Alt down and suppresses one matching injected Alt up. The driver sends no Alt while armed. If an injected Alt down was captured, it requires only an owned Edit, not retained focus, then immediately types `abc` to expose the fault. If no Alt was injected, it first reads the existing focused-Edit readiness condition because the normal handoff waits for shortcut modifiers to release. This wait sends no input and cannot repair focus. Both paths type `abc` with raw layout-mapped input, without Doctor, foreground repair, or modifier release. It compares the Edit text before cleanup, or records null if that verified Edit was destroyed. After capture, cleanup unhooks and releases only the Alt whose injected release it suppressed.

Inspect `browser-typing-fault.json`, the three `fault-*.png` screenshots, `result.json`, the ordinary cycle checks, and process cleanup. A controlled lost-release red must reach the final exact-text comparison, record both the injected down and dropped up, and fail that comparison. An ordinary-cycle exact-text failure independently proves misrouted typing, but does not prove a lost Alt release. A launch, hook or fixture failure is not a typing regression. A candidate with no injected Alt may pass without a dropped event; its real typing still must pass.

Released v0.28.1501 run https://github.com/valentinyeo/multiprompt/actions/runs/41987342187 passed all twenty native page/omnibox cycles, then failed ordinary address cycle two: the selected URL remained unchanged while `abc` reached the console. Candidate `00f4a796` reproduced that failure. Native trace https://github.com/valentinyeo/multiprompt/actions/runs/41995904330 proved foreground activation was refused while thread-local Edit focus succeeded. Console input-queue attachment subsequently returned native error 87; the fix does not use that new attachment route.

Candidate `5f926cd1` run https://github.com/valentinyeo/multiprompt/actions/runs/42005277347 passed all twenty native page/omnibox cycles, twenty exact address cycles and final `abc` typing. The final hook observed no injected Alt down or dropped release, and no held Alt/Ctrl before or after typing. Screenshots independently show `abc` in the app address Edit, not the console. App and local-server cleanup both recorded zero remaining processes. Full CI https://github.com/valentinyeo/multiprompt/actions/runs/42005281608 passed the same revision. This is isolated Windows proof, not a physical German-layout or owner-account test.

## Gotchas

- This is a deliberately suppressed event, not evidence of its natural frequency or the reported incident's root cause.
- GetAsyncKeyState includes injected input. The evidence does not claim to distinguish a real physical key from an injected key.
- App-mode page navigation and page content input are not exercised. The extensionless pane may show its placeholder.
- German AltGr is not exercised. This proof does not establish AltGr preservation.
- This recipe is manual-only and does not alter workflow definitions. Hosted results above cover only the named revision and actions.
