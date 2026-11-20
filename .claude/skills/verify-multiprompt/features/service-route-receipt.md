# Service route receipt

Source files: service/worker.js, service/test/secrets.test.js, .github/workflows/service-route-receipt.yml
CI workflow: service-route-receipt.yml

## Sub-features

The account Worker answers `GET` and `PUT /v1/secrets/<name>` for every secret name it stores: `deepgram` and `screencast2`. A device session is required for both methods; a service key is refused. `PUT` takes exactly one field, `key`, of 1 to 256 printable ASCII bytes, and answers `{ stored: true }`. `GET` returns the caller's own value with `Cache-Control: no-store`, `404 not_found` when the account has not stored that name yet, and never returns another account's value or another name's value. A revoked device is refused on both methods.

## How to get to it (user POV)

Nobody opens this from the app. A change to the two files above runs the `Service route receipt` workflow on GitHub, and the verifier reads its result. The desktop side that reads this route is a separate change.

## Driving it with GitHub CI

The `Service route receipt` workflow has one job. It builds the Worker with `wrangler deploy --dry-run --outdir .build` on the PR head, runs `node --test service/test/secrets.test.js` with the TAP reporter, then copies the same test into a worktree of the base commit, builds that Worker and runs it there. Both exit codes and both TAP logs go into `summary.json` with `repro.part` set to `secrets`, so the receipt shows the head green and the base red on the same test.

The PR selector owns `service/worker.js` through `CI workflow:`, not a nearest desktop name. `service/test/secrets.test.js` and every other `*.test.js` file is skipped by source mapping, so a route change and its test select this receipt and no desktop journey. The verifier requires this workflow to pass on the exact PR head, downloads the artifact and gives the independent judge its raw summary and run receipt.

## Gotchas

The base run only works because the workflow copies the new test file into the base worktree; a base commit that has no such file would otherwise run nothing. The route match is one alternation over the stored names, so adding a third secret name needs a line in `service/test/secrets.test.js` and in this map. A change to `service/schema.sql` or to the desktop client is outside this receipt and still needs its own journey.
