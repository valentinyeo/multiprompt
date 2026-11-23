# Formal chat delivery

Source files: .claude/skills/verify-chat-delivery-formal/*, .github/workflows/chat-delivery-formal.yml
CI workflow: chat-delivery-formal.yml

## Sub-features

Check send, outbox, echo reconciliation, retry and resume in a bounded TLA+ model. Each accepted message must show once, never as a false **Not sent** copy. This verifies delivery decisions, not the Windows screen.

## How to get to it (user POV)

An agent changing this skill or workflow runs [verify-chat-delivery-formal](../../verify-chat-delivery-formal/SKILL.md). Changes to covered product files still select their existing desktop journeys and trigger the formal workflow separately.

## Driving it with GitHub CI

Run the skill's one-command check with production replay and both planted breaks on GitHub's hosted Linux runner. Read every model result with pstack /statechart. Local TLC-only investigation is permitted; native replay and reviews remain hosted.

The PR selector owns these files through `CI workflow:`, not a nearest desktop name. The verifier requires this workflow to pass on the exact PR head alongside Tests, downloads its identically named `chat-delivery-formal` artifact, and gives the independent judge its raw summary and run receipt. Missing, pending, failed or stale evidence cannot pass.

## Gotchas

SOFT-3125 fixes the three baseline source findings SOFT-2724, SOFT-2725 and SOFT-2726. Every finding on the current head fails CI, even if inherited. Native replay, both planted mutations and restoration still run. The independent verifier rejects raw delivery summaries with failures or model-only evidence. No UI journey or binary hash certifies this model.

The workflow retains pstack /statechart output for all-events and resume-only configs. Its optional manual `baseline_run` input downloads earlier raw delivery evidence and charts those paths too. It does not waive their findings or rerun a failed check to get a pass.
