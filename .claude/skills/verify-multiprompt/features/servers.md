# Servers

Open the Servers screen, add a disposable server, test it, then remove it. The servers journey proves that Multibot signs in with its own key and that removal cuts access. IGSH-1928: Settings and Ctrl+K both expose Servers. Adding a name, address, user and optional port produces one setup line. Test explains failures. Removal revokes the app key.

## Sub-features

- `servers-both-entry-points`: the same Servers screen opens from Settings and from Ctrl+K.
- `servers-plain-failure`: Test before the setup line is pasted shows the plain missing-key error.
- One-time paste: the app-generated setup line runs once in a disposable POSIX home.
- Connected: Test then reports that Multibot signs in with its own key, in under 120 seconds from form entry.
- Remove: the native confirmation runs the app's real remote revocation command and the same OpenSSH login then fails with exit 255 and Permission denied.

## How to get to it (user POV)

- Open Settings, then Servers.
- Press Ctrl+K and run Servers.
- Enter a name, address, user and optional port, copy the one setup line, run it once on the server, then press Test.
- Remove deletes the server and takes the key off it.

## Driving it with control.ps1

Dispatch the existing `verify.yml` workflow with `feature=servers` and `tag=v0.28.1681` (or a later published release). This journey is manual-only, not part of the default matrices.

The ordinary harness isolates APPDATA, LOCALAPPDATA, USERPROFILE and HOME, checks the released executable digest and marker, and launches the real Windows application. `servers.ps1` opens Settings, then Ctrl+K and Servers, enters a disposable loopback target through native keyboard and mouse input, requires the plain missing-key error, and presses Test. The app-generated setup command is read from the form and written to a script file without a byte-order mark. Git Bash runs that file once in a disposable home, because a byte-order mark on standard input makes bash look for a command named after it.

A real Windows OpenSSH positive-control login must work before removal. The native Remove confirmation then runs the app's actual remote revocation command. The authorized-key row must disappear, the endpoint must record exactly one successful removal command, and a later identical OpenSSH login must fail with exit 255 and Permission denied, not a network failure.

`servers-proof.json` and before, action and after screenshots retain timings, authentication events, remote command results and cleanup evidence. Private app key files are deleted before the harness copies scratch evidence. The SSH endpoint's host key exists only in memory.

## Gotchas

- Only the remote server is replaced: a loopback Paramiko endpoint executes the production POSIX commands using Git Bash in an isolated home. It accepts only public-key authentication, `true` and the revocation command, and never edits an existing Windows or remote connection.
- The released app, form, setup and removal commands, crypto authentication and Windows OpenSSH are real.
- Production migration and 1Password isolation need the separate read-only live check on existing servers.
- Never pipe the setup line into bash on standard input from Windows PowerShell: the redirected stream starts with a byte-order mark.
