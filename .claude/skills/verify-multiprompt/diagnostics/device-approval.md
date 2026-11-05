# Desktop device approval

## Sub-features

Discover a new pending device during account sync. Show the existing approval dialog once for that device and login key. Keep Cancel quiet on later syncs. Allow explicit retry through the existing account command. Approve installs the public key on every configured server reachable from desktop before recording approval through the existing account API.

## User entry points

- Automatic discovery through signed-in account sync.
- Ctrl+K → Account: Approve devices.
- The same command appears in Shortcuts and the keyboard guide. This infrequent confirmation has no dedicated shortcut.

## Hosted deterministic verification

The Test workflow runs `tools/account-keys.test.js` through the existing Zig integration test graph. Its extracted production prompt and reply-dispatch fixture covers first discovery, unchanged pending keys after Cancel, new devices, changed keys, explicit retries and invalid reply guards. `src/account_keys.zig` and `src/account_keys_shell_test.zig` cover all-host rollout, unreachable hosts and idempotent authorized-key editing.

The auto-discovered `tools/device-approval-1636.test.js` compiles the production key rollout and device-key sync functions with fake SSH, account API, key publication, host discovery and protected storage. It checks named partial and total failures, approval ordering, denial, API errors, quiet background cleanup and retry. Two-device cases check that each confirmed approval retains its own skipped servers, including when a later approval fails. It checks the native result dispatch in source. The hosted red gate runs the same suite against the full merge-base source. Hosted runs must pass before this is evidence; no run is claimed here.

These checks substitute account and SSH boundaries. They do not prove live sign-in, real SSH installation, an actual native prompt screenshot, phone connectivity or cross-device delivery. Never run the compiled fixtures on the shared server.

## Live acceptance proof

1. Use an already signed-in desktop that can open all configured servers.
2. Sign in a new phone. Wait for the account device check.
3. Capture the desktop's "Approve this device?" prompt without exposing keys or private account details.
4. Choose Yes. On the phone, reconnect to each server, including a server only desktop could previously open.
5. Capture the phone Inbox without the rejected-login-key line.
6. Cancel a different new-device prompt. Ordinary sync must not repeat that prompt. Ctrl+K → Account: Approve devices must reopen it.

The existing offline `verify.yml` journey bypasses login and cannot supply this proof. Keep live acceptance gates open until both screenshots and successful phone connections exist. A green Test workflow is deterministic regression evidence only.
