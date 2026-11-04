# IGSH-1651 gates

- [ ] A test fails on the original cause and passes with the fix. Record exact commands and output.
- [ ] Live Windows proof: after time in the background, the app answers at once. Exercise the original trigger through the Windows verification journey.
- [ ] CI green.
- [ ] Full CI green on this PR. Record PR URL, head SHA and run IDs.
- [ ] A freeze with a responsive message loop but missing paints saves a report.

# Work order

1. Reproduce it yourself on the matching surface via the control skill.
2. Binary-search the cause.
3. Plan the fix.
4. Verify on the same surface.
5. Stage the commits so the failing repro lands before the fix in git history.
6. Run Opening a PR.

Local execution is limited to node --test tools/<name>.test.js and zig ast-check. Windows execution requires GitHub-hosted CI. No private logs or machine identities enter committed evidence.
