# Workspace browser profiles

## Sub-features

- Six stable workspace IDs launch six distinct live Edge profile roots.
- A user-created synthetic bookmark survives workspace rename, reorder,
  single-to-multi and multi-to-single conversion, close and reopen.
- Every lifecycle observation independently reads the workspace ID, live browser
  command line, unchanged profile root and Edge-written bookmark file.
- Real zsb requests reach the target workspace's native host, including while a
  different workspace is foreground; the other profile lacks the target bookmark.
- Fresh launches do not create shared migration seeds; cleanup owns every process.

## How to get to it (user POV)

Alt+A opens a browser pane. Ctrl+N creates another workspace in single-window
mode; Alt+2 through Alt+7 select these six workspaces. Ctrl+K exposes Rename
Workspace, Sort Workspaces (Ctrl+Up moves the selected row), Window Mode,
Close Workspace and named workspace reopening. Browser Address focuses Edge's
address bar; Ctrl+D saves a favorite. Agents use zsb with their exact shell key.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=browser-workspaces`.
The fresh GitHub desktop uses installed Edge and the repository's unmodified
unpacked extension at the app's normal development extension path. After Edge
publishes the actual extension ID, the harness registers the matching native
host executable in the disposable runner's HKCU, removing it during cleanup.
No app state, browser preferences or bookmark files are seeded or edited.

Create six workspaces and panes. Hash the persisted IDs independently and
require completion markers, Local State and six real profile processes.
In the sixth workspace, rename it to IGSH224 Journey, navigate to a synthetic
example.com URL and bookmark it through real keyboard input. Move the workspace
one position earlier, convert to six standalone windows and back, then close
and reopen the named workspace. At each stage, assert the same ID, root and
bookmark and capture a screenshot plus saved state in workspace-lifecycle.json.

Use the app-owned loopback zsb listener to request the target URL, switch to a
different workspace, request the parked target and the foreign workspace URL,
and require distinct correct replies without switching the active workspace.
Inspect workspace-host-processes.json, zsb request/reply artifacts, result.json,
workspace-lifecycle.json, bookmark-action.png and all lifecycle screenshots.

## Gotchas

Offline account bypass is not real sign-in. Real signed-in browser credentials,
Valentin's existing bookmarks and their migration are checked by the runner on
laptop1 after release/install, never on this server. This journey uses only
synthetic public URLs and newly created favorites, not private profile data.
It does not prove remote SSH/tmux, sync, Chrome engine switching or every menu
entry. Missing extension, native host, bookmark, identity or lifecycle state
fails rather than skipping an action. Six browsers can each need a minute.
