# Chat startup failure

## Sub-features

Show one plain startup failure after the host stand-in stops, with no provider transcript.

## How to get to it (user POV)

Select the saved tmux tab and open Chat View.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-startup-failure` on GitHub Windows. The saved tmux tab has a known session ID and no provider transcript. The remote-shell stand-in calls the app-supplied reader's production `host_startup_failure` after the real event subscription. The reader persists and pushes its real events. Native keyboard selection and copy require one plain failure. Inspect `startup-failure-visible.png`, copied text, event evidence and cleanup in `verify-chat-startup-failure` before claiming proof.

## Gotchas

The host failure is simulated by a stopped thread, not a real host or provider. The Windows stand-in replaces Linux notifications and file locks. This does not prove real SSH, agent startup or provider behavior.
