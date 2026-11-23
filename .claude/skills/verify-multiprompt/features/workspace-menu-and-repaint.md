# Workspace menu speed and session repaint churn

Measure the workspace menu and live-session repaint behaviour on a selected release with twenty real CMD sessions, without writing app state.

## Sub-features

- `workspace-menu-open`: clicking the workspace name paints the menu within 300 ms and the window message pump never stalls longer than 300 ms.
- `workspace-menu-hover`: the menu's row fill follows the real pointer onto each of three rows.
- `session-repaint-churn`: three Chat View sessions receiving continuous console output change the sidebar at no more than a few frames per second and never show a blank frame.

## How to get to it (user POV)

- The workspace menu opens from the workspace name above the sessions in the expanded sidebar.
- Rows are moved through with the real mouse; the current workspace row is not special.
- A session's Chat View opens with Alt+C, and Ctrl+1 through Ctrl+9 select a session.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=workspace-menu-and-repaint -f tag=v0.28.<build>`. With no `tag`, the branch is built instead. The workflow selects `control.ps1 -Feature workspace-menu-and-repaint`.

Preconditions:

- `control.ps1` writes one saved-tab file before launch: twenty local CMD tabs, five in each of four workspaces, first tab active, single-window mode. No state is edited after launch.
- Launch, read-only Doctor and the foreground window are the ordinary baseline; the run waits up to 180 seconds for twenty restored CMD sessions and four saved workspaces.

- **Open.** For five samples: record the workspace name point from the saved sidebar state, take a screen patch of the menu region, arm the message-pump probe, click the name with real mouse input, and poll that patch every 2 ms until at least 100 sampled pixels differ. Record the paint time, the time until the native `MultiPromptWorkspaceSwitcher` window is visible and the worst pump round trip in the sample. Capture `workspace-menu-open.png` on the fifth open, then dismiss on the menu's top padding.
- **Hover.** Open the menu once, read its window rectangle, then move the real pointer to the centre of rows one, two and three, waiting 350 ms on each. Capture `workspace-menu-hover-<row>.png` with the pointer position, hit window and foreground logged in `workspace-menu-hover.json` and `workspace-menu-hover-<row>.focus.json`.
- **Churn.** In three sessions: type `for /l %i in (1,1,20) do @(echo churn-line-%i & ping -n 4 127.0.0.1 >nul)`, press Enter and turn on Chat View. Return to the first session and capture presented frames at 10 fps for 30 seconds across the sidebar and the chat pane. Save `session-repaint-churn.json` with every frame, and `session-repaint-strip.png` as six full-resolution sidebar crops five seconds apart.
- **Proof.** Pass requires all five opens painted within 300 ms, no pump round trip over 300 ms, the highlighted band equal to the hovered row for all three rows with a measurable fill, at least 270 of 300 frames captured, at least eight chat-pane changes proving output reached the screen, zero blank sidebar frames and at most three sidebar changes per second.

## Gotchas

- This measures the released executable only when `tag` is set; a branch run measures the branch.
- Screen captures see presented frames. A repaint whose result is pixel-identical is invisible to them, so the churn count bounds visible change, not GDI invalidations.
- The menu region and sidebar width come from the saved launch state; a changed sidebar width or a collapsed sidebar fails the readiness checks instead of silently measuring the wrong rectangle.
- The console stand-in is a real local CMD console with a real ping delay, not a remote agent; no SSH, provider or account path is exercised.
- Not measured: the cross-window registry lock the menu used to wait on. Opening the menu under that contention needs a second app window and is a separate journey.
