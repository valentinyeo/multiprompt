---
name: verify-chat-still
description: Check the native chat scroll invariant after changes to history refresh, row measurement, padding, live replies, reconciliation or painting; run alongside verify-multiprompt chat-still before shipping chat changes.
---

# Verify that a shown chat stays still

The newest message visible when the chat appears must keep its screen position until the user deliberately scrolls. Moving that message while history settles makes the chat jump and flicker.

## Run

From the checkout, run `bash tools/verify-chat-still --self-test --replay --output evidence/chat-still-formal.json`.

The launcher installs `z3-solver==4.13.4.0` in an isolated cached Python environment. Python 3.12 and Zig 0.16.0 are the replay toolchain used by the GitHub check. This is a small focused check, not the desktop suite. By default, exit 0 means no modeled violation, 1 means a counterexample, and 2 means drift or an unavailable baseline. Read every reported property, not only the last line.

CI adds `--inherit-from <base-commit>`. Findings can then return exit 0 only if every modeled source file is byte-identical to that commit, after all requested mutation and replay checks complete. The JSON keeps every failure and witness and records `inherited_from`. Changed source, missing baselines, drift and failed replay cannot inherit. This classifies existing findings without changing the invariant; the default command still fails on them.

Run the matching real Windows journey with `gh workflow run verify.yml --ref <branch> -f feature=chat-still`. Follow [verify-multiprompt](../verify-multiprompt/SKILL.md) and [the chat-still recipe](../verify-multiprompt/features/chat-still.md) to inspect frame samples, screenshots, streaming receipt, Doctor and cleanup. Run desktop code only on GitHub-hosted Windows. The [Chat stillness workflow](../../../.github/workflows/chat-still.yml) runs both checks for chat-related PR paths.

## Why this tool

Z3 answers the scroll arithmetic question directly. The two native functions run synchronously on the UI thread; no event can interrupt their layout and scroll update. Their boundary states, not imaginary interleavings inside a function, are the meaningful transitions. A single-step invariant preserved by every passive transition composes over any sequence of those transitions. No verifier executes Zig UI code symbolically here. The source's scalar `held_y` expressions are translated to SMT, the rest of the covered function bodies are checked for drift, and every discovered counterexample can be replayed through the extracted production Zig functions.

## Coverage and assumptions

Last hosted-confirmed source/model sync commit is `5be4370e4d1dc44c3a80386954ee3b216b49819a`. Tests run `44348905357`, job `test-vps (1)`, passes all ten obligations, the ten guard-mutation replays, both native negative controls and nine exact-position regressions. Windows run `44348891482` passes the unchanged stillness journey; first/last message crops and the final screenshot were inspected. `tools/chat-still/coverage.json` records the reviewed function shapes.

| Source and function | What the model uses |
| --- | --- |
| `src/chat_session.zig`, `refreshChatTranscript` | Persistent newest-visible-message anchor during read hold, synchronous refresh/layout and final held-scroll selection. |
| `src/chat_session.zig`, `chatRelayoutPreservingScroll` | The same persistent message anchor, remeasurement and final held-scroll selection. |
| `src/chat_history.zig`, `scrollAnchor`, `readAnchor`, `readAnchorTop`, `followBottom`, `scrollAfterLayout`, `openScroll`, `Anchor`, `ReadAnchor`, `ReadBoundary` | Message identity and relative block offset, exact bottom calculation, divider fallback, content clamp and replay types. |
| `src/chat_render.zig`, `chatSetTopPad` | Source drift check and native regression for cached padding shifts. This fast path has no separate SMT obligation. |
| `tools/chat-still/verify.py`, `symbolic`, `held`, `check` | Restricted scalar translation and Z3 obligations. |
| `tools/chat-still/replay.py`, `replay` | Extracted production anchor helpers, scroll functions, both layout callers and cached padding, with a deterministic measurement boundary. |

Two ordered message rectangles represent the first visible row and the newest initially visible message. They are deliberately different. Preserving the first row does not imply that the newest message stays still if a row between them changes height.

The proof quantifies over all integer geometries in the stated bounds, not sampled sizes. Viewport height is 100 to 1,000 pixels; old and new content height are at most 10,000 pixels and exceed the viewport; padding is 0 to 100 pixels, and late padding changes are 1 to 32 pixels. A late divider is 28 pixels. The original newest-visible message and its anchored block survive, read-hold remains active, read boundaries have `unknown=false`, the transcript window has a fixed screen origin, and the desired held position is inside the content clamp. Thus integer overflow, forced refresh, user scroll, anchor removal, short fitting conversations and impossible clamp positions are outside the proof. The runtime check covers full screen rectangles, actual on-screen RGB pixels, first-frame layout readiness and blank paints; the SMT check only covers Y position under these explicit assumptions. It does not prove absence of all paint flicker, real font measurement, arbitrary transcript parsing or live-event transport.

Each passive event is checked through both callers. History may add a divider; measurement and reconciliation may change the gap between the first and newest rows; late layout may add padding; a live append may increase content height without changing existing rows. An SMT failure is a concrete allowed geometry, not proof that a specific screen interaction reaches it. Native replay establishes the scroll result for that geometry, while the Windows journey establishes reachability for its actual user path.

## Read failures

Hosted Tests run `44342248357` at `9ef7d1c5` replayed six real findings for row-height changes, padding compensation and reconciliation across both callers. The earlier ten failures in that log are deliberate guard mutations, not ten product regressions. `regressions.json` retains the six real coordinates.

The product now holds the newest initially visible message by identity instead of the first visible row. Padding is already included in its new top, so the scroll offset must not subtract padding again. The translation uses that message's old/new top and stored offset. All ten obligations, geometry bounds, content clamps and the exact Y invariant remain unchanged. The replay requires the original six witnesses to preserve their before-Y, then checks cached padding and an append followed by remeasurement without replacing the original anchor. Hosted confirmation at `5be4370e` passes in Tests run `44348905357` and Windows run `44348891482`.

A counterexample lists old/new row tops, content height, viewport, divider, padding and the newest message's before/after Y. Tell it as opening the chat, receiving that update, and painting the changed Y. For a model error, show the mismatching production operation or impossible geometry and repair the mapping; keep the invariant. For a real bug, link the failing coordinates and native replay to the product ticket. Do not confuse replaying a synthetic measurement boundary with proving a production UI path.

## Prove and maintain it

`--self-test` copies the real source into a temporary directory, breaks both production `held_y` guards so they discard the anchor, and requires all ten obligations to reject the scratch code. With `--replay`, those counterexamples must also match the production functions compiled from that scratch copy. With `--replay`, native negative controls also restore the first-row selection and the uncompensated cached-padding shift. Each must fail an exact-position regression. The real checkout is never edited, and the original check then runs again. Its result must return to the same findings or pass it started with.

When changing covered code, read the full functions, their callers and the runtime recipe before editing the model. `coverage.json` hashes normalized function bodies except the explicitly translated `held_y` declaration. Any other changed code stops with MODEL DRIFT. Update the translation, replay and bounds if semantics changed; recheck every mutation and the Windows journey. Move the sync commit and hashes forward only after confirming the verification still describes the code. A hash update alone is not that confirmation. Use `/maintain-formal-verification-skill` after covered changes shipped without this review.
