# Gates: IGSH-731 native smoothing assertion follow-up

Scope: Change only the native smoothing assertion, its independent BMP oracle and regression coverage. Keep production painting, composer behavior, live journey and live threshold unchanged. No builds, tests or copied fixtures run on this VPS; GitHub runs Windows verification.

Baseline: 166527ad1ef27221d9aa7206299845237b727add, existing ceo/IGSH-731 worktree and draft PR 336. This committed ledger is a pre-push evidence snapshot: existing Windows measurements plus reviewed changes, not a claim that revised code has already executed. Post-push CI run IDs and actual outcomes must be reported in the handoff.

- [x] G1: ledger has valid measurable gates
  CHECK: node /home/valentin/.agents/skills/unlazy/scripts/gate-lint.mjs GATES.md
  EXPECT: LINT OK
  EVIDENCE: automatic-evidence=v1; definition-sha256=69f81179f3934636347ff01de4824d2a1f500f2d29238b9fd688f82f77d1c57b; exit=0; EXPECT=matched; output-sha256=9553172b9c8e7494ee0d5411b5a295d469604c86f323de25dc19ab26d65c3344; output-bytes=1526; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-731; path=169277661364/28 entries

- [x] G2: regression coverage distinguishes small strict improvements, equal painters and a composer that beats GDI but exceeds 0.15
  EVIDENCE: tools/chat-composer-text-proof.test.js varies hard glyphs in the existing BMP fixture: GDI/DirectWrite 80/70 accepts an improvement below 25 percent; 80/80 rejects equal painters; fully hard GDI versus 100 hard-glyph DirectWrite rejects the absolute bound while partial pixels remain. Source-contract coverage requires the exact strict inequality, <= 0.15 and partialPixels > 0 Zig assertions. These revised tests are written, not locally executed; GitHub executes them after push.

- [x] G3: changed source contains no comments and diff has no whitespace errors
  CHECK: node tools/strip-comments.mjs --check && git diff --check 166527ad
  EXPECT: No code comments found.
  EVIDENCE: automatic-evidence=v1; definition-sha256=3678fea7135e83e9aec1afda265df07b792f99a1ffb2f30e409975eb16508dfb; exit=0; EXPECT=matched; output-sha256=33ad9c77b5aaa9b59009bc21cbb061083aebe1abb6a656c7c02af72264a20ded; output-bytes=24; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-731; path=169277661364/28 entries

- [x] G4: production painting, composer, live journey and control threshold are unchanged
  EVIDENCE: diff against 166527ad is restricted to src/chat_composer_text_proof.zig, tools/chat-composer-text-proof.mjs, tools/chat-composer-text-proof.test.js and GATES.md. Production painter, composer, control.ps1, verify.yml and feature journey are byte-identical. evaluateLive and exported threshold 0.18 are unchanged. Existing child-control geometry proof is untouched.

- [x] G5: all nine measured Windows pairs satisfy DirectWrite < GDI and DirectWrite <= 0.15 with partialPixels > 0
  EVIDENCE: Windows run 40113230185 composer-native-summary.json independently remeasured all nine BMP pairs; the old-rule passed flags are NOT reused. Every measured pair in the table below satisfies the revised contract. Tests run 40114921030 at baseline 166527ad reproduces all nine printed fractions and passes x64/arm64 builds; its only native failure is the old 25-percent rule (861/862 tests passed). This gate proves the measured bound honestly, not execution of the revised assertions before push.

- [x] G6: unchanged live proof distinguishes branch green from release v0.28.858 red at the identical threshold
  EVIDENCE: release red at https://github.com/valentinyeo/multiprompt/actions/runs/40111228106: 193/931 hard edges = 0.20730397422126745, smoothing false, threshold 0.18, composer check failed and cleanup passed. Branch live green in run 40113230185 composer-live-summary.json: 85/901 = 0.09433962264150944, partialPixels 936, smoothing false, threshold 0.18, composer check passed. Its overall feature failed solely because the embedded native summary retained the old 25-percent rule. The revised native BMP oracle matches the new Zig contract; live evaluation and control.ps1 remain byte-identical.

- [x] G7: existing published branch, draft PR and one-sentence changelog are retained
  EVIDENCE: gh pr view 336 identifies ceo/IGSH-731 at baseline 166527ad with base master; changelog.d/IGSH-731-composer-smoothing.md is unchanged. This follow-up will be delivered as one commit on this branch, without changing PR status or merging. Commit/push and post-push checks are handoff checks, not preclaimed here.

- [x] G8: native proof and independent BMP oracle enforce the same strict comparison and absolute cap
  EVIDENCE: src/chat_composer_text_proof.zig now directly asserts measurements[1].hardEdgeFraction < measurements[0].hardEdgeFraction and measurements[1].hardEdgeFraction <= 0.15 inside both loops; partialPixels > 0 and the existing per-scale print remain. tools/chat-composer-text-proof.mjs applies both identical bounds while retaining metadata, edge-count and partial-pixel checks. Regression coverage rejects equality and a too-rough relative improvement.

- [x] G9: other failed baseline GitHub checks are inspected and branch-caused failures identified without unrelated fixes
  EVIDENCE: Tests run 40114921030 and Verify desktop run 40114921036 failed logs inspected. verify (chat-view) at 2026-10-24T17:23:16.7728406Z and verify (chat-view-everywhere) at 2026-10-24T17:16:27.7542125Z both report `error: 'chat_composer_text_proof.test.IGSH-731 production composer edges beat native EDIT at every UI scale and DPI' failed:`, followed by `851/852 tests passed (1 failed)`. These are the same branch-added arbitrary-margin assertion, not separate journey failures. No unrelated failures were fixed. Inspect post-push failures again before handoff.

## Measured Windows fractions

Source: run 40113230185 `composer-native-summary.json`. Rendering is unchanged, so the revised Windows run must print these same rounded fractions. These are measurements, not hard-coded expected test values.

| UI scale | DPI | Font px | GDI hardEdgeFraction | DirectWrite hardEdgeFraction | DirectWrite partialPixels |
| --- | --- | --- | --- | --- | --- |
| 100 | 96 | 14 | 0.19552529182879377 | 0.075 | 1065 |
| 100 | 120 | 17 | 0.21333333333333335 | 0.08196721311475409 | 1416 |
| 100 | 144 | 21 | 0.17373380447585396 | 0.10448642266824085 | 1768 |
| 125 | 96 | 17 | 0.21333333333333335 | 0.08196721311475409 | 1416 |
| 125 | 120 | 21 | 0.17373380447585396 | 0.10448642266824085 | 1768 |
| 125 | 144 | 26 | 0.09715157680569685 | 0.09432989690721649 | 2105 |
| 150 | 96 | 21 | 0.17373380447585396 | 0.10448642266824085 | 1768 |
| 150 | 120 | 26 | 0.09715157680569685 | 0.09432989690721649 | 2105 |
| 150 | 144 | 31 | 0.16023007395234182 | 0.06778964667214461 | 2664 |

Historical local exception from the previous session: its initial Node command included tools/console-font-lifecycle.test.js, which copied Zig fixtures and attempted a Zig subprocess; it failed without a native result. This follow-up runs no local test suites, copied fixtures, Zig, Wine or Gradle. Only source/ledger lint and Git whitespace checks run locally.
