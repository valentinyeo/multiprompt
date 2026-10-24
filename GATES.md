# Gates: IGSH-731 composer smoothing

Scope: DirectWrite composer glyphs at EDIT positions without changing editing behavior, default-on rollback, native rendering proof, Windows feature and release red control, changelog and published PR. No native builds or native tests run on the VPS.

- [x] G1: ledger has valid measurable gates
  CHECK: node /home/valentin/.agents/skills/unlazy/scripts/gate-lint.mjs GATES.md
  EXPECT: LINT OK
  EVIDENCE: automatic-evidence=v1; definition-sha256=69f81179f3934636347ff01de4824d2a1f500f2d29238b9fd688f82f77d1c57b; exit=0; EXPECT=matched; output-sha256=30bc545cb0d346a35c0f657f19c1c87b07b735924adc36ae07b0b5e3151ec8ed; output-bytes=995; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-731; path=169277661364/28 entries

- [x] G2: source-only Node regressions pass without invoking native builds or copied Zig fixtures
  CHECK: node --test tools/chat-composer-text-proof.test.js tools/chat-code-font-proof.test.js tools/verify-multiprompt.test.js tools/chat-font-weight.test.js tools/one-font.test.js tools/console-font.test.js tools/font-probe.test.js
  EXPECT: fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=fb60ce65c7359037170a919e75cf746319840d92b0635e2073f6d001f2703d33; exit=0; EXPECT=matched; output-sha256=7e2ebb5b86f0d44852bf3d3f354afe1b896929ea6aaf510637d7a8f44ad1d748; output-bytes=19884; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-731; path=169277661364/28 entries

- [x] G3: changed source contains no comments and diff has no whitespace errors
  CHECK: node tools/strip-comments.mjs --check && git diff --check 37ac8248
  EXPECT: No code comments found.
  EVIDENCE: automatic-evidence=v1; definition-sha256=f186ec081e99a7b34dccfd58981e16feec6b28b8e978dfc1869e68a9d9fd2b20; exit=0; EXPECT=matched; output-sha256=33ad9c77b5aaa9b59009bc21cbb061083aebe1abb6a656c7c02af72264a20ded; output-bytes=24; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-731; path=169277661364/28 entries

- [x] G4: production painter preserves EDIT geometry, selection, caret, scrolling, IME and rollback; native proof and feature are wired into Windows CI
  EVIDENCE: source review: src/chat_composer.zig:1086 only defers paint invalidation; 1152-1178 delegates native painting and preserves placeholder/fallback; src/main.zig:1611 changes only native ink color; src/chat_composer_text.zig:22 queries text, selection, formatting and native positions without mutating editing state, balances HideCaret/ShowCaret, and leaves IME/autocomplete input in the original EDIT procedure. Native child-control geometry regression passed in Windows run 40114071216: eight wrapped lines, undo enabled, first-visible-line 0 then 2, selection 524289 and text/position/undo unchanged after painting; real IME and remote autocomplete were not manually exercised.

- [ ] G5: Windows CI builds and native proof at 100/125/150 percent has materially smoother edges than native GDI
  EVIDENCE: Windows x64/arm64 builds passed at 1b4dfa50 (Tests run 40113233484). Native proof in run 40113230185 remeasured all nine BMP/JSON pairs: 7 passed; UI125/DPI144 and UI150/DPI120 (both 26px) failed the unchanged 25-percent improvement assertion: GDI 0.09715157680569685 versus DirectWrite 0.09432989690721649. No threshold was weakened. Child-control follow-up run 40114071216 completed at source 4fb613ec: Windows build succeeded, geometry regression passed, 851/852 desktop tests passed; the only failure is this unchanged all-scales edge assertion. All 18 BMPs and JSON measurements are retained. No native proof was run locally.

- [ ] G6: live Windows feature records composer edge metrics with smoothing disabled; branch passes and v0.28.858 fails the identical check
  EVIDENCE: release red proven at https://github.com/valentinyeo/multiprompt/actions/runs/40111228106 (c862ffff; unchanged live harness): v0.28.858 measured 931 edges, 193 hard edges, hardEdgeFraction 0.20730397422126745, partialPerInk 0.6548890714872637, system smoothing false, fixed threshold 0.18, composer check failed and cleanup passed. Branch live composer-edge check is green in run 40113230185: hardEdgeFraction 0.09433962264150944, partialPerInk 0.7194465795541891, 901 edges, smoothing false, threshold still 0.18; screenshots/crops inspected. Full feature remains red because native scale evidence fails G5. Final source run https://github.com/valentinyeo/multiprompt/actions/runs/40114071216 reproduces the same live green numbers and the same native red. The live oracle/control.ps1 are byte-identical to the release-red run; only native source/fixture and evidence retention changed. Full branch-green acceptance is unmet, not waived.

- [x] G7: branch includes one-sentence changelog, is committed and pushed, and PR has the requested title
  EVIDENCE: fresh worktree /home/valentin/projects/multiprompt-IGSH-731 from origin/master 37ac8248; ceo/IGSH-731 pushed through 4fb613ec; PR https://github.com/valentinyeo/multiprompt/pull/336 has the exact requested title and base master; changelog fragment is one user sentence with no version bump.

Local exception: the initial Node command mistakenly included tools/console-font-lifecycle.test.js, which copies Zig fixtures and attempts a Zig subprocess; it failed with no native result. It was excluded from all subsequent VPS checks. The blanket tools/*.test.js suite was not run because it includes native compilation and copied-fixture tests. The approved source-only suite has 81 passes, zero failures and one Windows-only skip.
