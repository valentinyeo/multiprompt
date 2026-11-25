# MUBO-533 verification record

Goal: released desktop Claude rooms create, discover members, route mentions and finish durable work reliably.

## Faults for the owner to file

The worker Hypertask wrapper denies both board access and `hypertask feedback`. No board write was possible. The owner must record these repository faults on the Multi Bot Features board and view.

- The room bridge rejected the symlink that the real runtime installer publishes as `reader.py`. The bridge now verifies and uses the immutable digest file from `active.json`.
- Hosted Zig setup restored an empty archive cache. Two official downloads timed out after receiving about 9 MB of a 55 MB archive. [Failed build](https://github.com/valentinyeo/multiprompt/actions/runs/45522511900). The five-minute room-check job also expired inside installation. Python checks now run first, and the job budget includes installation. The shared installer falls back to cached compiler and library archives from the registry, pinned to version 0.16.0 and separate SHA-512 integrity values. Both sources fail closed on an integrity mismatch.
- SSH push authentication stopped working during this run. The branch was pushed over HTTPS instead.

## Hosted evidence

- [Initial Python failures](https://github.com/valentinyeo/multiprompt/actions/runs/45520435553), head `87a4de155`.
- [Initial desktop refresh, mention, creation and Restart failures](https://github.com/valentinyeo/multiprompt/actions/runs/45521131553), head `b3245eb07`.
- [Before/after checks](https://github.com/valentinyeo/multiprompt/actions/runs/45524981987), head `06bd4bd2f`. Python baseline reproduction and current Python suites passed. Canonical process and desktop results are still being checked.

No build, test suite or app verification ran on the shared server. These checks do not prove the real Windows UI or paid Claude replies. The paired phone work remains MUBO-536; Codex/Pi remains PR B.

## Decisions

Fix Root Causes moved admission off history reads and corrected installed-runtime selection. Test Behavior, Not Implementation uses real store events, a real installed runtime, host-loop functions and extracted desktop logic instead of relying on recent-send flags.
