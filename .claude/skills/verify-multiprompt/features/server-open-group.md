# Server runner group

Import one account shell tab into a named group, then import that same tab again.

## Sub-features

- A mocked account layout tab `{kind:tmux, group:Runners}` becomes one saved group named Runners.
- The imported tab's `group_id` equals that group's id.
- A second identical import adds no tab and no group.
- The desktop screenshot shows the resulting window.

## How to get to it (user POV)

- A lead on the server runs `node tools/mp-layout.mjs open --kind shell --tmux <session> --name <title> --workspace <workspace> --group Runners`.
- Multibot shows that shell tab in the named workspace and group.
- Running the same command again leaves the one tab in place.

## Driving it with control.ps1

This journey owns launch. It does not use the offline login bypass. Dispatch `gh workflow run verify.yml --ref <branch> -f feature=server-open-group`.

The driver builds the local account worker when needed, serves it on the account hostname with a private certificate, and enrolls one device. It publishes one tmux tab in workspace Multiprompt with group Runners through `mp-layout open --kind shell`, starts the branch executable, and waits until `session-server-group.json` has one group named Runners whose id equals the imported tab's `group_id`. It runs the same open again, writes that layout back once so the desktop imports it a second time, and requires the same tab count and the same single Runners group. It saves `before.png` after the first import and `after.png` after the second. Evidence stays in the job artifact. The driver stops only the processes it started and restores the hosts file and certificate.

## Gotchas

- Dispatch this journey. It is not in the automatic pull-request matrix.
- The live account service still has to advertise groups before a lead's real server command can place a group. This journey proves the desktop import against the mocked service.
- No remote machine, SSH credential, or existing tmux session is used. `--no-tmux` publishes the tab without starting a shell on the runner.
