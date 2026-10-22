# Browser CLI: embedded frames

`zsb` targets the shell's bound browser tab; `--tab <id|match>` selects another tab within that pane. These commands do not activate the tab.

```sh
zsb frames
zsb frames --tab 7
zsb eval --frame 43 'document.title'
zsb eval --tab 7 --frame 43 'Promise.resolve(location.href)'
zsb click '[role="tab"][aria-label="Settings"]' --tab 7
```

## Frame discovery and JavaScript

`frames` is read-only and returns `tab` plus `frames`, each with `frameId`, `parentFrameId`, and `url`. Frame 0 is the top page. IDs belong to a tab and can change after navigation; refresh the list rather than reusing a stale ID. No `Target.*` CDP access is needed or added.

`eval [--frame <frameId>] <js> [--tab <id|match>]` executes in the requested frame's MAIN world using `chrome.scripting` with `frameIds`, including cross-origin frames where extension scripting is permitted. It awaits promises and preserves the existing result serialization. `script` is an alias. Without `--frame`, execution remains in the top page; `--frame 0` explicitly selects it. Frame IDs must be nonnegative integers.

Missing/inaccessible frames fail rather than silently executing in the top page. If a subframe's Content Security Policy blocks dynamic evaluation, the command reports that restriction; it never uses the top-frame debugger fallback for a subframe. Browser-internal pages and other extension-restricted frames remain inaccessible.

## Click paths

`click` finds a CSS selector across frames. A top-page match takes precedence; otherwise a selector matching multiple frames is rejected as ambiguous.

The trusted path scrolls the target and its ancestor iframes into view without smooth-scroll delays, identifies each iframe by its child window (not its URL), and adds the iframe viewport offsets and borders up to the top page. This handles nested cross-origin/out-of-process frames, redirected frames, and same-URL siblings. The target centre is measured again after ancestor scrolling. The tab receives `Input.dispatchMouseEvent` in order: `mouseMoved`, `mousePressed`, `mouseReleased`.

Results report `clicked`, `trusted`, `frameId`, and `via`:

- `via: "cdp"`, `trusted: true`: browser-dispatched input; `x` and `y` are top-page viewport coordinates in CSS pixels.
- `via: "frame-dom-fallback"`, `trusted: false`: iframe coordinates could not be resolved or the debugger was unavailable before input began. `reason` explains why. The target receives `pointerdown`, `mousedown`, `pointerup`, `mouseup`, and `click` with bubbling, composed events, coordinates, and button state (cancelled pointer-down suppresses compatibility mouse events, as in a browser).

Synthetic events cannot set `isTrusted` or satisfy browser user-activation requirements. A partial trusted sequence or timeout fails instead of replaying a potentially delivered click. A successful dispatch is not an assertion that the page changed; inspect the page state with `eval --frame`, `snapshot`, or `text` afterward.
