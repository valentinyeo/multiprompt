# Workspace focus

Return to a workspace and resume typing in its Chat View typing box or shell without clicking.

## Sub-features

- `workspace-focus-chat`: remember the selected session and Chat View typing box; verify text through the native Edit control's read-only UI Automation value.
- `workspace-focus-shell`: remember the selected session and console; verify a command staged before switching executes after returning.

## How to get to it (user POV)

Use Alt+C for Chat View or the shell, Ctrl+N to create workspace 2, Alt+2 for workspace 1, and Alt+Right / Alt+Left to switch away and back.

## Driving it with control.ps1

Run `gh workflow run verify.yml -f feature=workspace-focus`. The workflow invokes `control.ps1 -Feature workspace-focus` against an isolated Windows instance. Follow the complete keyboard focus regression recipe in [Workspaces](workspaces.md#keyboard-focus-regression-journey). Require both `workspace-focus chat PASS` and `workspace-focus shell PASS`, matching saved session identity and focus, exact composer text, and the independently read shell-created marker. Missing assertions fail the job.

## Gotchas

No clicks, UI Automation focus setters, seeded state or private app messages are used. Local CMD needs no account or agent. This journey verifies workspace switching, not application restart; persisted focus round trips are covered by Zig tests.
