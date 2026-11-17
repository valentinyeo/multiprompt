# Long-chat position replay

## Sub-features

- PR 1070's synthetic 64-session profile, eight workspaces and 2,400-message long histories with images, tables and code.
- Opening and revisiting five real-size long chats through native session shortcuts.
- Every visible successful paint saved with global chat/message bounds, identities, scroll and exact pixels, including unfinished layouts.
- A long hosted chat left open through idle refreshes, reading old history, a real composer send, eight production text deltas and completion below the reader.
- Native copied transcript receipts and zero surviving owned processes.

## How to get to it (user POV)

Open a long saved session, switch away and return. Scroll into older messages, leave the chat open, send a reply and keep reading while the answer streams below.

## Driving it with control.ps1

Select `feature=chat-position-replay` in the existing reusable Windows workflow. This is a verification alias, not a new app feature. The workflow enables the identical paint probe and normalizes to the existing chat-switch driver, then runs the production-host delivery driver in a separate owned profile. The original switch-speed benchmark is unchanged.

No manual dispatch is needed for PR 1067. Its automatic baseline/candidate workflow already runs these same scripts. The independent verifier can select this map by name to run the same journey itself. Artifacts use `verify-chat-position-replay`; application-compare artifacts append the baseline SHA.

Done when both long-chat journeys pass, copied text includes the seed's final answer and the real sent/completed reply, all stable phases have no block or text-row movement, every recorded paint has its image, and both owned profiles clean up. `result.json.positionJourneys` must report both switch and hosted success. Explicit user scrolls retain their movement records.

Before a product fix, master must fail on an actual painted movement in a stable long-chat phase under the same scripts. A missing screenshot, unsupported display mode, setup error, or short-chat jump does not establish that reproduction. Do not substitute the regular 400-round speed journey or the 50-paragraph working-dots journey.

## Gotchas

The hosted runner supports 1920x1080; it rejected the owner's 2560x1600 mode before launch. The video starts before launch at the supported size. Exact per-paint bitmaps, not sampled video alone, establish positions. Recording overhead is not a latency benchmark. SSH/provider I/O is synthetic; the app's archive, subscription, layout, input and scroll paths are real. No production fix is claimed until the required long-chat master failure and candidate pass exist.
