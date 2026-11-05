Each fragment supplies the end-user changelog for one app PR.
Name it changelog.d/<TICKET>-<slug>.md, for example ISSUE-365-version-stamp.md.
App code changes require a new fragment with specific user-visible changes; generic filler and notes about checks, tests, CI, proofs, pipelines or workflows are rejected. Pipeline-only changes need no fragment.
No ticket ids, file names, paths, code names or PR numbers in those sentences.
Never edit APP_VERSION or .ver lines by hand.
Automatic releases replace manual `node tools/version-stamp.mjs release`.
Start every commit with its ticket ID.
Release notes use the ticket number and its authoritative board title, not fragment text.
The checked-in title catalog supports offline builds and historical releases.
Trusted release jobs resolve missing titles from the board and fail if any title is unavailable or invalid.
Historical entries without identifiable tickets are omitted; ticketed entries are never silently omitted.
Releases without ticketed lines cannot publish.
