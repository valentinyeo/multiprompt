# Gates: IGSH-1892 agent browser pane

OWNS: .unlazy/IGSH-1892/**

Scope: Keep the agent browser pane open while an agent is attached. If it closes, reopen it on the next browser call. Done only after this runner drives its own pane for 15 minutes without a drop and a closed pane reopens on the next call.

- [x] G1: The desktop process in memory matches a published release that contains the pane lifecycle fix and the reply-ownership fix.
  CHECK: node .unlazy/IGSH-1892/live-check.mjs identity
  EXPECT: IGSH-1892 identity pass
  EVIDENCE: automatic-evidence=v1; definition-sha256=67ff1afe518dd3b0cefd91bc9a3dac505b6ee0f3dd139390f9db199d044f359e; exit=0; EXPECT=matched; output-sha256=3c2b0d7494295e3470bc59f07ca8d1c0ad81ea6027eaaf08c5cf4779059c8f42; output-bytes=344; shell=/bin/sh; cwd=/home/valentin/projects/mp-runner-3-1892; path=40375c739e86/57 entries

- [x] G2: A closed pane on ht-or-runner-3 reopened on the next browser call and answered a page read.
  EVIDENCE: pane-info windowId 0, then zsb open https://example.com/ returned ok, then pane-info windowId 1813544135, tabs target https://example.com/, eval result https://example.com/.

- [x] G3: This runner drove its own pane for 15 minutes without the pane closing.
  CHECK: node .unlazy/IGSH-1892/live-check.mjs soak-audit
  EXPECT: IGSH-1892 soak pass
  EVIDENCE: automatic-evidence=v1; definition-sha256=126d2adb10fdfa4bdbb93459d14a065ff98b4b8cdb26452f740a210466647377; exit=0; EXPECT=matched; output-sha256=e4b517d8503495971345aaa91e16f5317cf50d68bfe01f5ad5b51f067fb2359c; output-bytes=61; shell=/bin/sh; cwd=/home/valentin/projects/mp-runner-3-1892; path=40375c739e86/57 entries

- [x] G4: Live evidence is pushed and the ticket moves to Done only after the other gates pass.
  EVIDENCE: Pushed https://github.com/valentinyeo/multiprompt/commit/51b0e0967c7f9875fc96b769cd10c27582e66d63 and moved IGSH-1892 to Done. Done comment 389178.

## Recovery observation 2026-11-11

Running process is v0.28.1673, started 2026-11-11T11:56:57Z, SHA256 8760865105733cf8a14c1d864e8f26e9b3bbded59c2e6f9d321c7d5519d84e9c, same hash as the installed multiprompt.exe. That release is after the reply-ownership fix.

Own session ht-or-runner-3, shell 20216, was closed: pane-info returned windowId 0. The next call, `zsb open https://example.com/`, returned ok. pane-info then returned windowId 1813544135. tabs showed Example Domain at https://example.com/ as the target tab. eval returned https://example.com/. Extension 1.0.90.

Soak then kept that same window for 37 calls and 15.00 minutes. One pane-info reply timed out and the retry succeeded. The window id never changed.
