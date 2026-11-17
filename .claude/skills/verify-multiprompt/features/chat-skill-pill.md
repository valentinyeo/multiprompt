# Skill pills

Source files: src/chat*, src/terminal*, src/markdown*, src/claude*, src/tmux*, src/message*, tools/chat-history-reader.py, tools/verify-chat-delivery/*, src/main.zig, build.zig, build.zig.zon, src/command_palette.zig, src/shortcuts.zig, .claude/skills/verify-multiprompt/control-feature-chat-skill-pill.ps1

## Sub-features

Known complete skill names and slash commands use one accent foreground and a soft rounded background with a slight lower edge. Arguments stay normal. Both the composer and user messages use the same exact catalog-name rule; unknown names and paths stay plain. Native caret positions, wrapping, selection, undo and sent text remain unchanged.

## How to get to it (user POV)

Type a known skill in Chat View, or pick one using the existing command menu. No new setting or action.

## Driving it with control.ps1

Run on GitHub Windows only:

```sh
gh workflow run verify.yml --ref ceo/IGSH-928 -f feature=chat-skill-pill
gh workflow run verify.yml --ref ceo/IGSH-928 -f feature=chat-skill-pill -f tag=v0.28.912
```

The same harness must fail `IGSH-928 skill pill pixels` on the old release and pass on the shipped release. Download `verify-chat-skill-pill` and inspect its ten named screenshots, `skill-pill.json`, `skill-pill-summary.json`, `result.json` and action trace.

The journey creates a real skill definition under the isolated profile before launch. In each theme, it opens a fresh CMD tab through the palette, types unknown slash text, replaces it with a plain message, sends that message, then types and sends the known skill plus arguments. Screenshots use screen capture; native HWND client bounds isolate composer or transcript pixels. The oracle requires both accent glyph pixels and the soft blue pill fill, and requires neither for plain messages and unknown names.

## Gotchas

Sent-history measurements stop at the owned composer's top edge. The transcript HWND extends behind the composer, so its full bounds also contain placeholder text and microphone pixels. Draft measurements still use the native Edit bounds.

The fixture skill is discovered through the production local skill scanner. Delivery uses the actual local CMD console, not a remote AI provider; the journey proves the visible message treatment, not execution of a skill by an external agent. It does not alter the app's files after launch. Existing composer tests cover native scale, DPI, editing and text rendering.
