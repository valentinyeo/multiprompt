Each fragment supplies the end-user changelog for one app PR.
Name it changelog.d/<TICKET>-<slug>.md, for example ISSUE-365-version-stamp.md.
App code changes require a new fragment with one short plain product sentence per line; blank lines are ignored.
No ticket ids, file names, paths, code names or PR numbers in those sentences.
Never edit APP_VERSION or .ver lines by hand.
After your PR merges, run `node tools/version-stamp.mjs release`.
