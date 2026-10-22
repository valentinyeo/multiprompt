# Workspace browser profiles

## Sub-features

- Six stable workspace IDs launch six distinct live Edge profile roots.
- A user-created synthetic bookmark survives workspace rename, reorder,
  single-to-multi and multi-to-single conversion, close and reopen.
- Every lifecycle observation independently reads the workspace ID, live browser
  command line, unchanged profile root and Edge-written bookmark file.
- Real zsb requests reach the target workspace's native host, including while a
  different workspace is foreground; the other profile lacks the target bookmark.
- A separate synthetic pre-upgrade install retains its original profile root,
  bookmark/cookie/Local State marker bytes and owner while a new workspace launches
  a separate empty profile. Neither the fixture nor any account contains real data.
- The original fresh six-profile journey remains unchanged; cleanup owns every process.

## How to get to it (user POV)

Alt+A opens a browser pane. Ctrl+N creates another workspace in single-window
mode; Alt+2 through Alt+7 select these six workspaces. Ctrl+K exposes Rename
Workspace, Sort Workspaces (Ctrl+Up moves the selected row), Window Mode,
Close Workspace and named workspace reopening. Browser Open URL accepts a URL inside the
palette; Ctrl+D saves a favorite in the actual owned Edge window. Agents use zsb with their exact shell key.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=browser-workspaces`.
The fresh GitHub desktop uses installed Edge and the repository's unmodified
unpacked extension at the app's normal development extension path. After Edge
publishes the actual extension ID, the harness registers the matching native
host executable in the disposable runner's HKCU, removing it during cleanup.
In each profile, open edge://extensions/, turn on Developer mode through its
visible UI Automation toggle, and require the real native pipe. No browser
flags, policies or preference files bypass this user consent step.
Only the separate upgrade preflight seeds an old-format session and synthetic
Bookmarks, Network/Cookies and Local State marker files before starting the app.
It never launches Chromium on these deliberately synthetic marker files. The
new workspace launches a real separate root; marker hashes and ownership must
remain unchanged. `workspace-upgrade.json` and `upgrade-process-tree.json` retain
the proof. The Zig migration regression additionally resolves the original root
and native token through the production mapping, reopens it and verifies every
marker remains byte-for-byte intact. The main six-profile journey still seeds
no app state, preferences or bookmark files.
Common app keystrokes use the strict Doctor-verified main-window foreground guard.
Browser-only keystrokes validate the exact profile PID/HWND and root owner;
A real hit-tested title-bar click can activate the window without selecting a tab.
GetGUIThreadInfo validates its actual keyboard focus without joining input queues.

Create a second workspace with Ctrl+N to persist the fresh layout, then return
to the first workspace and open both panes before creating the remaining four.
Hash all six persisted IDs independently and
require completion markers, Local State and six real profile processes.
In the sixth workspace, rename it to IGSH224 Journey using the existing inline
palette editor (Ctrl+A, type, Enter), without transferring native focus; use Browser Open URL to navigate to a synthetic
example.com URL. Select its newly opened tab with Ctrl+9 in the verified Edge window,
independently read its address bar, then bookmark it with Ctrl+D. Move the workspace
one position earlier, convert to six standalone windows and back, then close
and reopen the named workspace. At each stage, assert the same ID, root and
bookmark and saved active URL, and capture a screenshot plus saved state in workspace-lifecycle.json.

Use the app-owned loopback zsb listener to request the target URL, switch to a
different workspace, request the parked target and the foreign workspace URL,
and require distinct correct replies without switching the active workspace.
Inspect workspace-host-processes.json, zsb request/reply artifacts, result.json,
workspace-lifecycle.json, bookmark-action.png and all lifecycle screenshots.

## Gotchas

Offline account bypass is not real sign-in. Real signed-in browser credentials,
Valentin's actual existing bookmarks are checked by the runner on laptop1 after
release/install, never on this server. Synthetic upgrade continuity is checked
on GitHub; real sign-in/decryption is not claimed by marker preservation. This
journey uses synthetic fixtures, public URLs and new favorites, not private data.
It does not prove remote SSH/tmux, sync, Chrome engine switching or every menu
entry. Missing extension, native host, bookmark, identity or lifecycle state
fails rather than skipping an action. Six browsers can each need a minute.
