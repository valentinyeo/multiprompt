# Verification skill eval

This checks whether an agent can use the skill, not just repeat its instructions. `.github/workflows/verify-skill-eval.yml` runs every Monday at 05:41 UTC, on relevant pull requests, and through its manual trigger. No workflow dispatch happens inside the exercise.

## Cases

`tools/verify-skill-cases.json` holds three organic requests and the hidden answers:

| Case | Request | Journey | Required verdict |
| --- | --- | --- | --- |
| maple | Appearance | appearance | PASS |
| cedar | Light remains dark | appearance | FAIL |
| birch | Ctrl+K does not open | command-palette | FAIL |

The Windows build matrix compiles the current revision three times. Maple is unchanged. Cedar disables the Light choice in production theme selection. Birch swallows ordinary Ctrl+K instead of opening the palette. Source replacements must match exactly once; source drift fails the build rather than silently removing the negative control. Source patches and executable hashes stay in `desktop-*` artifacts. No planted change is committed to production source.

## Blinding and execution

DeepSeek Flash and Codex GPT-5.4 receive the same request per case. Each has a fresh `multiprompt` workspace containing only the unmodified skill and feature maps. Neither receives the hidden answers, source patches, model comparisons or case identifiers. Models choose from the entire feature index, not a shortened list containing only the expected recipes.

Both clients use the same workspace tools. The host records successful file reads separately from the model's transcript. `run_journey` launches the original `control.ps1` on a hosted Windows desktop, with the downloaded executable's checked hash and version. It accepts one feature choice and performs real keyboard input and owned cleanup. A wrong choice is not redirected to the expected journey. Evidence is produced by execution, not fabricated or replayed.

DeepSeek cannot view screenshots. Its tool reports that limitation; it must base its claims on the native observations and saved files. Codex can read the PNGs through MCP. Both retain screenshots for independent inspection.

The five mandatory criteria are:

1. Read the skill, index and correct recipe before execution.
2. Execute the journey that covers the request.
3. Match the executable to Doctor and complete owned cleanup.
4. Return PASS for clean behavior, or FAIL from the planted assertion for each regression. Infrastructure errors do not count.
5. Read the cited evidence and make claims it supports.

A Claude Sonnet judge reads all six responses in one pass, under shuffled anonymous labels. It receives no model identities. It checks evidence claims against the observed file contents and anonymous screenshots. Its family differs from both participants. The final check requires every observed criterion and every independent judgment to pass. A missing family, missing case, empty response or incomplete cleanup fails closed.

## Artifacts and credentials

- `skill-*` contains the organic request, raw client transcript, host tool trace, answer, Doctor, screenshots, saved files, execution log and cleanup evidence.
- `verify-skill-eval-results` contains `blind.json`, `summary.json`, anonymous screenshots, `judge.json` and the separate label-to-model mapping in `identities.json`.
- `desktop-*` contains the actual executable, source patch and build identity.

The two existing verifier credentials remain `DEEPSEEK_API_KEY` and `CLAUDE_CODE_OAUTH_TOKEN`. `CODEX_AUTH_JSON` supplies the existing Codex plan login to its pinned client. Only same-repository pull requests can run credentialed jobs. The isolated Codex home is removed after use and never uploaded.

The workflow is not a release gate and never merges a pull request. A failed eval is evidence to repair the skill or driver, not permission to relax the hidden answer. Run the focused checker with `node --test tools/verify-skill-eval.test.mjs`.
