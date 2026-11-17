# Reusable baseline evidence

The PR verifier restores baseline evidence before it creates the base job matrix. Only cache misses reach `verify.yml`. Head journeys still run on every PR. Cache tooling comes from the workflow revision, so older PRs need not contain the tool. The journey scripts and their content hash still come from the PR head.

## Identity

Each immutable `base-v1-*` artifact identifies one journey, one application commit SHA, one harness content hash, and one DPI/theme variant. Every variant must be available before the verifier reuses a journey.

The content hash covers the verification scripts, fixtures, build configuration, assets, extension, service, and the exact reusable workflow executed by Actions. It also covers non-Zig source helpers and the source catalogs read by the driver: app state, palette, sidebar, shortcuts, notification ports, and changelog. Top-level application Zig files outside these catalogs and tool unit tests do not change this version. Changes to these runtime inputs invalidate stored results without a manual version bump.

## Evidence contract

An artifact is reusable only when it contains:

- A product pass or failure with screenshots, Doctor data, and completed cleanup.
- Build provenance identifying the exact baseline revision and embedded revision.
- A manifest matching the cache identity, repository, and source run.
- A source run from the same repository and an allowed verification workflow.

Infrastructure failures, expired artifacts, unavailable downloads, and incomplete display coverage are cache misses. `tmux-binding` remains a miss because its separate Linux semantic proof is not contained in the Windows artifact. Cached artifacts expire after seven days.

The existing repro gate still requires the named journey to fail on current master and pass on the PR head. Reusing a master pass cannot satisfy that gate. Stored evidence is copied under its original baseline artifact name, so the judge and deterministic gates read the same results, screenshots, and cleanup records.

`pr-verifier-base-reuse/reuse.json` records the baseline SHA, harness version, reused journeys, source artifact/run IDs, and the planned Windows journey counts before and after lookup. These counters exclude build and Linux jobs. They are not wall-time measurements.

## Hosted measurement command

```sh
node tools/measure-base-reuse.cjs owner/repo <cold-run-id> <warm-run-id>
```

The command reads two completed PR runs without waiting or polling. Both runs must request the same journeys on the same baseline and harness version. The warm run must reuse evidence from the cold run and schedule fewer baseline Windows jobs.

Its JSON report includes actual total and scheduled job counts, baseline Windows job counts, failed jobs, initial queue delay, and wall time from workflow creation through the final job completion. Wall time includes the shared account queue. A quicker failed run does not prove the approximately twenty-minute goal.
