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

The original source findings are SOFT-2724, SOFT-2725 and SOFT-2726. Their historical traces stay in the formal skill. The repair must pass with no findings and no inherited result. Source equality, native replay, both mutations and restoration remain required before an unrelated verification-only change can classify a finding as inherited. No UI journey or binary hash certifies this model.
