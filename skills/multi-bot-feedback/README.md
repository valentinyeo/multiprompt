# /multi-bot-feedback

One command for user-requested and agent-initiated Multibot reports. All adapters follow `SKILL.md` and call the existing `multibot-feedback --report` runtime tool. No desktop action or keyboard shortcut is added.

Vstack Maintainer installs these files, not the coding worker:

| Agent | Install |
| --- | --- |
| Claude Code | Copy this folder to `~/.claude/skills/multi-bot-feedback/`; `SKILL.md` supplies `/multi-bot-feedback`. |
| Codex | Copy this folder to `~/.codex/skills/multi-bot-feedback/` for agent invocation; copy `codex.md` to `~/.codex/prompts/multi-bot-feedback.md` for `/prompts:multi-bot-feedback`. Codex's built-in custom prompt namespace cannot register a bare `/multi-bot-feedback`; an ordinary message with that name invokes the installed skill. |
| pi | Copy this folder to `~/.pi/agent/skills/multi-bot-feedback/`; copy `pi.md` to `~/.pi/agent/prompts/multi-bot-feedback.md` for `/multi-bot-feedback`. Agents can also invoke the skill directly. |
| Antigravity | Copy `antigravity.md` to the workspace's `.agents/workflows/multi-bot-feedback.md` (older releases use `.agent/workflows/`), and copy `SKILL.md` to `multi-bot-feedback/SKILL.md` alongside that workflow. |

For isolated agent accounts, install within each account's own home or workspace. Do not copy credentials. Existing chats may need to reload skill discovery.

The updated desktop reader automatically publishes `src/multibot_feedback.py` as `~/.multiprompt-runtime/multibot-feedback`, plus desktop-version metadata. Its contents change the runtime fingerprint automatically. `tools/install-mp-talk.sh` also ships the same source as the PATH command; it is not a second implementation. Vstack Maintainer must refresh the tool as well as installing the command files. This PR does not install, deploy or change any chat configuration.

`--report` adds expected/actual behavior, current chat identity, desktop version, runtime fingerprint/generation, and up to six trimmed, redacted `--step` entries. The agent supplies recent steps from its current conversation, so no provider-specific transcript parser is required. Missing identity/version data is recorded as `unavailable`. Screenshots remain optional, reviewed PNGs; text redaction cannot inspect pixels.

Reports use the existing private log and host queue when the caller has no agent token. The host files them with its existing credentials; without a credentialed host they remain queued. Repeated open titles/signatures receive another detailed occurrence instead of another ticket. Closed or archived reports are not reused. Existing wish, attachment, ranking and drain callers retain their behavior.

Errors default to Multi Bot Bugs; `--kind feature` selects Multi Bot Features. Handover/reconnect keywords select Seamless Session Transitioning. Android/phone keywords in the report or chat select an existing Android bug/feature label, falling back to Multiprompt Android. Missing owner labels keep the report queued rather than silently routing elsewhere.
