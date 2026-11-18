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

Run the matching real Windows journey with `gh workflow run verify.yml --ref <branch> -f feature=chat-still`. Follow [verify-multiprompt](../verify-multiprompt/SKILL.md) and [the chat-still recipe](../verify-multiprompt/features/chat-still.md) to inspect frame samples, screenshots, streaming receipt, Doctor and cleanup. Run desktop code only on GitHub-hosted Windows. The [Chat stillness workflow](../../../.github/workflows/chat-still.yml) runs both checks nightly or manually. The PR Tests workflow keeps its changed-chat formal guard.

## Why this tool

Z3 answers the scroll arithmetic question directly. The two native functions run synchronously on the UI thread; no event can interrupt their layout and scroll update. Their boundary states, not imaginary interleavings inside a function, are the meaningful transitions. A single-step invariant preserved by every passive transition composes over any sequence of those transitions. No verifier executes Zig UI code symbolically here. The source's scalar `held_y`, hold guard and bottom-follow force expressions are translated to SMT. The selected anchor helper determines whether the first or newest visible row supplies the anchor. The remaining covered function bodies are checked for drift, and every discovered counterexample can be replayed through the extracted production Zig functions.

## Coverage and assumptions

Last source/model sync commit is `80cf5000fcd66fa2d1ce7b397c419e127e9f2409`. Confirm the full SHA in `tools/chat-still/coverage.json`; that file is authoritative.

| Source and function | What the model uses |
| --- | --- |
| `src/chat_session.zig`, `refreshChatTranscript` | Newest-visible-row anchor while opening hold is active, synchronous refresh/layout, final held-scroll selection and readiness guard. |
| `src/chat_session.zig`, `chatRelayoutPreservingScroll` | Newest-visible-row anchor while opening hold is active, remeasurement including padding, and final held-scroll selection. |
| `src/chat_history.zig`, `scrollAnchor`, `visibleTailAnchor`, `followBottom`, `scrollAfterLayout`, `openScroll`, `Anchor`, `ReadBoundary` | Anchor definition, exact bottom calculation, divider fallback, content clamp and replay types. |
| `tools/chat-still/verify.py`, `symbolic`, `held`, `check` | Restricted scalar translation and Z3 obligations. |
| `tools/chat-still/replay.py`, `replay` | Extracted production `scrollAnchor`, `visibleTailAnchor`, `followBottom`, `scrollAfterLayout`, `openScroll` and both callers, with a deterministic measurement boundary. |

Two ordered message rectangles represent the first visible row and the newest initially visible message. They are deliberately different. Preserving the first row does not imply that the newest message stays still if a row between them changes height.

The proof quantifies over all integer geometries in the stated bounds, not sampled sizes. Viewport height is 100 to 1,000 pixels; old and new content height are at most 10,000 pixels and exceed the viewport; padding is 0 to 100 pixels, and late padding changes are 1 to 32 pixels. A late divider is 28 pixels. The newest visible row survives at its index, read-hold remains active, read boundaries have `unknown=false`, the transcript window has a fixed screen origin, and the desired held position is inside the content clamp. Readiness and prior scroll-state flags independently range over both Boolean values; readiness must not bypass an active hold. Thus integer overflow, forced refresh, user scroll, anchor removal/reordering, short fitting conversations and impossible clamp positions are outside the proof. The runtime check covers full screen rectangles, actual on-screen RGB pixels, first-frame layout readiness and blank paints; the SMT check only covers Y position under these explicit assumptions. It does not prove absence of all paint flicker, real font measurement, arbitrary transcript parsing or live-event transport.

Each passive event is checked through both callers. History may add a divider; measurement and reconciliation may change the gap between the first and newest rows; late layout may add padding; a live append may increase content height without changing existing rows. An SMT failure is a concrete allowed geometry, not proof that a specific screen interaction reaches it. Native replay establishes the scroll result for that geometry, while the Windows journey establishes reachability for its actual user path.

## Read failures

The earlier sync at `608b7d629` retained six findings for row-height changes, padding and reconciliation. PR 1089 head `f695a879d` additionally let readiness bypass the hold. Updating its mapping produced ten counterexamples; all ten replayed through that head's production functions. Product fix `80cf5000f` preserves the newest visible row, removes the padding subtraction and keeps the hold active when history is ready. All ten obligations now pass without inheritance. A scratch break of both real `held_y` guards fails all ten obligations, and all ten witnesses replay; the unbroken source passes again. Only then was the sync commit advanced. The invariant, event classes, numeric bounds and strict drift/inheritance guard were not weakened.

A counterexample lists old/new row tops, content height, viewport, divider, padding and the newest message's before/after Y. Tell it as opening the chat, receiving that update, and painting the changed Y. For a model error, show the mismatching production operation or impossible geometry and repair the mapping; keep the invariant. For a real bug, link the failing coordinates and native replay to the product ticket. Do not confuse replaying a synthetic measurement boundary with proving a production UI path.

## Prove and maintain it

`--self-test` copies the real source into a temporary directory, breaks both production `held_y` guards so they discard the anchor, and requires all ten obligations to reject the scratch code. With `--replay`, those counterexamples must also match the production functions compiled from that scratch copy. The real checkout is never edited, and the original check then runs again. Its result must return to the same findings or pass it started with.

When changing covered code, read the full functions, their callers and the runtime recipe before editing the model. `coverage.json` hashes normalized function bodies except the explicitly translated `held_y` declaration. Any other changed code stops with MODEL DRIFT. Update the translation, replay and bounds if semantics changed; recheck every mutation and the Windows journey. Move the sync commit and hashes forward only after confirming the verification still describes the code. A hash update alone is not that confirmation. Use `/maintain-formal-verification-skill` after covered changes shipped without this review.
