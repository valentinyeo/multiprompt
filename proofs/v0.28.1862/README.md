# Released-app proof, v0.28.1862

Release: `v0.28.1862` (tag commit `73006e2dd`), published 2026-11-23T02:29:21Z.
Executable SHA256: `51489fdadde98bc50313f9651187769133cc7a6d8ea7200696423d0aa0de0b63`.
The tag contains `4629193865` (SOFT-2883, SOFT-3075) and `3f4b98b01` (SOFT-3086).

| Image | Check | Run |
| --- | --- | --- |
| `ctrl-t-mul-before-refresh.png` | Ctrl+T, `mul`, sibling rows cached, highlight moved Down to `multiprompt` | [45101103523](https://github.com/valentinyeo/multiprompt/actions/runs/45101103523) |
| `ctrl-t-mul-after-refresh.png` | Same picker after the held SSH listing was released: `multiprompt-ios` inserted above, highlight still on `multiprompt` | [45101103523](https://github.com/valentinyeo/multiprompt/actions/runs/45101103523) |
| `dark-mid-skill-sent.png` | Sent message keeps `why is this not done via /pill-proof ?` as plain text, no skill pill, no skill run | [45101103350](https://github.com/valentinyeo/multiprompt/actions/runs/45101103350) |
| `dark-skill-sent.png` | Leading `/pill-proof` still becomes the skill pill and is delivered as a skill | [45101103350](https://github.com/valentinyeo/multiprompt/actions/runs/45101103350) |

Both runs drove the downloaded release executable, not a branch build: `build.json` records
`tag: v0.28.1862`, `version: 0.28.1862`, `candidate: false` and the same executable hash in both runs.

## Picker refresh (SOFT-2883, SOFT-3075)

`result.json` status `passed`, check `ctrl-t-mul-highlight-stable`: `cwd=/work/projects/multiprompt`,
`host=2`, `beforeCount=27`, `afterCount=28`. Enter was pressed once, after the after-refresh
screenshot, with no arrow keys in between, and the saved tab took exactly
`/work/projects/multiprompt` (not the `multiprompt-android` or `multiprompt-ios` sibling).

The production palette trace moved from 27 rows to 28 rows while the picker was open; the new
row id `6736` (`multiprompt-ios`) pushed the highlighted row down one slot, and the highlight
followed the folder, not the row index.

Row layout in both screenshots: folder name first, dimmed full path second, host label
`remote-3` in a right-hand column clear of the visible scrollbar.

Boundary: the SSH listing is a fixture process that serves the cached and refreshed folder
lists. The released app itself paints, sorts, highlights and saves the selection. No real
server, SSH or agent is involved.

## Slash skills (SOFT-3086)

`result.json` status `passed`, check `IGSH-928 skill pill pixels`: all 18 captures pass, including
`dark-mid-skill-draft`, `dark-mid-skill-sent`, `dark-end-skill-draft`, `dark-end-skill-sent`,
`dark-skill-draft` and `dark-skill-sent` in both themes.

Mid-message and trailing skill mentions render and deliver as plain text (ink 0, fill 0, no pill).
The leading mention still gets accent glyph ink and the pill fill, and is delivered as a skill.

The literal in the journey is `/pill-proof`, not `/board-drain`, because the journey registers a
real skill definition named `pill-proof` in the isolated home. An unregistered name such as
`/board-drain` renders plain either way and would prove nothing about the mid-message fix.

Boundary: delivery is to a local CMD console, the journey's documented stand-in. The screenshots
prove the sent text, its painted form and the delivery path, not execution by an external agent.
