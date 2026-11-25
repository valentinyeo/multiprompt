# Agent feedback wishes

Source files: src/multibot_feedback.py, tools/multibot-feedback-proof.py, .github/workflows/agent-feedback.yml
CI workflow: agent-feedback.yml

## Sub-features

- A wish from any chat reaches board 13734 with the existing Multiprompt and Agent Feedback labels and a ticket number in whatever prefix that board uses today (`MUBO`).
- The board rejects ticket ids and long sentences outside quote blocks, so a ticket leads with short plain lines and keeps the full want, the full why and the app version and provider details inside `> ` quote blocks.
- The title is the first ten words of the want, so a repeated wish finds the existing ticket and votes instead of creating another.
- With `HT_TOKEN` unset, the tool uses the chat's own agent login file and passes it to the hypertask CLI for that subprocess only. No token file keeps the wish local and says `agent token unavailable`.

## How to get to it (user POV)

Nobody opens this from the app. An agent runs `multibot-feedback "<want>" --why "<why>"` in a chat; the wish is saved locally, then filed or voted on the board. Review them at https://app.hypertask.ai/project?id=13734&view=agent-feedback.

## Driving it with GitHub CI

One Linux job runs `python3 tools/multibot-feedback-test.py`. Its cases drive the real tool against a fake `hypertask` executable: a wish files on board 13734, the printed link is `https://app.hypertask.ai/detail/project-13734/<number>`, the title is the first ten words of the want, and every long line sits inside a `> ` quote block. The same suite covers the agent-token fallback, a wish kept local with no token, any ticket prefix, and the queue cutoff.

One artifact named `agent-feedback` holds `summary.json` and the case log. The PR selector owns `src/multibot_feedback.py` and `tools/multibot-feedback-proof.py` through `CI workflow:`, not a nearest desktop name. The verifier requires this workflow on the exact pull request head, downloads the artifact and gives the independent judge its summary and run receipt.

## Gotchas

The cases use a fake board, so a green receipt says nothing about a real board write or a real agent token. `tools/multibot-feedback-proof.py` proves those against the real board and needs the authorized agent secret, so it runs only in the nightly `chat-history-reader-proof` dispatch. Changing the title or description shape changes what a repeated wish matches.
