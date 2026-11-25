# Emergency lane

Source files: tools/check-emergency-lane.mjs, tools/check-emergency-lane.test.mjs, tools/emergency-release-path.test.mjs, tools/pr-verifier-repro.test.js, .github/workflows/emergency-lane.yml, openwiki/operations/build-and-install.md
CI workflow: emergency-lane.yml

## Sub-features

When Valentin cannot reach or see his chats, or cannot work, the verification owner adds the GitHub label `emergency` to the fixing pull request. The workflow never creates that label. The label turns on the owned-journey repair rule in `tools/pr-verifier.cjs`, pauses other open pull requests through the `emergency-lane` check, and publishes through the short release path master already runs.

## How to get to it (user POV)

Nobody opens this from the app. The outage is visible when chats are missing, unreachable, or Multiprompt blocks normal work. The verification owner marks the fix pull request with `emergency`, merges it ahead of routine pull requests, and relies on the automatic master release plus the in-app updater.

## Driving it with GitHub CI

The `Emergency lane` workflow listens for pull request open, sync, ready-for-review, label, unlabeled, close and manual dispatch events. Each eligible pull request runs `node tools/check-emergency-lane.mjs check`. While any open non-draft pull request carries `emergency`, every other open non-draft pull request fails `emergency-lane` until that pull request merges, closes, or loses the label. When the emergency pull request closes or the label changes, the refresh step reruns `emergency-lane` on the remaining open pull requests. The verifier does not wait for that workflow or download its artifact; it is a lane gate, not a proof.

A pull request with the `emergency` label follows the same owned-journey-only rule as a repair pull request: `tools/pr-verifier.cjs` limits journeys to the files the diff touches. After the emergency pull request merges to master, `auto-release.yml` publishes it. Resource observation left the release path, so `tools/emergency-release-path.test.mjs` keeps the measured sub-hour path documented in `openwiki/operations/build-and-install.md` honest.

## Gotchas

Only the verification owner should add or remove `emergency`. Routine pull requests that fail `emergency-lane` need a manual or automatic rerun after the lane clears; the refresh step reruns paused pull requests but does not replace verification on the emergency pull request itself.