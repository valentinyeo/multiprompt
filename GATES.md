# Gates: IGSH-811 Chrome frameless measurement

OWNS: GATES.md, .github/workflows/probe-chrome-frameless.yml, tools/probe-chrome-frameless.ps1

Scope: Measure branded Chrome frame removal, navigation stability, corner input and edge hit tests on a GitHub-hosted Windows desktop without modifying the mask subsystem or running local builds or tests.

- [ ] G0: The ledger has valid observable gates
  CHECK: node /home/valentin/.agents/skills/unlazy/scripts/gate-lint.mjs GATES.md
  EXPECT: LINT OK
  EVIDENCE: pending

- [ ] G1: Only the self-contained probe, its workflow and this ledger differ from the starting commit; no code comments or local builds/tests were introduced
  EVIDENCE: pending

- [ ] G2: The pushed branch has a successful Windows probe run with the exact Chrome identity and complete JSON and screenshot artifacts read back
  EVIDENCE: pending

- [ ] G3: Raw before/after styles, both navigation methods, HWND recreation, physical corner clicks and edge hit tests are measured, and screenshots independently establish visible frame/button behavior
  EVIDENCE: pending

- [ ] G4: The final verdict and artifact paths agree with the downloaded run evidence and all gates are reverified
  EVIDENCE: pending
