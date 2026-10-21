# Workspace focus

Return to a workspace and resume typing in its Chat View typing box or shell without clicking.

## Sub-features

- `workspace-focus-chat`: remember the selected session and Chat View typing box; verify text through the native Edit control's read-only text, retrieved with bounded WM_GETTEXT.
- `workspace-focus-shell`: remember the selected session and console; verify a command staged before switching executes after returning.

## How to get to it (user POV)

Use Alt+C for Chat View or the shell, Ctrl+N to create workspace 2, Alt+2 for workspace 1, and Alt+Right / Alt+Left to switch away and back.

## Driving it with control.ps1

Run `gh workflow run verify.yml -f feature=workspace-focus`. The workflow invokes `control.ps1 -Feature workspace-focus` against an isolated Windows instance. Follow the complete keyboard focus regression recipe in [Workspaces](workspaces.md#keyboard-focus-regression-journey). Require both `workspace-focus chat PASS` and `workspace-focus shell PASS`, matching saved session identity and focus, exact composer text, and the independently read shell-created marker. Missing assertions fail the job.

## Gotchas

Setup uses Ctrl+K `per tab` and Alt+C to enable Chat View for the local CMD session, waits for saved state and the visible owned Edit child, then foregrounds the frame and waits for that exact control's focus and initial text. An embedded console can remain foreground after Alt+C even though its ancestor is the app frame. No foreground repair or control-focus setter is allowed after workspace switching; only the workspace-pill tests click, never the typing box. No seeded state or private app messages are used. Local CMD needs no account or agent. This journey verifies workspace switching, not application restart; persisted focus round trips are covered by Zig tests.
