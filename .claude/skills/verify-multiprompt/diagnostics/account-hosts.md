# Account servers

## Sub-features

Remove an account server permanently by slot, keep other servers unchanged, reject stale uploads from both old and current clients, and retain removal through client cache refresh and restart. Local SSH configuration, known host keys and sessions remain usable and untouched by removal.

## How to get to it (user POV)

Ctrl+K → Account: Remove server 1, Account: Remove server 2 or Account: Remove server 3. The existing confirmation dialog names the server and hostname; No is the default. There is no destructive keyboard shortcut. Sync: Pull Now and ordinary background sync use the same filtering.

## Driving it with the Test workflow

The baseline `verify.yml` desktop harness has no account-service stub and explicitly bypasses sign-in. This journey therefore runs deterministically in the GitHub **Test** workflow, not through a pretend signed-in desktop journey or `verify.yml` feature selection.

1. Seed three account servers in Miniflare, remove slot 2 through a `host_removal` PUT, and independently read the stored account layout.
2. Re-send all three slots from an old client without `host_removal`, then a current client omitting `removed_hosts`. Both must retain the tombstone and only slots 0 and 1. Old GET, PUT and conflict replies must never expose `removed_hosts`.
3. Feed the real Worker snapshot into the production desktop account-sync fixture with a stale slot-2 cache and an existing local `Host remote-3` block. Sync twice, restart with an empty memory cache and the persisted host base, then sync again. The server must never return to the account, client cache or saved host base. No publish or SSH append is allowed.
4. Require the complete local config to remain byte-identical, including a user-written `Host personal` block for a different alias. Zero SSH append attempts also guards known_hosts import. Separately exercise the real remove-job sync branch against the deterministic service boundary, and pure Zig filtering, schema round trip, capability detection, rebase and equality tests.

CI wiring: `service/test/worker.test.js` runs the Miniflare journey and the compiled production sync fixture in `test-worker`; `tools/account-hosts.test.js` runs the remove-job fixture in the existing Test Zig graph; `zig build test-account` covers `src/account_hosts.zig`, `src/session_layout.zig`, `src/account_layout.zig` and `src/account_client.zig` through `test-vps`. `tools/account-host-removal.test.js` is a lightweight production-merge/schema/surface contract check with the pre-fix Worker as a negative control; it runs in the existing `test-update-source` responsive-startup contract step. GitHub job logs are the evidence; no live run is claimed by adding this map.

## Gotchas

The fixture replaces only the account HTTP and SSH/file boundaries; it executes extracted production desktop sync logic. It does not prove real sign-in, native confirmation clicks, live SSH resolution or cross-device delivery. The real Worker uses Miniflare and D1. Local tests must not start Miniflare or compile Zig on the shared machine. Full test execution and Windows compilation belong to GitHub Actions after the runner pushes. Tombstones are permanent: this action does not offer slot reuse or remove existing tabs, user config blocks or known_hosts lines.
