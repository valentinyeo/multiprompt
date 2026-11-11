# Release path

Master pushes start release workflows.
Both x64 and arm64 builds run.
Gitleaks gates publication.
The x64 app must open successfully.
Its visible ZigShell window must respond.
The launch job allows five minutes.
A screenshot and process details record proof.
Signed assets publish after these gates pass.

## Permanent update origin

Installed releases through v0.28.1660 require exact asset URLs under
`https://github.com/valentinyeo/multiprompt/releases/download/`.
A GitHub repository rename changes `browser_download_url` in release API
responses. Redirects cannot repair those installed clients.

Keep `valentinyeo/multiprompt` permanently, including its history, issues,
releases and existing pages. Create `valentinyeo/multibot` from that public
history as the development repository; do not rename or delete the old one.
This preserves old project links without recreating the namespace and losing
GitHub's redirects. The old repository must not be archived: its update
workflow still needs to publish releases.

The new repository runs the existing signed release pipeline. After the first
new release, `legacy-update-feed.yml` copies verified release bytes back to
the old repository every fifteen minutes. Its repository-scoped GitHub token
publishes as `github-actions[bot]`, which older clients require. Reads of the
other public repository omit that token and the checkout authorization header.
Sending the workflow token hides the other repository, because the token cannot
leave its own repository. It imports the
release tag's commit, checks the original Ed25519 signature and every asset's
checksum, and publishes a draft only after all files pass. It never re-signs
or overwrites a published release. A retry can complete its own partial draft.
The mirror shares the publication lock with the existing release workflow.
No cross-repository credentials or extra signing keys are needed.
The new-source release preparation refuses a renamed or archived legacy
repository, or a disabled mirror workflow. This also catches GitHub disabling
scheduled workflows after repository inactivity; restore the old workflow
before publishing another new-source release.

During the transition, leave existing releases and download names unchanged.
Once development moves, stop pushing app changes to the old master branch;
only the new source should build releases. The mirror remains on the old
repository's default branch. It intentionally does nothing until the new
repository exists. A new source without a signed release fails closed.
After creating the new repository from the public history, run **Legacy update
feed** there manually with `bootstrap` enabled. This seeds its release baseline
with the existing signed legacy release, without rebuilding or signing again.
Configure the existing release secrets on the new source before its first app
change. Normal new-source runs never mirror backwards into themselves.

Before retiring the old development path, run **Legacy update feed** manually.
Require both its mirror publication and old-client proof to pass. Check the old
release API still reports `/multiprompt/` download URLs, then check an older
installed copy stages that signed release through its in-app updater. Do not
replace its executable by hand. Keep the old repository even after current
users update: an offline installation can return later.

The hosted old-client proof uses the unchanged v0.28.1660 URL validator and
its actual release executable to verify a newer signed manifest. A literal
rename is the failing control. The permanent legacy origin is the passing
case; this simulation is not evidence of a completed repository migration.

Tests run nightly or manually.
Their results cannot block releases or trigger reverts.
Auto-revert and automerge have disabled job guards.
They also require disabling through GitHub settings.
The original release workflow remains archived.
Find it at `tools/workflow-archive/release.yml`.
Broader release diagnostics use `release-diagnostics.yml`.
Gitleaks also runs on pushes.
TruffleHog runs on scheduled and manual scans.

Nightly and manual workflow inventory:

- `account-bundle.yml`
- `account-journey.yml`
- `background-close.yml`
- `bot-avatars.yml`
- `browser-corners.yml`
- `browser-toggle-normal.yml`
- `chat-bench-ab.yml`
- `chat-history-retention.yml`
- `chat-perf-bisect.yml`
- `chat-replies.yml`
- `chat-shape-switch-proof.yml`
- `chat-style.yml`
- `chat-table-bench.yml`
- `chat-transcript-reconcile.yml`
- `check-red-run.yml`
- `color-emoji.yml`
- `docs-site.yml`
- `freeze-recorder.yml`
- `hax-sessions.yml`
- `held-queue.yml`
- `idle-poll-proof.yml`
- `large-history-switch.yml`
- `ledger-guard.yml`
- `link-picker.yml`
- `manage-snippets.yml`
- `no-comments.yml`
- `notifications-rejection.yml`
- `palette-dialog-design.yml`
- `probe-chrome-frameless.yml`
- `question-journey.yml`
- `reaction-journey.yml`
- `release-diagnostics.yml`
- `release-gate.yml`
- `remote-switch.yml`
- `session-notes.yml`
- `shared-sidebar.yml`
- `test-repeat.yml`
- `test.yml`
- `title-pill.yml`
- `verify-close-unattached.yml`
- `verify-long-chat.yml`
- `verify-reconnect.yml`
- `verify.yml`
- `window-controls.yml`
- `workspace-journey.yml`
- `workspace-number-shortcuts.yml`
