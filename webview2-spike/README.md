# WebView2 Spike — ZigShell Feasibility

**Proves:** a Microsoft Edge WebView2 control can render a live web page as a true Win32
child control — no separate top-level browser window, no overlay masks, no z-order tricks.
Resizing the host window resizes the page because the controller bounds follow `WM_SIZE`.

## Build

Prerequisites: Zig 0.16 on PATH, Edge / WebView2 Runtime installed
(normally available on Windows 11). Download the Microsoft.Web.WebView2 NuGet package
from Microsoft and extract it under `webview2-sdk\`, or pass `-SdkRoot` to
`build-bridge.ps1`. SDK binaries and generated loader DLLs are not included.

```powershell
cd webview2-spike
.\build.ps1          # produces webview2-spike.exe + copies WebView2Loader.dll
```

To build AND launch immediately:

```powershell
.\build.ps1 -Run
```

To build the in-process bridge used by the DEV app, then build DEV:

```powershell
.\webview2-spike\build-bridge.ps1
zig build dev
```

Launch multiprompt and press **Alt+S** to create or fully destroy the embedded
pane. `Alt+A` toggles the regular native-Edge pane, and opening either mode closes
the other. F10 remains an additional DEV-only WebView2 toggle.

Manual build command (what build.ps1 does):

```
zig c++ main.cpp -I webview2-sdk\build\native\include -I . `
    webview2-sdk\build\native\x64\WebView2Loader.dll.lib `
    -lole32 -luser32 -lgdi32 -mwindows -std=c++17 -O2 `
    -Wno-nullability-completeness -Wno-unused-command-line-argument `
    -o webview2-spike.exe
```

## Run

```
webview2-spike.exe
```

`WebView2Loader.dll` must be in the same directory (build.ps1 copies it there).
The WebView2 Runtime itself is the evergreen install that ships with Edge — no separate
install step on Win11.

## What it shows

`example.com` renders inside a native Win32 `WS_OVERLAPPEDWINDOW`.
The WebView2 control is created with `CreateCoreWebView2Controller(g_hwnd, ...)`, making it
a child of the window's HWND. Its bounds are set to the client rect and updated on every
`WM_SIZE`. There is no separate Edge window, no `SetParent` reparenting, and no z-order
fighting — WebView2 manages its own child surfaces entirely through Chromium compositor.

## How this maps to ZigShell's pane

In ZigShell the right pane HWND (currently used to host a reparented top-level Edge window)
would instead be passed as the parent HWND to `CreateCoreWebView2Controller`. The controller
bounds would be set from `calcBrowserLayout` on every reposition. The result would be:

- Zero top-level browser windows — WebView2's composited surfaces live inside ZigShell's
  own window tree. No z-order conflict with the sidebar, Ctrl+K overlay, or F1 panel.
- No DWM border / rounded-corner hacks needed — there is nothing to fight; the control
  paints directly into the parent.
- No `SetWindowRgn` clip-reset problem — WebView2 does not reset anything on the parent.
- Resize is a single `put_Bounds(rect)` call, not a `SetWindowPos` + reattach dance.
- No floating orphan windows if ZigShell crashes — WebView2 child processes are tracked
  by a `Job Object` inside the WebView2 Runtime and die with the host.

The branch now contains this mapping as a working DEV-only integration:

- `webview2_bridge.cpp` exposes a native boundary around the asynchronous WebView2 COM
  lifecycle, focus ownership, navigation, and a bounded internal tab set.
- The bridge creates `MultipromptWebView2Host` as a true child of the main window.
- Alt+S keeps the active console visible on the left, creates and focuses WebView2 in the
  same right-hand rectangle used by regular Edge, and follows the same saved splitter.
  Alt+S again closes the controller and environment and expands the console normally.
- Shell links, Alt+W, browser-bridge opens, and website popups create internal tabs instead
  of overwriting the active page. Ctrl+Tab/Ctrl+Shift+Tab cycle, Ctrl+W closes, and Ctrl+T
  opens a blank tab. The tab set has no visual tab strip yet.
- Existing per-session Edge state is not modified. For isolation, the F10 spike declines
  to open on a session that already has the current native Edge pane enabled.

## Measured footprint (2026-07-13)

Measured on the development machine after an 8-10 second settle, summing private memory
across the complete `msedgewebview2.exe` process group:

| Case | Runtime processes | Runtime private | Runtime working set |
|---|---:|---:|---:|
| `about:blank`, standalone host | 6 | 147.6 MB | 309.1 MB |
| `example.com`, standalone host | 6 | 168.4 MB | 341.2 MB |
| `example.com`, embedded in DEV | 6 | 166.0 MB | 345.0 MB |
| `google.com`, embedded stable candidate | 6 | 246.4 MB | page-dependent |

The embedded DEV app and WebView2 group were 203.7 MB private combined in the first run.
Closing with F10 removed all six runtime processes within six seconds and returned the DEV
host to 37.7 MB private. Reopening produced no WebView2 top-level window, so the runtime
processes add no independent taskbar entries.

This means WebView2 is viable as an explicit on-demand browser mode, but its ~148 MB blank
baseline—and substantially higher cost on real pages—is incompatible with making it an
always-on default in a RAM-first application.

## Honest tradeoffs vs the current docked-Edge approach

| | Current (docked top-level Edge) | WebView2 embedded |
|---|---|---|
| **Profile / cookies** | Shared with the user's real Edge — same logged-in state | Isolated `userDataFolder`; does NOT share Edge cookies/logins |
| **Tab strip / omnibar** | Real Edge chrome (native tabs, back/forward, DevTools) | Internal tabs and history work, but there is no visual tab strip or omnibar yet |
| **Browser control** | `zsb` CLI → native-messaging extension → Chrome DevTools Protocol | `ICoreWebView2::ExecuteScript` + `AddScriptToExecuteOnDocumentCreated`; also has a `CallDevToolsProtocolMethod` API |
| **Extension support** | Full Edge extension ecosystem, Vimium, etc. | No extensions by default (can inject scripts instead) |
| **`zsb`/ bridge layer** | Full extension/native-host bridge | The multiprompt-browser bridge can open/navigate/back/forward/reload; extension-specific automation still requires real Edge |
| **Keyboard shortcuts** | Full browser shortcuts reach Edge natively | Must forward keyboard events explicitly; ZigShell's hook would handle all keys |
| **Memory** | Shares Edge's GPU process with the user's tabs | Separate GPU/render processes; may use MORE memory for a single page |
| **Complexity** | Fighting z-order, DWM borders, SetWindowRgn resets | Clean child control; standard Win32 ownership model |
| **Build size** | No new SDK needed | +`WebView2Loader.dll` (~500 KB) at runtime; SDK headers only at build time |

**Bottom line:** WebView2 solves every z-order and visual integration problem cleanly.
The cost is losing the shared Edge profile and the existing `zsb`/extension control layer.
Whether that's worth it depends on whether seamless visual integration outweighs the value
of shared logins and Vimium. Both are real tradeoffs, not paper ones.
