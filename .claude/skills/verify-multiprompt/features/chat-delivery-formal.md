# Formal chat delivery

Source files: .claude/skills/verify-chat-delivery-formal/*, .github/workflows/chat-delivery-formal.yml
CI workflow: chat-delivery-formal.yml

## Sub-features

Check send, outbox, echo reconciliation, retry and resume in a bounded TLA+ model. Each accepted message must show once, never as a false **Not sent** copy. This verifies delivery decisions, not the Windows screen.

## User entry points

An agent changing this skill or workflow runs [verify-chat-delivery-formal](../../verify-chat-delivery-formal/SKILL.md). Changes to covered product files still select their existing desktop journeys and trigger the formal workflow separately.

## Driving recipe

Run the skill's one-command check with production replay and both planted breaks on GitHub's hosted Linux runner. Read every model result with pstack /statechart. Local TLC-only investigation is permitted; native replay and reviews remain hosted.

The PR selector owns these files through `CI workflow:`, not a nearest desktop name. The verifier requires this workflow to pass on the exact PR head alongside Tests, downloads its identically named `chat-delivery-formal` artifact, and gives the independent judge its raw summary and run receipt. Missing, pending, failed or stale evidence cannot pass.

## Gotchas

The three current source findings are SOFT-2724, SOFT-2725 and SOFT-2726. They remain findings even when the verification-only CI job classifies them as inherited. Source equality, native replay, both mutations and restoration are required for that classification. No UI journey or binary hash certifies this model.
