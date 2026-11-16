# Repeated thumbs-up replies

## Sub-features

- Two thumbs ups on the same long reply have separate delivery identities.
- Both attempts are accepted and consumed by the agent.
- The quoted line ends at a whole word with an ellipsis.
- Neither visible transcript text nor AI input contains the private code.
- The existing composer draft survives both reactions.

## User entry points

Right-click an assistant reply, then click the thumbs-up menu item twice, consuming the first reply before repeating.

## Driving it with control.ps1

Dispatch `gh workflow run verify.yml --ref <branch> -f feature=chat-reaction-replies`.

The journey uses the existing chat-delivery Windows app, isolated saved remote tab, production embedded reader, fake tmux and synthetic Claude transcript boundary. It selects AMOLED through Ctrl+K, types a draft, locates the first long assistant bubble from native pixels and right-clicks it. A genuine mouse click selects thumbs up. The driver reads the app's saved acceptance and independent fake-agent queue, then lets the agent consume it. It repeats on the same original reply and requires a different saved delivery identity.

The independent checker requires exactly two whole-word quoted lines at both enqueue and consumed-attachment boundaries. It reads each saved outbox snapshot, both accepted screenshots, the real Ctrl+K Select all / Ctrl+C transcript copy, the unchanged composer draft and zero-process cleanup. Keep `reactions-menu-*.png`, `reactions-accepted-*.png`, `reactions-consumed-*.png`, `actions.json`, `doctor.json`, `build.json`, `reactions/transcript.jsonl` and `result.json`. Inspect the screenshots yourself.

Run the identical head harness against the merge base through the PR verifier. The base must fail the exact code-free transport assertion, rather than an unrelated desktop setup failure.

## Gotchas

This is not real SSH, account sign-in or a live AI service. Its two replies intentionally share the same quoted prefix. Without an exposed target code those ambiguous reactions may remain ordinary transcript bubbles; this journey does not claim target-specific badges or restart identity. The existing quoted-reaction badge journey remains separate and unchanged.
