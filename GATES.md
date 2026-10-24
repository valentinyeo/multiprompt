# Gates: IGSH-760 typing-frame rectangle contract

OWNS: .claude/skills/verify-multiprompt/control.ps1, tools/chat-composer-text-proof.test.js, GATES.md

Scope: Make capture metadata describe the captured bitmap without weakening the evaluator, prove real evidence is measured and vanishing ink still fails, and commit only this composer follow-up on ceo/IGSH-760. No app changes, version bump, push, PR, board writes or heavy execution.

- [x] G1: this ledger has valid measurable gates
  CHECK: node "$HOME/.agents/skills/unlazy/scripts/gate-lint.mjs" GATES.md
  EXPECT: LINT OK
  EVIDENCE: automatic-evidence=v1; definition-sha256=2e01e6cb0c2b57862b4f4acfd1b3fed2fbbc2f8a6db901d2d3d3bf8d4170f7fb; exit=0; EXPECT=matched; output-sha256=48630b7361dd44ee870917b12c3d19b9d7bdea738aaca16bb04d4cab83b772d2; output-bytes=8; shell=/bin/sh; cwd=<worktree>; path=433695eed2f1/23 entries

- [x] G2: composer tests accept valid capture geometry, reject the old out-of-bounds contract and reject vanishing mid-typing ink
  CHECK: node --test tools/chat-composer-text-proof.test.js
  EXPECT: /# fail 0\b/
  EVIDENCE: automatic-evidence=v1; definition-sha256=e38caca9a65d24f4a2777efe6b2b4e78c1927df9ddcef46a4e4299d1b1c45311; exit=0; EXPECT=matched; output-sha256=f2df98bdcece009ff2e0ff74b4ef22435a6ffa76eb9a53dc4ff95530c8325cab; output-bytes=3477; shell=/bin/sh; cwd=<worktree>; path=433695eed2f1/23 entries

- [x] G3: downloaded Windows frames are evaluated under the corrected producer contract without a rectangle error
  CHECK: node .unlazy/IGSH-760/replay.mjs
  EXPECT: TYPING EVIDENCE MEASURED
  EVIDENCE: automatic-evidence=v1; definition-sha256=04f9de16570fa9b6f2fb3f2c0b367c42cafea0da9dd2d06d608fcf9e2760f9ea; exit=0; EXPECT=matched; output-sha256=33fb0bb2ed0e8a2302c46342d64837b307ee46177f24740a52ed161eec39968e; output-bytes=528; shell=/bin/sh; cwd=<worktree>; path=433695eed2f1/23 entries

- [x] G4: changed composer source is comment-free and the diff has no whitespace errors
  CHECK: node tools/strip-comments.mjs --check && git diff --check && git diff --cached --check
  EXPECT: No code comments found.
  EVIDENCE: automatic-evidence=v1; definition-sha256=4d018b60fafcaaaa497e570f14bd46f8465594f093ef64fc21c237ac795d5023; exit=0; EXPECT=matched; output-sha256=33ad9c77b5aaa9b59009bc21cbb061083aebe1abb6a656c7c02af72264a20ded; output-bytes=24; shell=/bin/sh; cwd=<worktree>; path=433695eed2f1/23 entries

- [x] G5: strict evaluator, existing changelog, app version and unrelated production features remain unchanged
  CHECK: node -e "const a=require('node:assert/strict'),c=require('node:child_process'); const names=c.execFileSync('git',['diff','--name-only','e19a0e25'],{encoding:'utf8'}).trim().split('\\n'); a.deepEqual(names.sort(),['.claude/skills/verify-multiprompt/control.ps1','GATES.md','tools/chat-composer-text-proof.test.js'].sort()); console.log('COMPOSER ONLY VERIFIED')"
  EXPECT: COMPOSER ONLY VERIFIED
  EVIDENCE: automatic-evidence=v1; definition-sha256=832fa845289574f14f45617e847df3b080f994d41a08a4ef5780c238d62b4143; exit=0; EXPECT=matched; output-sha256=ef1c846a829d38e682cd656a387da4765266117722583ca9fa1c06a4c99ca614; output-bytes=23; shell=/bin/sh; cwd=<worktree>; path=433695eed2f1/23 entries

- [x] G6: follow-up remains on the requested branch before the final local commit
  CHECK: node -e "const a=require('node:assert/strict'),c=require('node:child_process'); a.equal(c.execFileSync('git',['branch','--show-current'],{encoding:'utf8'}).trim(),'ceo/IGSH-760'); console.log('REQUESTED BRANCH VERIFIED')"
  EXPECT: REQUESTED BRANCH VERIFIED
  EVIDENCE: automatic-evidence=v1; definition-sha256=8f5dd5070dc059c0e45fa5ec6fdf30b9ff7bcd3ddc888a5bde28ef01360530a9; exit=0; EXPECT=matched; output-sha256=81da02802ea0a639da19a9a54d25be7af7c906a5ad4ec7d68955acaacb64d6e9; output-bytes=26; shell=/bin/sh; cwd=<worktree>; path=433695eed2f1/23 entries

## Regression evidence

Before changing control.ps1, the new source-expression test failed with both rectangle bottoms measured as 27 instead of the bitmap limit 23 (local geometry-red.tap). The full suite retains synthetic all/prefix/trailing vanished-ink frames and CLI exit-status checks. The evaluator and all thresholds are byte-identical to baseline e19a0e25.

The local-only G3 replay oracle copies downloaded typing artifacts into .unlazy/IGSH-760/replay, first confirms the original metadata fails with Invalid typing rectangle, then evaluates the production rectangle expressions against BMP dimensions and reruns the real CLI. It checks source artifact hashes are unchanged. Set IGSH_760_EVIDENCE to the downloaded read-only evidence directory. No Windows app execution is claimed.

Contract: inkRect and rowRect are half-open integer rectangles in captured-bitmap pixels. Intersect each screen-space ComposerRow with typingCrop, then subtract typingCrop.Left/Top. Bitmap dimensions remain typingCrop.Right-Left by Bottom-Top. An empty intersection remains invalid; the evaluator never clamps or repairs input. For the downloaded 412x23 images, inkRect is {left:5,top:1,right:59,bottom:23}, rowRect is {left:5,top:1,right:332,bottom:23}.

Measured replay: passed=true; samplingPassed=true; 87 typing frames / 89 captured; durationMs=3489.0205; maxGapMs=78.40499999999997; prefix ink min=max=settled=419; row ink min=1717, max=2627; mismatchedFrames=[]. Full JSON is local at .unlazy/IGSH-760/replay/composer-typing-summary.json.
