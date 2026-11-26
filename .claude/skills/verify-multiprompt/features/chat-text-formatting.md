# Chat text formatting

Source files: src/chat_inline_code.zig, src/chat_markdown.zig, src/link_detect.zig, tools/fixtures/inline-stubs.js, tools/chat-text-formatting.test.js, .github/workflows/chat-text-formatting.yml, .claude/skills/verify-multiprompt/features/chat-text-formatting.md
CI workflow: chat-text-formatting.yml

## Sub-features

- Inline code draws inside its own rounded, tinted pill: padding on both sides, a line of vertical padding, a radius that stays under half the chip height, and a chip colour and text colour that differ between the light and dark themes and separate the code from the sentence around it.
- A list marker, bullet or number, is right-aligned inside the marker column, so every marker lines up against the body, and a wrapped list line stays on the indented body column.
- A labelled Markdown link `[label](url)` shows the label and keeps the exact target, and `file:///` addresses count as links next to `http://`, `https://` and `www.`, while `javascript:` and `mailto:` stay plain text.

## How to get to it (user POV)

Read a chat reply that contains inline code, a labelled link, or a bulleted or numbered list, and open Chat View with Alt+C.

## Driving it with GitHub CI

The `Chat text formatting` workflow runs on a Linux runner for a pull request that changes the files above. It installs pinned Zig 0.16.0, then runs `tools/chat-text-formatting.test.js`.

That test executes shipped source rather than a copy of it. It runs the chip padding, wrapping and colour tests in `src/chat_inline_code.zig` against the real `metrics`, `chipWidth`, `fits`, `chipRect`, `chipRadius`, `chipColor` and `textColor` functions with the Windows painter removed, the scheme test in `src/link_detect.zig` that keeps `file:///` a link and `javascript:` plain text, the labelled-link test in `src/chat_markdown.zig` that renders `[notes](file:///C:/notes.md)` as its label over the exact target, and the `AUDIT` list layout harness in `tools/chat-view-gaps.test.js` that drives the real `chatFlowBlock` with paint on and requires every list marker to carry `DT_RIGHT` and end six pixels before the body column at every list level.

One artifact named `chat-text-formatting` holds `summary.json` and the TAP log. The PR selector owns these files through `CI workflow:`, so `src/link_detect.zig` and the shared inline-stubs fixture stop being unowned user-facing files. The verifier waits for this workflow on the exact PR head, requires a successful conclusion, downloads the artifact and gives the independent judge the raw check names and the run receipt.

## Gotchas

This proves the formatting decisions, not the pixels on screen. Chip painting, the Windows text run and the marker draw still need the desktop journeys that own `src/chat_render.zig`, such as chat-still and server-chat. Removing the inline code painter from the harness is deliberate: the chip metrics and colours are the parts that decide padding, wrapping and contrast, and the painter is a single `fillRoundRect` call over the same rectangle.
