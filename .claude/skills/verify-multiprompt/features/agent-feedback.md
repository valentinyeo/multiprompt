# Chat feedback command

Source files: src/multibot_feedback.py, tools/multibot-feedback-test.py, skills/multi-bot-feedback/*, .github/workflows/test.yml
CI workflow: test.yml

## Sub-features

`/multi-bot-feedback` uses one shared skill and provider prompt adapters to invoke the existing runtime feedback tool in detailed-report mode. The caller needs no token. The existing host queue eventually files it using host credentials. Report text includes expected/actual behavior, chat name/session ID, desktop/runtime versions and six trimmed recent steps. Open titles/signatures merge; owner labels follow error/feature, transition and Android keywords. Reviewed PNG attachments use the existing snapshot/upload/readback path. Wish callers retain their existing behavior.

## How to get to it (user POV)

Invoke the installed chat skill with `/multi-bot-feedback [summary] [screenshot.png]`. Codex custom prompts use `/prompts:multi-bot-feedback`; agents can invoke the shared skill themselves. Vstack Maintainer installs the files as described in `skills/multi-bot-feedback/README.md`. No desktop UI action is added.

## Driving it with GitHub CI

The `reader-tests` job in `test.yml` runs `tools/multibot-feedback-test.py` on the exact PR head against a fake board and fake `mp-sessions whoami`. It checks token-free queue intake, report fields, redaction before saving and trimming, duplicate occurrences, retry convergence, label selection and screenshot attachment after queueing. The reader-bundle case checks runtime tool publication and desktop-version metadata. It also runs the new token-free report case against the base source to demonstrate that the old CLI rejects the new command options. Artifact `feedback-command` retains the receipt and raw logs.

## Gotchas

These are fake-network command tests, not a live ticket filing or proof of provider command discovery. They never file real tickets. The command intentionally reports `queued` without host credentials. Image pixels require human/agent review; text redaction cannot sanitize screenshots. Unknown chat/version metadata remains explicitly unavailable. Desktop reader changes also follow their existing runtime checks.
