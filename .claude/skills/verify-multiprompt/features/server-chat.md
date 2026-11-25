# Runner-owned server chat

Source files: tools/verify-server-chat/*, src/ssh*, src/tmux*, src/chat*, src/console.zig, src/session.zig, src/main.zig, build.zig, build.zig.zon, .claude/skills/verify-multiprompt/control.ps1, .claude/skills/verify-multiprompt/control-library.ps1

Verify on: push, pull_request

## Sub-features

- Open a saved Linux tmux chat and copy its persisted seed reply from the Windows Chat View.
- Send a message with the real composer and Enter. Require exactly one server-side provider receipt and exactly one copy of the reply in the copied visible transcript.
- Type `/clear`, dismiss autocomplete, and send it. The production composer terminates bare trigger tokens with one space, so require exactly one provider receipt of `/clear ` and its rendered reply, then send another message successfully.
- Close Chat View with Alt+C and reopen it. The last server reply must still appear exactly once in the copied transcript.
- Authenticate with a new ed25519 key for this job. The private directory and file allow only the Windows runner SID, with inheritance removed.
- Retain an actual desktop recording and evidence even when the journey fails.

## How to get to it (user POV)

Select the saved server tab with Ctrl+1. Open Chat View with Alt+C. Type in the composer and press Enter. Use `/clear` the same way, then send another message.

## Driving it with control.ps1

Preconditions: GitHub `windows-latest`, the branch executable, WSL2 Ubuntu 24.04 with OpenSSH server, tmux and Python, Windows OpenSSH client, and FFmpeg. `verify.yml` installs these for `feature=server-chat`.

`control.ps1 -Feature server-chat` delegates to `tools/verify-server-chat/drive.ps1`. This is a real networking journey, not the fake SSH/tmux boundary used by `chat-delivery` and `chat-slash`. The runner owns both ends of the loopback connection on port 2222. Linux uses a dedicated `mpverify` user, key-only authentication and a real tmux session. The unmodified production host and connectors dispatch to a deterministic stream-json provider instead of making paid Claude calls. The provider writes normal Claude transcript records and independently records its input. Seeding waits for the production host's persisted `host.status=ready` event before submitting its first message; a live socket alone does not mean the provider has initialized.

The PR verifier can select this map automatically. Do not dispatch another run while its push-triggered checks are running. For a separate authorized manual run, select `feature=server-chat` in `verify.yml`.

Require `result.json` status `passed`, all five named cases passed, zero app processes after owned-job cleanup, `keyRemoved=true`, and successful `videoExit`. Watch `journey.mp4`; inspect `open.png`, `send.png`, `clear.png`, `after-clear.png`, `reopened.png`, copied text, `*-server.json`, `key-acl.json`, `ssh-preflight.txt`, `sshd.log`, `actions.json`, `doctor.json` and `build.json` in `verify-server-chat`. The private key and profile never enter the artifact. Cleanup stops the dedicated WSL distribution and deletes the disposable Windows profile.

## Gotchas

- This proves real server transport and that the `/clear` journey runs through the UI, host and provider. It does **not** prove paid Claude context erasure, or fix the separate server-chat clear behavior tracked by SOFT-2420. The deterministic provider echoes `/clear`; it does not fabricate a reset acknowledgement or alter the production reader.
- Initial saved-tab and provider configuration are seeded before launch. User actions after launch use SendInput, not UI setters or forged transport responses. Server snapshots are read-only SQLite reads over real SSH.
- Never use a shared VPS, production key, real account, or user computer. WSL and its test user belong to this disposable GitHub runner. Its sshd offers `curve25519-sha256` key exchange because the bundled Windows `ssh-keyscan` fails on Ubuntu's default `sntrup761x25519-sha512@openssh.com` offer. Authentication remains key-only with an ed25519 host key.
- WSL2 provides the Linux kernel and ext4 file locking required by concurrent production-host SQLite writers. WSL1 does not respect those locks and can corrupt event sequences or raise disk I/O errors. Startup proves cross-process SQLite exclusion in the Linux user's home before seeding and records the kernel and integrity result in `server-start.stdout.log`. Windows reaches the WSL2 server through its default localhost forwarding; `ssh-preflight.txt` must prove that connection before the app launches.
- Every synchronous native command uses `Invoke-ServerNative` in `native.ps1`. It retains `<name>.stdout.log`, `<name>.stderr.log` and `<name>.exit-code.txt`; only the process exit code decides success. This includes key generation, WSL paths, Linux startup, host-key scan, SSH preflight, snapshots and shutdown. Successful `ssh-keyscan` banner comments remain in `ssh-keyscan.stderr.log`. The recorder and owned app retain their existing process handles and stderr logs; the recorder exit code is checked on shutdown. The video probe retains its stdout, stderr and exit code too. Cleanup runs `stop.sh` as a file and retains the production host logs in `linux-host/` before shutting WSL down.
- A green source test is not Windows proof. The run and video are required.
