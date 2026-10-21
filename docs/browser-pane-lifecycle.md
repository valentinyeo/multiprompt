# Browser Pane Lifecycle and Focus Invariants

This is the source of truth for ZigShell's native Chromium pane ownership, focus,
Alt+Tab, visibility, and recovery behavior. Documentation indexers such as
OpenWiki should link implementations and release notes back to this page.

## Window model

- The selected Edge or Chrome pane remains a native top-level
  `Chrome_WidgetWin_1` window.
- `GWLP_HWNDPARENT` points at the ZigShell frame, making the pane owned.
- `WS_EX_TOOLWINDOW` must be set and `WS_EX_APPWINDOW` must be clear.
- The `ZigShellPaneOwner` HWND property identifies the owning ZigShell frame.
- Browser edge masks are separate ZigShell-owned popup windows. They must be
  hidden immediately whenever foreground leaves ZigShell.

## Alt+Tab invariant

One physical Alt+Tab must leave ZigShell whether focus starts in the shell, the
docked browser page, or the browser address bar. Native consoles and Chromium panes can
be treated as separate members of ZigShell's owned-window group, so passing
Alt+Tab through can stop inside that group. The keyboard hook must select and
activate the next eligible foreign task, exclude every ZigShell-owned window,
and consume the original Tab.

Do not synthesize an Alt key-up in this path. Do not start a shell refocus retry.
`noteSystemAltTab` must cancel pending refocus before Windows handles the chord.

## Alt+Q focus invariant

One physical Alt+Q press performs one focus hop. Windows may emit repeated Q
keydown events while Alt remains held, especially when Chromium or the UI
thread is busy. The keyboard hook must consume those repeats until the physical
Q key-up. It must clear the latch when the hook is replaced. Do not add a
time-based debounce because a separate rapid press must still switch back.

## Cross-monitor movement invariant

The multiprompt frame, reparented console, native Chromium pane, URL bar, masks, and
verified Chromium popups are one movement unit even though they are separate
HWNDs with different coordinate spaces. Monitor selection must use the live
virtual desktop rather than a left-sorted list: coordinates may be negative,
gapped, vertically stacked, rotated, mixed-size, or mixed-DPI.

Every title-bar drag, detected crossing, Win+Shift+Arrow move, snap hop,
`WM_DPICHANGED`, and `WM_DISPLAYCHANGE` must use the shared monitor transition.
Park native browser chrome during the frame move, suppress independent
geometry/mask timers, and recompute all child rectangles from the landed frame.
Completion requires stable frame read-back, the requested monitor handle,
console containment, browser rectangle read-back, and destination-contained masks.
A timeout is a visible failure and must be appended to
`%APPDATA%\ZigShell\monitor-move-audit.tsv`; it must never be recorded as a
successful move.

## Link-click modifier invariant

An ordinary physical left click inside a marked native browser pane must never
inherit stale Alt state and become an HTML download. The permanent stale-Alt
guard runs on its own message-loop thread, not multiprompt's UI thread. It uses
the pane's `ZigShellPaneOwner` property rather than scanning sessions or reading
cross-process geometry, ignores injected clicks, and bypasses the repair while
Alt is physically held so intentional Alt+click remains native.

The guard must not rewrite every browser mouse-down. An Alt transition involving
the pane arms exactly one repair; that repair emits the missing Alt release and
replays the next physical mouse-down once. With no armed repair, the original
hardware event passes through unchanged so Chromium retains native click counts,
caret placement, drag selection, and double-click behavior. The repair's own
tagged synthetic Alt release must not re-arm the guard.

Do not move this guard back onto the UI thread. Do not make it depend solely on
the Chromium extension or a content-script handshake: unpacked extension updates do
not become live until the selected browser reloads them, while the native click boundary must be
effective immediately after a multiprompt relaunch.

## Runtime checklist

1. Open a session with a docked browser pane.
2. Focus the page and press Alt+Tab once. Foreground must be a foreign app.
3. Return, focus the address bar, and repeat. Foreground must be a foreign app.
4. Return, focus the shell, and repeat. Foreground must be a foreign app.
5. Confirm the pane has no separate taskbar button and the frame masks do not
   remain over the foreign app.
6. Switch from a session with a visible browser pane to one without a browser.
   The old browser HWND must be parked off-screen even if Chromium still owned
   foreground when the switch message arrived, and no grey browser surface may
   cover the centered console.
7. Switch repeatedly between two sessions with live browser panes, then toggle
   one off and on with Alt+A. The returning pane must remain painted; when off,
   the shell must reclaim the entire column with no blank DWM rectangle.
8. Force-end the selected Edge or Chrome process that owns a test pane. Within a few seconds the
   shell must reclaim the browser column, the active pane must relaunch, and
   multiprompt must still respond and close normally.
8. In a page text editor, double-click to enter edit mode, single-click between
   characters, and drag across part of a word. The caret and selection must
   match regular Chromium; unarmed clicks must not select a whole word.
9. Move a console-only tab to every connected display with a title-bar drag and
   `Win+Shift+Left/Right`, then move it back. Test restored and maximized states.
10. Repeat with a native browser pane, then with its three-dot menu open. The pane
    and masks must return on the destination only, the console must remain
    contained, and one-step Alt+Tab must still work.

## Tab-switch visibility invariant

`updateBrowserVisibility` must park every inactive pane before its foreground
ownership early-return. A tab switch can update `active_shell` while the old
Chromium pane still owns foreground; checking foreground first leaves that old
cross-process window visible over the new console. For an established tracked
pane, keep Win32 visibility set and move the TOOLWINDOW to the off-screen park
coordinate. Do not cycle `SW_HIDE`/`SW_SHOW`: Chromium can return with a live
but solid-grey compositor surface. Hard hide remains appropriate only while an
unadopted beacon is being mutated/closed. Queue a hard hide before asynchronous
`WM_CLOSE` so delayed destruction cannot leave stale DWM content in the layout.
Do not move or hide the active browser during ordinary foreground loss.

## Crash and shutdown invariant

Never call synchronous cross-process visibility or geometry APIs on a Chromium
pane from multiprompt's UI thread. Use `ShowWindowAsync` and include
`SWP_ASYNCWINDOWPOS` in `SetWindowPos`; avoid hot-path `SetWindowRgn` calls on
native panes. `WM_CLOSE` must gate browser callbacks before cleanup and must not
wait for Chromium to acknowledge any request.

The browser health timer validates the owning process as well as `IsWindow`,
because Windows can retain an HWND while its process is termination-pending. A
dead or repeatedly Windows-hung pane loses its local HWND/windowId binding,
returns the full column to the console immediately, and relaunches only after a
short teardown backoff. The saved URL and `browser_enabled` intent survive.
Likewise, termination-pending multiprompt HWNDs must never satisfy workspace
dedup; a new process must be allowed to replace them without a Windows sign-out.

## External-link boundary and audit

Every adopted Edge or Chrome pane must complete `protectWindow` registration with its
Chrome window ID and owning multiprompt shell ID. Protection registry loading is
single-flight and merge-only: an asynchronous storage read must never replace
IDs added by concurrent restore-time registrations.

Every tab created in a protected isolated-profile window is internal by
construction and stays unmuted in that exact window. Multiprompt provenance may
provide a more specific audit reason, but focus, opener identity, transition
type, bookmarks, redirects, and timeouts never quarantine or eject a tab.

The extension persists the last 200 routing decisions, including timestamp,
URL, Chromium window/tab IDs, owning shell ID, authorization reason, destination
focus, and errors. Inspect them without a pane binding:

```text
multiprompt-browser routing-audit --limit 50
```

Native panes globally select either
`%LOCALAPPDATA%\ZigShell\EdgeUserData` or
`%LOCALAPPDATA%\ZigShell\ChromeUserData`. A mere `--profile-directory` inside
normal Edge or Chrome is not isolation: normal browser and PWA service workers
can still enumerate and focus same-process clients. Each dedicated directory is
its own complete OS/PWA boundary with independent cookies and logins. Both remain
full browsers with tabs and extensions, automatically load the bridge and active
theme packages, and disable web notifications. Normal Edge, normal Chrome, and
Windows activation cannot address either process singleton, so tab-level
ejection remains off.

`%APPDATA%\ZigShell\browser-engine.txt` persists the global `edge` or `chrome`
choice. Ctrl+K **Browser Engine** closes every tracked old-engine window and
clears its pane bindings before a delayed active-pane relaunch. Inactive enabled
panes preserve URL/state and use the selected engine when next shown. Only one
isolated engine may own `\\.\pipe\multiprompt-browser-isolated` at a time.
Chrome receives the same native-host manifest through its user-level
`NativeMessagingHosts` registry key, so focus, navigation, tab activation,
screenshots, theme synchronization, and routing audits target the selected
engine rather than falling back to Edge.
The separate on-demand WebView2 mode is unchanged.

A physical Ctrl+click on a Bash/console URL is explicit user navigation: it
must create the fresh tab active and move keyboard focus into that session's
docked browser. Programmatic `multiprompt-browser` and `zsb navigate` requests
remain append-only and background-safe unless they carry the private explicit
user-activation flag. Both paths retain the exact bound-window containment
check; foreground activation is not new authorization.

Remote browser control has one authoritative session identity. Inside tmux the
wrapper sends only the live `#S` name. Outside tmux it requires an explicit
`ZSB_SESSION` and fails closed when absent. It must never ask tmux for an
unscoped current session, and the Windows resolver must never fall through from
the primary tmux name to a stale `zss-*` token after a restart.

The same process-scoped launch also loads the selected one of seven bundled
theme-only extension packages. The palette's System option persists the
automatic preference separately, resolves Windows' `AppsUseLightTheme` value,
and gives the selected browser the resulting concrete Light or Dark token. Windows setting and
theme notifications reskin the app, native consoles, browser masks, and the
isolated browser profile together. Because Windows does not reliably deliver that
broadcast to this owner-docked process, System also checks the value once per
second and self-corrects a missed change; fixed themes skip the registry check.
Fixed theme choices remain fixed. Chromium retains
only one unpacked theme, so when the effective app theme changes,
bridge/extension 1.0.41 closes only the
isolated profile's normal windows. `--disable-background-mode` ends that
dedicated process and the existing pane-health self-heal relaunches it with the
new selected package. This changes native
frame/tab/toolbar chrome inside the selected dedicated user-data directory; it
must not alter normal Edge or Chrome, Windows appearance, protected-window routing, or
arbitrary website content. Browser edge masks inherit the active app theme;
Light must never restore the retired peach `RGB(248, 204, 168)` surround.

If the fallback must escape a residual tab or recovered notification URL, it
reuses the one regular window it explicitly created. It must not pick an
arbitrary PWA/normal window and must not create one new window per link.

## Regression history

- `v0.28.443` suppressed the pane's independent Alt+Tab entry.
- `v0.28.464` prevented browser frame masks leaking over foreign programs.
- `v0.28.472` attempted to normalize pane focus to the owner before native
  Alt+Tab; real use showed Windows could retain the owned-group traversal.
- `v0.28.475` explicitly activates the next foreign task and consumes the Tab,
  covering both native shell and browser-pane foreground paths.
- `v0.28.513` replaces established-pane hide/show transitions with off-screen
  parking, covering session switches, overlays, minimize, and Alt+A close.
- `v0.28.515` makes Edge window operations non-blocking, adds automatic
  dead/hung-pane recovery, and ignores termination-pending workspace owners.
- `v0.28.520` restores the native stale-Alt click boundary deleted by v0.28.516
  and isolates its permanent mouse hook on a dedicated message-loop thread.
- `v0.28.521` handles Firebase's `notification-clicked` client message in
  protected panes and opens the validated same-origin target in regular Edge.
  OS notification activation remains outside multiprompt; focusing an existing
  docked client must never be mistaken for completed navigation.
- `v0.28.522` moves the Firebase listener into the page MAIN world and relays
  only a validated same-origin target to the isolated extension. It also makes
  native Edge focus a verified bounded retry after physical Alt release, and
  gives Alt+W an explicit activate-and-focus path distinct from agent navigation.
- `v0.28.528` retains a validated notification target while the MV3 worker
  resolves protected-window state instead of treating unknown as unprotected.
- `v0.28.530` serializes protection loading, acknowledges registrations with
  shell identity, mutes unattributed tabs until classification, fails closed on
  ejection errors, and adds the persistent routing audit.
- `v0.28.534` removes raw same-pane opener inheritance as an authorization
  signal after the audit proved an external tab could be quarantined and then
  falsely trusted as `protected_opener`; explicit created-target provenance
  continues to cover real page-opened links.
- `v0.28.537` makes the stale-Alt repair one-shot instead of replacing every
  pane mouse-down, restoring native caret, drag, and double-click semantics.
- `v0.28.540` replaces independent monitor, console, Edge, and mask movement
  repairs with one spatially selected, generation-scoped transition that
  verifies landed rectangles and writes a durable failure audit. It remains a
  DEV candidate until live movement succeeds in both directions.
- `v0.28.580` moves native panes into an isolated full-Edge user-data directory,
  preventing normal Edge/PWA notifications from selecting protected clients,
  and reuses one explicit fallback window for residual escapes.
- `v0.28.585` loads the selected profile-scoped theme package and applies theme
  changes through an isolated Edge restart using bridge/extension 1.0.41. It
  also removes the legacy peach Light mask without changing page content or
  normal Edge.
- `v0.28.586` adds the persisted System choice. It follows Windows app
  light/dark changes live across multiprompt, its consoles and masks, and the
  isolated Edge profile while leaving fixed themes and normal Edge untouched.
- `v0.28.587` adds a one-second System-only fallback check after live evidence
  showed Windows could change the registry value without delivering a usable
  appearance broadcast to multiprompt.
- `v0.28.588` makes physical console URL clicks activate and focus their fresh
  pane tab while retaining background behavior for agent navigation.
- `v0.28.590` makes the dedicated profile the complete containment boundary.
  Protected-window tabs, popups, bookmarks, redirects, and legacy notification
  targets remain inside; delayed quarantine/ejection listeners are removed.
- `v0.28.591` adds one persisted global browser-engine choice. Edge and Chrome
  use separate dedicated user-data roots; switching closes every old-engine pane
  before the selected extension/native command channel relaunches the active one.
- `v0.28.592` makes Alt+A/Alt+B one toggle per physical press. Windows key
  repeats are consumed until A/B key-up, preventing a slow first dedicated
  Chrome launch from posting a second logical toggle. Live evidence later showed
  this did not fix the visual disappearance: the pane remained enabled but parked.
- `v0.28.593` carries foreground authority from an active multiprompt launch
  through Chrome's exact nonce beacon. After the beacon is hidden, multiprompt
  reclaims its frame and positions the owner-tagged pane instead of leaving its
  visible HWND parked at `-32000,-32000`; background launches remain passive.
  Live DEV acceptance placed Chrome at `690,223,1164,812` and retained it after
  a repeated `A` keydown 650 ms later.

These fixes cover different invariants. Do not remove one because another test
passes.

## Profile cloning

`zigshell-bridge profile-clone <src> <dst>` copies `Local State` and direct
profile folders containing `Preferences`, preserving bookmarks, cookies,
passwords, extensions, history, storage, and session data without changing src.
Other root data, cache directories at any depth, crash data, and lock files
are skipped. An exclusively held source `lockfile` refuses with a running error.
The destination must not exist; preflight requires copy bytes plus 1 GiB free.
A stale `<dst>.partial` is removed first. Copying goes into that sibling,
which is validated and marked `.multiprompt-clone-complete` before a rename
without replacement publishes dst. A copy error removes the partial directory.
Reparse points and overlapping source/destination paths are refused.
Success prints one JSON line with destination, copied file count, and bytes.

## Workspace browser profiles

`src/browser_workspace_profile.zig` has the one-line `IGSH_224 = true` switch.
Set it to false and rebuild to restore the shared isolated-profile behavior.
The switch defaults on; it does not move or overwrite `EdgeUserData` or
`ChromeUserData`. Those directories remain the read-only first-use seeds and
rollback profiles.

A stable workspace ID is SHA-256 hashed (the first 30 hexadecimal characters),
never a display name or slot. Profiles live under
`%LOCALAPPDATA%\ZigShell\BrowserWorkspaces\edge\<hash>` or `chrome\<hash>`.
The engine-prefixed token (`e-<hash>` / `c-<hash>`) is shown in a header notice
when opening a pane. Bookmark cleanup is manual and affects only that profile.
Closing or deleting a workspace leaves its hash-addressed browser data intact;
there is no automatic profile deletion. Retained directories can be backed up
or recovered separately, without following a workspace display-name path.

Before launching, a background worker prepares a missing profile. The shared
source must have no running browser process. Its process lock is held for the
whole copy. When absent, a temporary delete-on-close lock is created atomically
and removed on exit; no durable seed data changes. Process checks also run
before and after copying. Migration preflights the retained
bytes plus 1 GiB, copies into `.partial`, validates Local State and at least one
profile Preferences file, writes a completion marker, and atomically renames.
Incomplete destinations never launch. A fresh install with no seed initializes
a minimal complete profile without creating a shared seed. Interrupted partial
copies are retried, not adopted. Service Worker registrations are retained;
CacheStorage, ScriptCache, HTTP/code/GPU caches, component/model downloads,
crash reports, and process locks are not copied. Durable source files are never edited. Only the bridge extension's own local
routing registry is excluded from seeding, so copied window IDs and process
ownership cannot survive into a new profile; other extensions' local settings
are retained.

The native host reads its Chromium ancestor's actual `--user-data-dir`, validates
it against the local workspace profile root, and registers only the matching
profile pipe. Workspace registrations reject duplicates. UI commands, recovery,
URL polling and remote session binding carry the same token as the pane; a
window ID alone is not globally unique across profiles. Missing/stale pipes and
foreign/ambiguous windows fail closed, without using the shared pipe. Existing
window protection and containment rules still apply. Workspace switching parks
native windows; it does not close another profile. Engine switching closes old
panes but retains their URLs and both engines' profile roots.

V1 does not prune bookmarks, remove retained browser data, or claim that
Chromium's OS-bound encrypted credentials are portable between machines.

Local shell commands read the window ID and profile token from one atomically
published `browserwin-<owner-pid>-<shell-id>.txt` snapshot. Missing, incomplete, or old
numeric-only bindings cannot fall back to the shared profile while isolation is
on. Explicit CLI `--profile`/environment targets remain available; reopening the
exact pane refreshes its shell binding after a move or engine change.

Local binding filenames include the owning app PID, so two app windows with
the same shell counter cannot overwrite each other. Startup only clears its own
local binding namespace, not another live window's files.
