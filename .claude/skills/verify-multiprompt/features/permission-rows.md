# Permission rows

## Sub-features

A pending permission has three rows. The chosen row stays marked; the others fade. The answer appears in chat. Three clicks and composer shortcuts 1, 2 and 3 must each send one provider choice.

## How to get to it (user POV)

Open Chat View on a Claude session with a pending permission. Click a row, or press its number in an empty composer.

## Driving it with control.ps1

Dispatch `feature=permission-rows` on the branch. Dispatch again with `tag=vX.Y.Z` for a checksum-verified pre-fix release. Both runs use the same synthetic Claude console menu and isolated profile. The tagged run captures the old pending buttons only; it does not claim the new behavior passes.

The branch run captures pending and each picked row, reads actual console key receipts, checks all three clicks and shortcuts, checks duplicate clicks and preserves an existing draft across clicks. Claude's denial is provider digit 4, although its displayed row is 3. The empty composer is checked after shortcuts. The normal owned-process cleanup and executable identity checks apply.

## Gotchas

Inspect the pending and picked screenshots against the approved design, including the tick, fading, answer echo, and surrounding chat. These are not automatically certified by the receipt or rectangle checks. This synthetic local console does not exercise the live approval.request provider protocol, a real Claude process, or a remote server. The ordinary question-card journey is `chat-options`; working dots are `chat-working`. Run them separately for surrounding behavior. Retain the build identity, screenshots, key/event receipts and cleanup evidence; no coverage is claimed until hosted execution and independent visual review.
