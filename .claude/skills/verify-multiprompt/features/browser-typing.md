# Browser typing

## Sub-features

- The Multiprompt address Edit receives ordinary characters after repeated page and address focus changes.
- Alt+Q returns to the native browser page. Ctrl+L reaches an address input.
- A controlled lost release probes the effect of the address focus Alt tap.

## How to get to it (user POV)

Open Browser Pane, click its address bar, and type. Use Alt+Q to return to the browser page.

## Driving it with control.ps1

Run `gh workflow run verify.yml --ref <branch> -f feature=browser-typing` on a public GitHub Windows runner. The existing isolated Edge warmup, app launch, Doctor, Open-BrowserPane and owned-process cleanup apply.

The journey serves a synthetic localhost page with an autofocus input through a dedicated owned Python HTTP server. It waits for a real GET, opens the short URL, saves it through the `browser url` palette action and checks the saved session value. The server job stops in all cases and records its process cleanup receipt. It searches `browser mode` through Ctrl+K and selects `Browser: Use App Address Bar`, then waits for the visible owned bar and an owned browser retaining that page. Twenty cycles type `abc` into that page, click the app-owned `ZigShellUrlBar`, require exact `abc` in its native Edit, dismiss it and return using Alt+Q. It also checks Ctrl+L reaches an address input, including the app Edit. Page text is observed through the browser window title.

The final click installs a low-level keyboard hook on its own message-pump thread. It arms only around the actual SendInput mouse click. It records an app-injected Alt down and suppresses one matching injected Alt up. The driver sends no Alt while armed. It then disarms the hook and types `abc` with raw layout-mapped input, without Doctor, foreground repair, or modifier release. It compares the actual Edit text before any cleanup. After capture, cleanup unhooks and releases only the Alt whose injected release it suppressed.

Inspect `browser-typing-fault.json`, the three `fault-*.png` screenshots, `result.json`, the ordinary cycle checks, and process cleanup. A useful failing-before run must reach the final exact-text comparison, record both the injected down and dropped up, and fail that comparison. A launch, focus, hook or fixture failure is not the requested red control. A candidate with no injected Alt may pass without a dropped event; its real typing still must pass.

## Gotchas

- This is a deliberately suppressed event, not evidence of its natural frequency or the reported incident's root cause.
- GetAsyncKeyState includes injected input. The evidence does not claim to distinguish a real physical key from an injected key.
- German AltGr is not exercised. This proof does not establish AltGr preservation.
- This recipe is manual-only. It does not alter workflow definitions or claim a hosted run has passed.
