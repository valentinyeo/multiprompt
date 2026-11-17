# Account, devices and server sync

Journeys: servers

## Sub-features

The recipes below name the user actions, expected result and exact boundary.

## How to get to it (user POV)

Use the entry paths in the action table below on a disposable owned profile.

## Driving it with drive.ps1

Preconditions: a healthy GitHub Windows instance and the selected journey prerequisites.

Use `verify.yml` with the named executable journey, not this map stem. A journey is a recipe, not a claim of a live pass.

The recipes distinguish existing focused journeys from unreachable complete paths. UNREACHABLE names the missing data, endpoint, build mode or driver action; it never means the product passed.

### account: Account, devices and servers

Sign in with a disposable account. On a second disposable device request approval; approve on the first, then revoke it. Add/test/remove only a disposable server through Servers. Change its address and pull layout on the second device. Sign out and reopen the app.

Observable proof: Approval is required before the second key works; revoked or removed keys are rejected. Server address, layout and settings reconcile without reviving deleted entries. Sign out locks the app and does not retain a usable device login.

Journey: servers has a manual-only workflow route with an automated native recipe using real OpenSSH against a synthetic Paramiko endpoint; account-hosts/device-approval are diagnostics. UNREACHABLE until two disposable authenticated device states, a pending public key, disposable server with authorization to install/remove its key, and native account/device/sync driving are supplied. MULTIPROMPT_NO_LOGIN=1 bypasses all of this.

| Palette row or dynamic family | User reaches it |
| --- | --- |
| `SEARCH_APPROVE_DEVICES_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_LAYOUT_PULL_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_MULTIPROMPT_LOGIN_OFFSET` | Ctrl+K, type **sign in to multi bot**, then select the matching action with Up/Down and Enter. Follow `account` above. |
| `SEARCH_REMOVE_SERVER_1_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_REMOVE_SERVER_2_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_REMOVE_SERVER_3_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_SERVERS_OFFSET` | Ctrl+K, type **servers**, then select the matching action with Up/Down and Enter. Follow `account` above. |
| `SEARCH_SYNC_SIGNOUT_OFFSET` | Ctrl+K, search for **account: sign out**. Follow `account` above. |
| `SEARCH_SYNC_STATUS_OFFSET` | Ctrl+K, search for **account: devices**. Follow `account` above. |
| `SEARCH_USAGE_LOGIN_INNE_OFFSET` | UNREACHABLE as a distinct palette row: source retains a label/handler but no current result-generation path in `src/command_palette.zig`. Use the recipe above only through its documented alternative entry, not this ID. |
| `SEARCH_USAGE_LOGIN_PRIMARY_OFFSET` | Ctrl+K, type **usage sign in**, then select the matching action with Up/Down and Enter. Follow `account` above. |

## Gotchas

Never treat an offline, synthetic or diagnostic check as authenticated end-to-end proof.
