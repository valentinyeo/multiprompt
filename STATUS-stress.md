# Stress run on the DEV app (IGSH-1266)

## What is built

`tools/dev-laptop-journey.sh` gained a `stress` journey (plus `focus`, `shot`, `ctrl-t`). Every
keystroke goes through `guard`, which first asks the laptop for the foreground window's **process id**
and only types when it equals the running `multiprompt-dev` pid - so keys can never land in his app.

Cases coded so far, each asserting against the server transcript of the chat it drives (new
`~/.claude/projects/**/<sid>.jsonl` after the case starts, counting user/assistant rows and printing
the last reply):

1. first message right after Ctrl+T - coded
2. ten messages, each waiting for its reply - coded
3. three messages sent without waiting - coded
4. one ~4000 character multi-line message - coded
6. switch tab and back mid-reply - coded
7. terminal view and back - coded
9. kill the dev app's ssh child, send during reconnect - coded

5 (image paste + "what colour"), 8 (restart and reopen the chat), 10 (second Ctrl+T chat while the
first replies) are **not coded yet**.

## Runs

| run | dev build | case 1 | notes |
|---|---|---|---|
| 1 | 41241349333 (master incl. Runner A 1acf2a12) | NOT RUN | blocked before the first keystroke |

`runs=0` clean, so this is FAIL. Nothing was typed into any of his windows and no server tmux session
was created by the rig.

## Blocker, precisely

- The dev build from `dev-build.yml` run 41241349333 installed and **runs** on the laptop
  (pid 16096), window found by pid at hwnd 9636698.
- `SetForegroundWindow` from the VPS session is refused by Windows for a background process: after
  `ShowWindow + SetWindowPos` the window is maximised on DISPLAY1 (`-2560,-493 2048x1280`) but the
  foreground stays on another pid (8148), so `guard` correctly refuses and the journey stops.
- `tools/dev-laptop.sh place` still looks for a `MultipromptDevWindow` class; the dev window's class
  is `ZigShell` and the dev marker is a window property. A process-based rewrite of `place` was
  started and reverted when its quoting broke; it must be redone in the runner's style (the runner's
  own pid lookup already works).

## Next step

Attach the input thread to the dev window (AttachThreadInput with its thread id) or use
`SetForegroundWindow` from a helper that the shell allows (e.g. `keybd_event(VK_MENU)` + click on the
window's title area, which is what the app's own second-launch path does), then rerun
`tools/dev-laptop-journey.sh stress`. Nothing else in the stress plan needs his app.


---

# Round 2

Ordered tasks from brief-stress2. Nothing here claims a PASS; `runs` stays 0.

## 1. Foreground: reuse BringToForeground - NOT PROVEN

`tools/dev-laptop-journey.sh focus_dev` now loads the same algorithm as
`.claude/skills/verify-multiprompt/control-native.cs` (AttachThreadInput to the foreground and target
threads, ALT down, AllowSetForegroundWindow, BringWindowToTop, SetForegroundWindow, ALT up) instead of
the plain SetForegroundWindow that Windows refuses from a background process.

The check (one Ctrl+T on DEV, foreground pid == DEV pid) did not pass: `focus_dev` printed nothing,
i.e. the inline `Add-Type -TypeDefinition` block did not compile under the nested bash/PowerShell
quoting. The robust route is to ship the C# as a file: base64 chunks to `%TEMP%`, join, `Add-Type
-Path`, then call `[VerifyNative]::BringToForeground(hwnd)`. That upload is half-working - small
`lh write` chunks succeed, but a later chunk failed and the 0-byte assembled file made `Add-Type`
a no-op - so it needs chunk-size/escaping work before it can be trusted.

## 2. `tools/dev-laptop.sh place` - NOT DONE this round

Still finds `MultipromptDevWindow` by class. The DEV window's class is `ZigShell` (the dev marker is a
window property), so it needs the pid-based lookup the journey script already uses.

## 3-6. Not started

DEV identity (title/taskbar "Multibot DEV", visible badge, updater disabled in DEV with red-first
tests), the 20:59 stable-exit read, the missing stress cases 5/8/10, and the stress loop are all
untouched this round.

## Hard rules respected

His stable window was never focused, moved or typed into; his app was never relaunched; no server tmux
session was created; the dev app (pid 16096, build 41241349333) is still installed and running on
DISPLAY1 for the next attempt.

RUNNER DONE stress FAIL 0.28.1183 runs=0
