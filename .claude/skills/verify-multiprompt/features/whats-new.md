# What's new

## Sub-features

Production release titles and ticket IDs in the native changelog, including historical releases.

## How to get to it (user POV)

Open Ctrl+K and choose Changelog. Navigate with Page Down and Home, then close with Escape.

## Driving it with control.ps1

Dispatch `verify.yml` with `feature=whats-new` and no release tag, so the executable and source match. The journey selects palette target 6241, opens the overlay with Enter, pages into history, returns Home and closes it. Each key must change the visible surface. Screenshots capture the first page, historical rows and return.

The driver independently reads production `src/changelog.zig` and saves the release titles and ticket IDs as `whats-new-source.json`. Compare these with `whats-new-first.png` and `whats-new-history.png` by eye. The build stamps the first version; later versions come from source. The journey does not seed app state or open a ticket URL.

## Gotchas

A green result proves input and visible changes, not title correctness. Screenshot review against the source artifact is required. This is an on-demand journey, not a claim of completed verification.
