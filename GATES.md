# Gates: IGSH-731 composer smoothing

Scope: DirectWrite composer glyphs at EDIT positions without changing editing behavior, default-on rollback, native rendering proof, Windows feature and release red control, changelog and published PR. No native builds or native tests run on the VPS.

- [x] G1: ledger has valid measurable gates
  CHECK: node /home/valentin/.agents/skills/unlazy/scripts/gate-lint.mjs GATES.md
  EXPECT: LINT OK
  EVIDENCE: automatic-evidence=v1; definition-sha256=69f81179f3934636347ff01de4824d2a1f500f2d29238b9fd688f82f77d1c57b; exit=0; EXPECT=matched; output-sha256=30bc545cb0d346a35c0f657f19c1c87b07b735924adc36ae07b0b5e3151ec8ed; output-bytes=995; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-731; path=169277661364/28 entries

- [x] G2: source-only Node regressions pass without invoking native builds or copied Zig fixtures
  CHECK: node --test tools/chat-composer-text-proof.test.js tools/chat-code-font-proof.test.js tools/verify-multiprompt.test.js tools/chat-font-weight.test.js tools/one-font.test.js tools/console-font.test.js tools/font-probe.test.js
  EXPECT: fail 0
  EVIDENCE: automatic-evidence=v1; definition-sha256=fb60ce65c7359037170a919e75cf746319840d92b0635e2073f6d001f2703d33; exit=0; EXPECT=matched; output-sha256=ee18985216e171855171ea187cdf348178b706a2e9b87f18f7e7c6d1a530d0fd; output-bytes=19628; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-731; path=169277661364/28 entries

- [x] G3: changed source contains no comments and diff has no whitespace errors
  CHECK: node tools/strip-comments.mjs --check && git diff --check
  EXPECT: /./
  EVIDENCE: automatic-evidence=v1; definition-sha256=c31223fd7f778a616663ede99455c39960fd1b5bba12fade204ed83a18e83b0d; exit=0; EXPECT=matched; output-sha256=33ad9c77b5aaa9b59009bc21cbb061083aebe1abb6a656c7c02af72264a20ded; output-bytes=24; shell=/bin/sh; cwd=/home/valentin/projects/multiprompt-IGSH-731; path=169277661364/28 entries

- [ ] G4: production painter preserves EDIT geometry, selection, caret, scrolling, IME and rollback; native proof and feature are wired into Windows CI
  EVIDENCE: pending source review with exact paths and invariants

- [ ] G5: Windows CI builds and native proof at 100/125/150 percent has materially smoother edges than native GDI
  EVIDENCE: pending Windows CI only; never execute native tests on VPS

- [ ] G6: live Windows feature records composer edge metrics with smoothing disabled; branch passes and v0.28.858 fails the identical check
  EVIDENCE: pending Windows feature runs and release red control

- [ ] G7: branch includes one-sentence changelog, is committed and pushed, and PR has the requested title
  EVIDENCE: pending git and GitHub proof
