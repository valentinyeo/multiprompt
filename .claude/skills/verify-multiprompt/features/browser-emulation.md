# Browser emulation

## Sub-features

- Named iPhone and Pixel viewport, user agent and touch presets.
- Custom desktop or mobile dimensions.
- Per-tab debugger retention across ordinary CDP screenshots, link navigation and reload.
- `off` restores desktop dimensions, user agent and touch, including after reload.
- Local native CLI help without a browser request.

## How to get to it (user POV)

Run `zsb emulate iphone`, `zsb emulate pixel`, or `zsb emulate 390x844 --mobile` against the session's target tab. Use `zsb emulate 800x600` for a desktop viewport, and `zsb emulate off` to return to normal. Run `zsb emulate --help` without a connected browser. Reload if the current document was already served using its previous user agent.

## Driving it with verify.yml

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=browser-emulation`. This map uses `control.ps1 -Feature browser-emulation` to launch `browser-emulation.mjs` inside the existing kill-on-close Windows Job, rather than launching the desktop app. The workflow builds the real native bridge and installs pinned Puppeteer only to obtain Chrome for Testing. The driver refuses execution outside GitHub Windows.

Launch a fresh visible Chrome with an isolated temporary profile and the real unpacked extension. Discover its ID through the browser-level target list, register the real native messaging host for that ID, and wait for the extension's ordinary keepalive reconnect. Resolve the synthetic page's window using the browser-level protocol without attaching a page debugger. All page reads and actions use the compiled native CLI and the extension's actual transport, targeting that window.

Serve a synthetic local page with viewport metadata and a real navigation link. Capture desktop `before.png`; enable iPhone; assert width 390, height 844, iPhone UA and touch; capture `action.png` through `zsb cdp`. Follow the page link with `zsb click`, independently assert the incoming navigation request's mobile UA, then assert the viewport/UA/touch and reload persistence. Capture `after.png`. Exercise Pixel, a mobile custom size, a desktop custom size and off. Compare off with the independently measured baseline, reload, and require it still matches.

Retain `actions.json`, `requests.json`, measurement JSON files, four screenshots, build provenance and `result.json`. Require passed status, scratch removal and owned browser tree cleanup with zero active processes in `process-tree.json`. Inspect the screenshots and measurements after downloading `verify-browser-emulation`.

## Gotchas

- The synthetic page is deliberately public-safe; no user content, account or remote server is needed.
- Browser-level CDP is used only for identity and version; attaching an external debugger to the page would interfere with the extension session under test.
- This verifies Chrome, the native zsb command and extension, not the embedded browser pane, Edge-specific behavior, SSH forwarding or app keyboard/palette entry points.
- F12 and browser-chrome DevTools keys remain out of scope. Emulation changes Chromium's page environment; it is not an actual iOS browser engine.
- A tab's emulation ends if its debugger is externally detached or the extension/browser restarts. A new tab is independent; `zsb navigate` may create a new tab by design, so persistence is measured through a real same-tab link and reload.
