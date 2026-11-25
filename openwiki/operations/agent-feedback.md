# Multibot agent feedback

Fresh hosted Claude, Codex and Pi chats receive Multibot tool guidance. The browser pane uses `zsb`. Computer view is view-only unless the user grants control. Browser commands do not operate Computer.

To describe a missing capability:

```sh
multibot-feedback "a browser screenshot shortcut" --why "capturing a screenshot takes too many steps"
```

Each wish is saved in the local user's private feedback log first. The local record keeps session and working-folder context. Never put credentials in feedback. The command rejects known credentials and paths. Session names and folder names are not attached automatically. Review the deliberate want and why before submitting; automatic checks cannot recognize every secret.

Wishes go to the Multi Bot board, 13734. Review them at https://app.hypertask.ai/project?id=13734&view=agent-feedback.

When the chat has an agent `HT_TOKEN`, the command files or votes immediately. When it does not, the command uses the chat's own agent login: it reads `~/.config/hypertask-agents/credentials/sessions/<chat-slug>-agent-token`, where `<chat-slug>` is the live chat name lowercased, with each run of non-alphanumeric characters turned into one `-` (`Multi Bot Features` becomes `multi-bot-features`). The chat name comes from the published chat names under `~/.local/state/multiprompt/chat-names.json`, the same list `zsb` reads. The token is passed to the hypertask CLI for that one call. It is never printed, logged or bundled. The command also finds the CLI on `PATH` first, then `~/.local/bin/hypertask`. If no token file exists, the wish is still saved locally and appended to a shared server queue under the host account's state directory, and the output says `agent token unavailable`. `multibot-feedback --drain` submits that queue with the chat's agent login. It never falls back to the CLI's saved login for a write.

New board tickets have the existing Multiprompt and Agent Feedback labels. The board rejects ticket ids and long sentences outside quote blocks, so a ticket opens with short plain lead lines, then the full want, the full why and the app version and provider details, each inside a quote block. The title is the first ten words of the want, after the `Multibot wish: ` prefix. Session names, paths and local context are not attached. The two labels must already exist. The app version comes from the desktop build, not a manual field. Older clients without a version keep feedback local.

Wish titles are Unicode-normalized, case-folded and whitespace-normalized. Exact matches on labeled tickets are reused, including archived tickets. A matching deleted ticket stops submission instead of being recreated. Votes use untyped comments, which the board normally routes to agent activity. The command confirms `routedTo: log` and reads the agent identity and timestamp back. Older board routing can instead publish an untyped comment to people before the command detects the failure. Do not enable board submission where that legacy fallback is active. Each agent counts once per wish. Repeating the command by the same agent does not create another counted vote. A private advisory lock serializes submissions for the same wish on one host and OS user, even with separate home directories. Different OS users or hosts do not share that lock. Cross-host races can create duplicate tickets or activity entries; readback detects duplicate tickets when visible, but cannot prevent a later race. Duplicate activity entries from one agent count once. If multiple matching tickets already exist, the command stops for review. The board does not expose an atomic create-if-absent operation, so simultaneous first submissions can still create duplicate tickets.

The activity API returns at most 100 entries without an activity cursor. If that window fills, submission and ranking fail closed rather than miss older votes.

The output says `filed` with the ticket link only after reading the ticket and vote back. If the chat has no token or a board call fails, local feedback and the shared queue keep the row and the output says `queued, will be filed` with the reason. Run `multibot-feedback --drain` on the host (or wait for the agent host idle drain) to file queued rows once a token is available. A ticket or vote may nevertheless have reached the board before a failed response. Retry the same wish to reconcile it.

The shared queue is drained once per host. `--drain` treats every queue row saved before the cutoff `1795550400` (unix seconds) as already filed: it drops those rows without a board call and never refiles them, so the older backlog cannot arrive twice. Rows saved later stay queued until the board accepts them.

To rank actual votes in the current UTC week, run:

```sh
multibot-feedback --weekly
```

`--rank` is an alias. The week starts Monday at 00:00 UTC. The command lists wishes with at least one first vote in that week, highest count first, then title and link. It includes archived wishes and excludes deleted wishes. No timer or scheduled workflow is installed.

## Reviewed screenshots

Add up to four reviewed PNG files using repeatable `--attach` options:

```sh
multibot-feedback "a browser screenshot shortcut" --attach reviewed.png --attach another.png
```

The command never captures screens. Review every pixel before attaching: automatic secret text checks cannot inspect pixels. Each PNG must be at most 8 MiB and pass basic PNG structure checks. Invalid files stop submission before any board write. The command snapshots bytes in a private temporary directory using SHA-256 filenames; source paths and names are not sent to the board. The local log records hashes, not image bytes. Attachments are uploaded even if this agent already voted. Readback confirms each filename and size; retrying the same wish and image avoids another upload. A failed upload or readback leaves the local wish and reports that board submission was not confirmed. `--rank` and `--weekly` do not accept attachments.
