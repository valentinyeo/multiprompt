# Gates: IGSH-1892 agent browser pane

OWNS: .unlazy/IGSH-1892/**

Scope: Keep the agent browser pane open while an agent is attached. If it closes, reopen it on the next browser call. Done only after this runner drives its own pane for 15 minutes without a drop and a closed pane reopens on the next call.

- [ ] G1: The desktop process in memory matches a published release that contains the pane lifecycle fix and the reply-ownership fix.
  CHECK: node .unlazy/IGSH-1892/live-check.mjs identity
  EXPECT: IGSH-1892 identity pass
  EVIDENCE: pending

- [ ] G2: A closed pane on ht-or-runner-3 reopens on the next browser call and answers a page read.
  CHECK: node .unlazy/IGSH-1892/live-check.mjs recover
  EXPECT: IGSH-1892 recover pass
  EVIDENCE: pending

- [ ] G3: This runner drives its own pane for 15 minutes without a dropped browser call.
  CHECK: node .unlazy/IGSH-1892/live-check.mjs soak
  EXPECT: IGSH-1892 soak pass
  EVIDENCE: pending

- [ ] G4: Live evidence is pushed and the ticket moves to Done only after the other gates pass.
  EVIDENCE: pending

## Recovery observation 2026-11-11

Running process is v0.28.1673, started 2026-11-11T11:56:57Z, SHA256 8760865105733cf8a14c1d864e8f26e9b3bbded59c2e6f9d321c7d5519d84e9c, same hash as the installed multiprompt.exe. That release is after the reply-ownership fix.

Own session ht-or-runner-3, shell 20216, was closed: pane-info returned windowId 0. The next call, `zsb open https://example.com/`, returned ok. pane-info then returned windowId 1813544135. tabs showed Example Domain at https://example.com/ as the target tab. eval returned https://example.com/. Extension 1.0.90.

A 15-minute soak is running as node pid 2924477, log `.unlazy/IGSH-1892/soak.log`. First call passed at elapsed 1s on window 1813544135.
