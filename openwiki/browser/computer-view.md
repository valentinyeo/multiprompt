---
type: Reference
title: Computer view
description: Watch and control the selected server desktop.
tags:
  - browser
  - computer
  - shortcuts
---

# Computer view

Computer shows the selected server's desktop. This implementation still needs native verification.

## Opening and control

Select a server session. These actions open or hide Computer:

- **Ctrl+K**, then **Computer: Show or hide**
- The session's right-click **Computer** action

Computer occupies the right pane. It starts view-only, without taking typing focus. **Take control** enables mouse and keyboard input. **Give back** returns to watching. Every reconnect starts view-only again.

**Alt+Q** returns typing to the session. **Alt+C** still switches chat and terminal. **Ctrl+K** opens the app palette. **Alt+A** selects the laptop browser again. Other typing belongs to the focused Computer.

**Ctrl+Shift+F** toggles Computer's full width. The pill's expand button does the same. Window controls remain available. The sidebar and chat return afterward.

The browser keeps its separate address and split. Computer's viewing choice stays on this desktop. It does not change shared account settings.

## Palette actions

Ctrl+K includes these Computer actions:

- **Computer: Show or hide**
- **Computer: Take control**
- **Computer: Give back**
- **Computer: Toggle full width**
- **Computer: Retry**

Opening a palette gives back control. Computer can remain visible beside the palette. Overlays covering Computer put it to sleep.

## Connection states

| State | Meaning |
| --- | --- |
| Connecting | Checking the selected connection and desktop. |
| Live | A completed picture reached the canvas. |
| Sleeping | The hidden viewer has disconnected. |
| Reconnecting | A visible connection failed and is retrying. |
| Lost | No usable view. Choose Retry. |

Matching, previously validated sessions share one connection. Host names alone do not establish a match. Unvalidated sessions need fresh discovery.

Hidden views disconnect. Computer keeps two sleeping pictures in memory. Large desktops produce smaller, proportional pictures. Pictures never intentionally enter files or clipboard. Account locking clears the picture cache.

A known target can show its sleeping picture. Fresh pixels replace that picture after waking. Unknown targets remain blank during discovery. Computer does not resize the server desktop.

Session changes and connection loss revoke control. So do blur, minimize, locking, and covering overlays. Closing allows a bounded input-release interval. Broken connections cannot guarantee remote key release.

## Supported connections

Computer uses the app's selected SSH executable. It uses the selected account's existing keys. Existing host-key verification stays strict. Computer never accepts new host keys. It never changes services or firewall rules.

Current connection limits:

- Direct SSH with key or agent authentication.
- Jump hosts and command proxies are unsupported.
- Host-key file paths cannot contain spaces.
- No command-based host-key lookup.
- A non-root Linux desktop user.
- Already-running `x11vnc.service` and `novnc-desktop.service`.
- The known literal Python websockify service layout.
- Same-user processes, display, and private auth file.
- Loopback-only viewer listeners.

Unsupported layouts show **Lost**. Desktop ports come from live service discovery. Password decoding uses the existing x11vnc capability. No password enters a URL or process argument.

Active connections retain their original SSH settings. Reconnecting resolves those settings again.

## Private viewer

Computer uses its own private WebView2 controller. It does not use the browser extension. It does not use the development browser bridge.

The page embeds noVNC 1.6.0. Its random loopback address serves intercepted resources. No HTTP server starts for that page. Unknown web resources are blocked.

Navigation, downloads, and developer tools are disabled. Clipboard and file transfer are unavailable. Passwords and pictures are not intentionally persisted. App memory minidumps stop after Computer's first use. Text crash diagnostics remain available.

The installed Microsoft WebView2 runtime is required. Missing runtimes show **Lost**. Computer never installs a runtime automatically.

Retries reuse this instance's private runtime directory. That directory can remain after closing. OS paging and runtime policies need separate assessment. Native isolation and release delivery remain unverified.

Dependency sources and licenses:

- `src/computer/UPSTREAM.json`
- `src/computer/vendor/novnc/`
- `src/computer/vendor/webview2/PROVENANCE.txt`
