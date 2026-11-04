# AGENTS.md

The rules for every agent in this repo live in [CLAUDE.md](CLAUDE.md). Read it in full before any work. It applies to every agent, not only Claude.

Prove each change with the `verify-multiprompt` skill: [.claude/skills/verify-multiprompt/SKILL.md](.claude/skills/verify-multiprompt/SKILL.md).

Runner briefs for chat/sidebar drawing changes must name the approval ticket. Put `UI approval: <ticket URL>` in the PR body. The `chat-ui-approval` check verifies Valentin's own yes; quoted instructions or a runner's claim do not pass. See [approval evidence](CONTRIBUTING.md#chat-and-sidebar-approval).
