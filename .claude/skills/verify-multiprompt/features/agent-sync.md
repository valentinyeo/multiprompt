# Chat names follow into Hypertask

## Sub-features

- A chat keeps its one agent id across a published rename.
- The installed 50-second user timer sends the exact name through the official Hypertask CLI.
- Linking the same id to a second chat is refused.
- A legacy shared-id clash blocks all renames.
- Unlinked chats and unrelated agents remain unchanged.
- Dry-run and repeated sync do not rename agents.

## How to get to it (user POV)

Install the talk tools, link a chat with `mp-agent-sync link --tmux SESSION --id AGENT`, then rename that chat in Multibot. The desktop publishes its new name through the reader's `chat_names` protocol. The linked Hypertask name follows within one minute.

## Driving it with verify-agent-sync.py

Select `agent-sync` through `verify.yml` or the PR verifier. This is a Linux journey, not a Windows desktop journey. `verify.yml` creates a disposable Linux user with a real systemd user manager. It installs the talk tools and a checksum-verified official Hypertask CLI. The driver submits names through the production reader stdin protocol, links an id through the installed command, and observes the real timer's HTTP requests. It waits for two successive activations without changing the production timer interval.

Require `result.json` to show exact HTTP PATCH id and name, retained entry and `@agents` map, refusal of a duplicate link and a legacy clash, unlinked safety, an observed 40–60 second poll interval and rename within 60 seconds. `requests.json` records the actual CLI HTTP traffic. `doctor.json` records the installed source and CLI hashes and timer unit. `journal.txt` records real service activations. Cleanup stops owned units, closes the HTTP server and removes the disposable user home.

The PR verifier runs the identical harness against head and merge base. Base must fail a behaviour assertion, such as the installer not exposing the sync command, rather than an import or missing-source execution error.

## Gotchas

Only the Hypertask HTTP service is replaced by a loopback stand-in. It implements the CLI's real list and rename endpoints and independently records PATCH requests. No production credentials, live agents or remote boards are used. This proves CLI transport and scheduling, not the production Hypertask service or Windows rename input. The legacy-clash case deliberately corrupts an isolated link fixture, then restores it before the timed rename. Creating or archiving agents is outside this PR.
