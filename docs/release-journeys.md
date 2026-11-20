# Release journey gate

A release cannot publish until each changed feature has a passing, recorded journey on the unpublished x64 release executable. ARM64 still builds separately. The gate does not claim ARM64 desktop coverage.

## Mapping changes

`release-journeys.mjs plan` starts at the latest published release tag, not the newest reserved tag. It walks every first-parent commit through the candidate. Each commit retains its merged PR links and changed files. Reverts and direct commits remain in the plan.

Zig changes that only edit top-level tests or comments do not change a product feature. The plan uses the same runtime-token comparison as the changelog gate, keeps those paths in its attribution and marks them `testOnlyFiles`. New, deleted and runtime-modified files still need mapping.

Feature maps own `Release paths`, a comma-separated list of repository paths with optional `*` wildcards. A changed recipe also selects itself. All matching maps are required. A product file without a map fails preparation with its filename. This intentionally blocks a release until its missing mapping or journey exists.

Each selected map names its permitted `Journeys`. The release runs these through the existing verification workflow without the PR picker's three-journey limit. One passing journey per changed map is required. This is journey coverage, not proof of every sub-feature listed in a map.

## Publication evidence

The verifier downloads the current run's `multiprompt-x64` artifact. It does not rebuild or download a published release. Both the executable's embedded revision and its version must match the candidate. The ordinary driver records `journey.mp4` around the real desktop journey.

The publication gate checks the executable hash, source and harness revisions, current run, passing result, recorder result, named-case failures and zero-process cleanup. FFprobe reads the video and FFmpeg decodes it. Stale, rebuilt or corrupt evidence fails with the full missing-feature list, even after a matrix job fails.

A journey that fails on the candidate is a note, not a blocker, when the latest completed scheduled `verify.yml` run on master or the last published release's journey run also failed it. Only a journey that passed there and fails now blocks. A candidate failure with no recorded base run is a note as well; unreadable candidate evidence still blocks.

Release notes link each accepted artifact and name its video. `release-journeys.json` records those links, video hashes, executable hash and PR attribution. It is a signed-checksum-covered release asset. Artifact links follow GitHub's artifact retention policy.

`node tools/version-stamp.mjs release` only watches the existing automatic master release and validates its receipt. It cannot create or merge a release PR, publish, dispatch or retry a workflow.

## Historical rejection

Published [v0.28.1761](https://github.com/valentinyeo/multiprompt/releases/tag/v0.28.1761) contains [PR #1053](https://github.com/valentinyeo/multiprompt/pull/1053), the Shift+G jump. Its successful [release run](https://github.com/valentinyeo/multiprompt/actions/runs/44042909628) has build, startup and resource artifacts, but no journey artifacts. The new gate rejected the actual published executable with exit 1 and listed `chat-and-composer`, `chat-newest`, `palette`, `shortcuts` and `sidebar-sessions`.

The captured API metadata, mapping, executable digest and error are in `tools/fixtures/SOFT-2567i/historical-rejection.json`. To repeat the read-only check from a full checkout:

```sh
mkdir -p /tmp/release-1761
node tools/release-journeys.mjs plan 608b7d62944fd39b79cbbaa2c83bc6e3251f590c /tmp/release-1761/plan.json v0.28.1760
gh release download v0.28.1761 --pattern multiprompt-x64.exe --dir /tmp/release-1761
GITHUB_REPOSITORY=valentinyeo/multiprompt GITHUB_SERVER_URL=https://github.com GITHUB_RUN_ID=44042909628 \
  node tools/release-journeys.mjs check /tmp/release-1761/plan.json /tmp/release-1761 /tmp/release-1761/multiprompt-x64.exe /tmp/release-1761/receipt.json
```

No release is created and no workflow is dispatched. The portable regression also replays the captured historical mapping and absence of evidence.
