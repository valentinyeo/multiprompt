# Linked skill folders

Source files: src/skills.zig, src/chat_composer.zig, src/command_palette.zig, src/sidebar.zig, src/main.zig, .claude/skills/verify-multiprompt/control.ps1, .claude/skills/verify-multiprompt/skill-menu-links.ps1

## Sub-features

- A skill folder installed as a folder link (junction) under the user skill root appears in the Chat View skill menu.
- A plain skill folder next to it still appears.
- Choosing the linked skill from the menu puts its slash name in the composer.

## How to get to it (user POV)

Open Chat View, press Ctrl+K, type `skills`, press Enter to open the Skills list, filter by the skill name, then press Enter to insert it.

## Driving it with control.ps1

Before launch the harness writes two skill folders under the isolated `USERPROFILE`: `plain-proof` and a real folder-link named `valentin-mode` that points at a folder outside the skills root. The journey opens Chat View on the initial CMD tab, opens Ctrl+K, types `skills`, presses Enter, screenshots the unfiltered skills list, filters with `valentin`, screenshots the filtered list, then presses Enter and requires the composer text to become `/valentin-mode `. The evidence is `skill-menu-skills.png`, `skill-menu-linked.png`, `skill-menu.json` and `result.json`.

## Gotchas

- Skill discovery reads `USERPROFILE`, so the fixture lives in the isolated profile and never touches a user machine.
- The palette rows are custom-painted; the journey relies on the app-painted screenshots plus the composer text it reads back, not on invented accessibility rows.
- The local CMD session is enough: the menu and the insertion are local discovery, no AI agent or remote skill execution is involved.
