Each fragment supplies the end-user changelog for one app PR.
Name it changelog.d/<TICKET>-<slug>.md, for example ISSUE-365-version-stamp.md.
Write one plain end-user sentence per line; blank lines are ignored.
Never edit APP_VERSION or .ver lines by hand.
After your PR merges, run `node tools/version-stamp.mjs release`.
