---
name: verify-chat-still
description: Check the native chat scroll invariant after changes to history refresh, row measurement, padding, live replies, reconciliation or painting; run alongside verify-multiprompt chat-still before shipping chat changes.
---

# Verify that a shown chat stays still

The newest message visible when the chat appears must keep its screen position until the user deliberately scrolls. Moving that message while history settles makes the chat jump and flicker.

## Run

From the checkout, run `bash tools/verify-chat-still --self-test --replay --output evidence/chat-still-formal.json`.

The launcher installs `z3-solver==4.13.4.0` in an isolated cached Python environment. Python 3.12 and Zig 0.16.0 are the replay toolchain used by the GitHub check. This is a small focused check, not the desktop suite. By default, exit 0 means no modeled violation, 1 means a counterexample, and 2 means drift or an unavailable baseline. Read every reported property, not only the last line.

CI adds `--inherit-from <base-commit>`. Findings then return exit 0 only when the same model run over that commit's covered source reports the same failures and the same counterexamples, after all requested mutation and replay checks complete. The JSON keeps every failure and witness and records `inherited_from`. Source that changes a finding, a missing baseline, drift and failed replay cannot inherit. This classifies existing findings without changing the invariant; the default command still fails on them.

Run the matching real Windows journey with `gh workflow run verify.yml --ref <branch> -f feature=chat-still`. Follow [verify-multiprompt](../verify-multiprompt/SKILL.md) and [the chat-still recipe](../verify-multiprompt/features/chat-still.md) to inspect frame samples, screenshots, streaming receipt, Doctor and cleanup. Run desktop code only on GitHub-hosted Windows. The [Chat stillness workflow](../../../.github/workflows/chat-still.yml) runs both checks for chat-related PR paths.

## Why this tool

Z3 answers the scroll arithmetic question directly. The two native functions run synchronously on the UI thread; no event can interrupt their layout and scroll update. Their boundary states, not imaginary interleavings inside a function, are the meaningful transitions. A single-step invariant preserved by every passive transition composes over any sequence of those transitions. No verifier executes Zig UI code symbolically here. The source's scalar `held_y` expressions are translated to SMT, the rest of the covered function bodies are checked for drift, and every discovered counterexample can be replayed through the extracted production Zig functions.

## Coverage and assumptions

Last source/model sync commit is `1618131e4eb9e550549c0cecf82a0767b181d21f`. Confirm the full SHA in `tools/chat-still/coverage.json`; that file is authoritative.

SOFT-3140 restores the original single-file helper bundle in `src/chat_session.zig`, keeping health inside `mp_sessions.py`. All six covered functions and both types retain their canonical hashes after regeneration; no scroll expressions, callers, replay boundaries or model assumptions change.

| Source and function | What the model uses |
| --- | --- |
| `src/chat_session.zig`, `refreshChatTranscript` | Existing first-visible-row anchor, synchronous refresh/layout, padding compensation, final held-scroll selection. |
| `src/chat_session.zig`, `chatRelayoutPreservingScroll` | Existing first-visible-row anchor, remeasurement and final held-scroll selection. |
| `src/chat_history.zig`, `scrollAnchor`, `followBottom`, `scrollAfterLayout`, `openScroll`, `Anchor`, `ReadBoundary` | Anchor definition, exact bottom calculation, divider fallback, content clamp and replay types. |
| `tools/chat-still/verify.py`, `symbolic`, `held`, `check` | Restricted scalar translation and Z3 obligations. |
| `tools/chat-still/replay.py`, `replay` | Extracted production `scrollAnchor`, `followBottom`, `scrollAfterLayout`, `openScroll` and both callers, with a deterministic measurement boundary. |

Two ordered message rectangles represent the first visible row and the newest initially visible message. They are deliberately different. Preserving the first row does not imply that the newest message stays still if a row between them changes height.

The proof quantifies over all integer geometries in the stated bounds, not sampled sizes. Viewport height is 100 to 1,000 pixels; old and new content height are at most 10,000 pixels and exceed the viewport; padding is 0 to 100 pixels, and late padding changes are 1 to 32 pixels. A late divider is 28 pixels. The original anchor survives at its index, read-hold remains active, read boundaries have `unknown=false`, the transcript window has a fixed screen origin, and the desired held position is inside the content clamp. Thus integer overflow, forced refresh, user scroll, anchor removal/reordering, short fitting conversations and impossible clamp positions are outside the proof. The runtime check covers full screen rectangles, actual on-screen RGB pixels, first-frame layout readiness and blank paints; the SMT check only covers Y position under these explicit assumptions. It does not prove absence of all paint flicker, real font measurement, arbitrary transcript parsing or live-event transport.

Each passive event is checked through both callers. History may add a divider; measurement and reconciliation may change the gap between the first and newest rows; late layout may add padding; a live append may increase content height without changing existing rows. An SMT failure is a concrete allowed geometry, not proof that a specific screen interaction reaches it. Native replay establishes the scroll result for that geometry, while the Windows journey establishes reachability for its actual user path.

## Read failures

Master's SOFT-2557 fix in `5ce536b4` preserves the existing anchor when a divider first appears. The checker reads that changed `held_y` guard directly, and the divider obligation now passes. Six findings remain for row-height changes, padding compensation and reconciliation across both callers. Hosted run `44044096426` replayed all ten scratch counterexamples and all six current-source counterexamples through the extracted production functions. The sync commit records that confirmed source. Do not edit product behavior, omit event classes or relax the property to make this check green.

A counterexample lists old/new row tops, content height, viewport, divider, padding and the newest message's before/after Y. Tell it as opening the chat, receiving that update, and painting the changed Y. For a model error, show the mismatching production operation or impossible geometry and repair the mapping; keep the invariant. For a real bug, link the failing coordinates and native replay to the product ticket. Do not confuse replaying a synthetic measurement boundary with proving a production UI path.

## Prove and maintain it

`--self-test` copies the real source into a temporary directory, breaks both production `held_y` guards so they discard the anchor, and requires all ten obligations to reject the scratch code. With `--replay`, those counterexamples must also match the production functions compiled from that scratch copy. The real checkout is never edited, and the original check then runs again. Its result must return to the same findings or pass it started with.

When changing covered code, read the full functions, their callers and the runtime recipe before editing the model. `coverage.json` hashes normalized function bodies except the explicitly translated `held_y` declaration. Any other changed code stops with MODEL DRIFT. Update the translation, replay and bounds if semantics changed; recheck every mutation and the Windows journey. Move the sync commit and hashes forward only after confirming the verification still describes the code. A hash update alone is not that confirmation. Use `/maintain-formal-verification-skill` after covered changes shipped without this review.

MUBO-601 removes queued echo rectangles from `chatRelayout`, because their one visible copy belongs to the queued-message tray. No function or type hashed in `tools/chat-still/coverage.json` changes, so those hashes remain unchanged. Stillness continues to model a retained anchor, not the deliberate disappearance of an unsent bubble; the hosted Windows chat-still journey remains the screen-level check.
