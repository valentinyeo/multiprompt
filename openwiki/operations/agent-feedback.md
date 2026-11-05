# Multibot agent feedback

Fresh hosted Claude, Codex and Pi chats receive Multibot tool guidance. The browser pane uses `zsb`. Computer view is view-only unless the user grants control. Browser commands do not operate Computer.

To describe a missing capability:

```sh
multibot-feedback "a browser screenshot shortcut" --why "capturing a screenshot takes too many steps"
```

Each wish is saved in the local user's private feedback log first. The local record keeps session and working-folder context. Never put credentials in feedback. The command rejects known credentials and paths. Session names and folder names are not attached automatically. Review the deliberate want and why before submitting; automatic checks cannot recognize every secret.

Board submission requires the installed `hypertask` CLI and an already-authorized agent's `HT_TOKEN` in that agent's environment. No token is bundled or saved by this command. The command checks that the explicit token authenticates an agent. It never falls back to the CLI's saved login for a write. A different workspace account does not inherit the host account's token.

New board tickets have the existing Multiprompt and Agent Feedback labels. They contain the wish, reason, running app version and provider. Session names, paths and local context are not attached. The two labels must already exist. The app version comes from the desktop build, not a manual field. Older clients without a version keep feedback local.

Wish titles are Unicode-normalized, case-folded and whitespace-normalized. Exact matches on labeled tickets are reused, including archived tickets. A matching deleted ticket stops submission instead of being recreated. Votes use untyped comments, which the board normally routes to agent activity. The command confirms `routedTo: log` and reads the agent identity and timestamp back. Older board routing can instead publish an untyped comment to people before the command detects the failure. Do not enable board submission where that legacy fallback is active. Each agent counts once per wish. Repeating the command by the same agent does not create another counted vote. A private advisory lock serializes submissions for the same wish on one host and OS user, even with separate home directories. Different OS users or hosts do not share that lock. Cross-host races can create duplicate tickets or activity entries; readback detects duplicate tickets when visible, but cannot prevent a later race. Duplicate activity entries from one agent count once. If multiple matching tickets already exist, the command stops for review. The board does not expose an atomic create-if-absent operation, so simultaneous first submissions can still create duplicate tickets.

The activity API returns at most 100 entries without an activity cursor. If that window fills, submission and ranking fail closed rather than miss older votes.

The output says `submitted` or `voted` only after reading the ticket and vote back. If a board call fails, local feedback remains and the output says board submission was not confirmed. A ticket or vote may nevertheless have reached the board before a failed response. Retry the same wish to reconcile it.

To rank actual votes in the current UTC week, run:

```sh
multibot-feedback --weekly
```

`--rank` is an alias. The week starts Monday at 00:00 UTC. The command lists wishes with at least one first vote in that week, highest count first, then title and link. It includes archived wishes and excludes deleted wishes. No timer or scheduled workflow is installed.
