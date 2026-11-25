# Skill pills

Source files: src/chat*, src/terminal*, src/chat_markdown*.zig, src/chat_connectors/*, src/tmux*, src/message*, src/chat_history_reader.py, tools/verify-chat-delivery/*, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, src/skills.zig, .claude/skills/verify-multiprompt/chat-skill-pill.ps1

## Sub-features

A known slash skill or command gets a pill wherever it appears in the message: start, middle or end, in the composer while typing and in the sent message. A known skill named anywhere in the message runs it, and the sent message keeps every typed word, the skill word included, with the skill block after them. A skill word joined to other characters, as in a path, a web address or `xskill`, stays plain. Dollar-prefixed skills keep their existing behavior. Known complete skill names and slash commands use one accent foreground and a soft rounded background with a slight lower edge. Arguments stay normal. Both the composer and user messages use the same exact catalog-name rule; unknown names and paths stay plain. Native caret positions, wrapping, selection, undo and sent text remain unchanged.

## How to get to it (user POV)

Type a known skill in Chat View, or pick one using the existing command menu. No new setting or action.

## Driving it with control.ps1

Run on GitHub Windows only:

```sh
gh workflow run verify.yml --ref <branch> -f feature=chat-skill-pill
gh workflow run verify.yml --ref <branch> -f feature=chat-skill-pill -f tag=v0.28.912
```

The same harness must fail `IGSH-928 skill pill pixels` on the old release and pass on the shipped release. Download `verify-chat-skill-pill` and inspect its eighteen named screenshots, `skill-pill.json`, `skill-pill-summary.json`, `result.json` and action trace.

The journey creates a real skill definition under the isolated profile before launch. In each theme, it opens a fresh CMD tab through the palette, types unknown slash text, replaces it with a plain message, sends that message, then types and sends the same known skill mid-message and at the end of a sentence before sending it leading with arguments. The mid-message and end-of-sentence sends are the proof that a skill named anywhere runs and the typed words survive: the sent message keeps the typed line with its pill and carries the skill block after it, while the plain and unknown-name sends keep no pill and no skill block. Screenshots use screen capture; native HWND client bounds isolate composer or transcript pixels. The oracle requires both accent glyph pixels and the soft blue pill fill, and requires neither for plain messages and unknown names.

## Gotchas

Sent-history measurements stop at the owned composer's top edge. The transcript HWND extends behind the composer, so its full bounds also contain placeholder text and microphone pixels. Draft measurements still use the native Edit bounds.

The fixture skill is discovered through the production local skill scanner. Delivery uses the actual local CMD console, not a remote AI provider; the journey proves the visible message treatment, not execution of a skill by an external agent. It does not alter the app's files after launch. Existing composer tests cover native scale, DPI, editing and text rendering.
