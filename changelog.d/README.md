Each fragment supplies the end-user changelog for one app PR.
Name it changelog.d/<TICKET>-<slug>.md, for example ISSUE-365-version-stamp.md.
App code changes require a new fragment with specific user-visible changes; generic filler and notes about checks, tests, CI, proofs, pipelines or workflows are rejected. Pipeline-only changes need no fragment.
No ticket ids, file names, paths, code names or PR numbers in those sentences.
Never edit APP_VERSION or .ver lines by hand.
Automatic releases replace manual `node tools/version-stamp.mjs release`.
Start every commit with its ticket ID.
Releases without product notes show linked check notes.
Releases without ticketed lines cannot publish.
