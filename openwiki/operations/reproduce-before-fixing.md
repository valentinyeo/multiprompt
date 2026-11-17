# Reproduce before fixing

Repair PRs must prove that the reported behaviour was broken before the change. `pstack-verifier` enforces this rule independently of the model's verdict.

## Name the repro

Add exactly one line to the PR description, using a runnable feature-map stem:

```text
Repro journey: `chat-delivery`
```

A title containing `bug`, `bug fix`, `fix`, `fixes`, or `fixed` marks a repair. Conventional `fix(scope):` titles count. Labels `bug`, `bug-fix`, `bugfix`, `bug fix`, `defect`, and `regression` also count. Keep the title and labels accurate for bug tickets.

The picker cannot omit the declared repro or turn off its master comparison. The repro uses one of the existing three journey slots. An unknown or missing name cannot pass.

## Required evidence

The workflow captures the current master commit when verification starts. It runs the same PR journey against that app build and the PR head build. Master must fail a product assertion. Head must pass. Result files and screenshots must remain in the uploaded artifacts.

The gate rejects a repair when master passes, when no master evidence exists, when either side is blocked by infrastructure, or when head still fails. Another journey's failure cannot substitute for the named repro. Matching failures on both revisions remain inherited for ordinary PRs, but do not prove a repair.

The finalizer reads the PR's current title, labels, and description again before publishing its verdict. Editing those fields reruns verification. Non-repair PRs keep the existing optional baseline policy.

## Check the rule

```sh
node --test tools/pr-verifier-repro.test.js
```

The regression rejects a repair without failing-master evidence even when the model says PASS. It also checks a missing declaration, a wrong journey, inherited failures, infrastructure failures, forced selection, and a valid master-fail/head-pass pair.

Implementation lives in `tools/pr-verifier.cjs` and `.github/workflows/pr-verifier.yml`. The [verification skill](../../.claude/skills/verify-multiprompt/SKILL.md#reproduce-before-fixing) describes the same contract.
