# Optional account and layout service

A Cloudflare Worker and D1 database implementing device enrollment, PKCE authorization codes, rotating refresh tokens, device revocation, and revision-based workspace synchronization. Layout metadata is plaintext in D1, not end-to-end encrypted. Tokens are stored hashed; the desktop protects local credentials with Windows DPAPI.

## Configure your own deployment

`wrangler.jsonc` is an example, not a ready-to-deploy production configuration. Replace:

- `account_id`: your Cloudflare account ID
- route `pattern`: your account-service domain
- `database_id`: the ID from `npx wrangler d1 create multiprompt-account`
- `ACCOUNT_EMAIL`: the default account receiving usage updates
- `ALLOWED_EMAILS`: comma-separated emails permitted to use Better Auth
- `AUTH_ORIGINS`: your account-service and dashboard HTTPS origins
- `COOKIE_DOMAIN`, `RP_ID`: your shared cookie domain and passkey relying-party domain
- `EMAIL_FROM`: your verified sign-in sender address

Keep `ACCOUNT_EMAIL` in `ALLOWED_EMAILS`. Sign-in uses only Better Auth; remove any legacy edge login gate from your deployment. Without a Better Auth session, device authorization redirects to the service's own sign-in page. There is no plaintext development authentication bypass.

Better Auth provides email codes, magic links, passkeys and an optional Google sign-in, with a dashboard at `https://dash.example.com`. Configure `BETTER_AUTH_SECRET` and `USAGE_PUSH_TOKEN` through Wrangler secrets. Email delivery requires a configured email binding, `RESEND_API_KEY`, or `BETTER_AUTH_API_KEY`; Google sign-in requires `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET`. Set `USAGE_ACCOUNT` to override the usage recipient; otherwise it uses `ACCOUNT_EMAIL`. Never commit secret values.

```sh
npm ci
npm test
npx wrangler d1 execute multiprompt-account --remote --file schema.sql
npx wrangler deploy
```

Provide `CLOUDFLARE_API_TOKEN` through your environment or a secret store. Never commit it. Deploy only to resources you own. The example domain must be changed before deployment. Owner-specific provisioning and production verification scripts are not included.

Before first use, seed `layouts` with your configured account email, revision `1`, and a schema-1 JSON layout. An empty layout is valid:

```json
{"schema":1,"revision":1,"workspaces":[],"tabs":[]}
```

For self-hosted desktop sync, change the public service origin in `src/account_client.zig`. `MULTIPROMPT_NO_LOGIN=1` skips account login and cloud sync for local development. This does not bypass Worker authentication.

Read Android crashes newest first with `python3 service/crash-reports.py --limit 20` using `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN`; use `--database NAME` to override `multiprompt-account` or `--json` for raw rows.

## Tests and API

`npm test` bundles the Worker first, then runs it against local D1 through Miniflare. Device flows sign in through Better Auth with email codes captured from mocked outbound mail; no test-auth bypass is deployed. Passkey re-confirm uses `/signin?fresh=1&next=%2F%3Fpasskey%3Dadd` on either host, preserving the 15-minute fresh-session requirement.

- `GET /health`: service/schema identity
- `GET /`, `GET /signin`, `/api/auth/*`: dashboard and Better Auth sign-in
- `GET|POST /login`, `GET|POST /authorize`: device approval with random state and PKCE S256; GET shows confirmation or redirects to sign-in, and same-origin POST approval returns a 303 to the callback with a one-use, two-minute code and state, not tokens
- `GET /v1/me`: current browser or device identity
- `GET|PUT /v1/usage`: account usage readback and service-token-authenticated ingestion
- `POST /oauth/token`: authorization-code or refresh-token grant
- `GET /v1/devices`, `DELETE /v1/devices/{id}`: list and revoke devices; revoked device keys remain listed
- `PUT /v1/device-key`: device Bearer auth; register an Ed25519 public key as pending, preserving status for an unchanged key
- `GET /v1/device-keys`: device Bearer auth; list account device public keys and approval status
- `POST /v1/device-keys/{device_id}/approve`: device Bearer auth; approve another device's pending key on the same account
- `POST /v1/device-keys/{device_id}/deny`: device Bearer auth; deny another device's pending key on the same account
- `POST /v1/crash-reports`: device Bearer auth; strict Android report fields, 32 KiB body limit, duplicate IDs scoped to each device, newest 50 reports per device retained and deleted on revocation
- `GET /v1/layout`, `PUT /v1/layout`: revision-based layout sync; stale writes return 409

Callbacks accept only exact Android companion callback schemes or `http://127.0.0.1:<port>/callback`. Layout schema allows workspace names and tmux tab names, identities, host-slot indices (0/1/2), workspace membership, optional manual-title flags, and optional boolean `favorite` stars, and optional non-negative safe-integer `used` Unix-epoch millisecond timestamps. It rejects local paths, PIDs, SSH keys, and credential fields. Limits match desktop capacity: nine workspaces and 256 tabs.

Star-aware clients send `X-Layout-Features: favorite` on every layout GET/PUT. All layout responses advertise that header; only declaring clients receive `favorite` fields, including in 409 winner bodies. Storage preserves explicit `true` and `false`; absence means unknown, not false. Legacy PUTs preserve stored values by case-insensitive host/session identity and discard client-supplied favorites otherwise. Declaring PUTs store exactly the sent boolean or absence; send `false` to unstar across clients.

Clients syncing usage send `X-Layout-Features: favorite,used,visits,input`. Layout replies advertise all four features and negotiate them independently with trimmed comma-list tokens. Replies, including 409 winners, hide `used` from clients without that token. Legacy saves copy stored usage by case-insensitive host/session identity and discard unmatched incoming usage. Declaring saves keep the maximum of stored and incoming times; absence keeps stored time. Usage-only desktop publishes require a stamp more than ten minutes newer than the last sent or received time. Local caches mark Unix timestamps with `used_unix` to distinguish older Windows-epoch stamps.

Optional `visits` is an ascending, unique array of at most eight non-negative safe
integers (Unix milliseconds); absence means unknown. Every layout response,
including errors and 409 winners, advertises `favorite,used,visits,input`. Responses hide
visits unless the exact `visits` token is declared. Old-client PUTs copy stored
visits by host/session identity and discard unmatched incoming visits. Declaring
PUTs union stored and incoming visits, deduplicate, sort ascending and retain the
newest eight; omission keeps stored visits. The cap is the only way a visit is
removed from a retained tab.

Optional `input` uses exactly the `used` safe-integer, negotiation and maximum-merge
rules, but records Unix milliseconds of human input only: chat send, voice send
(including auto-send), dictation into a terminal, or terminal keystrokes. Old-app
PUTs preserve it and omission never clears it. A stamp publishes immediately
when the synced input is more than 60 seconds old (or unknown), otherwise it
rides the next publish. Keystrokes do not each generate network requests.
`used` remains for compatibility, but plain switches and step-jumps no longer
stamp it, and it plays no part in Frequent.

A watch-only look requires an explicit user session selection (click, keyboard
tab navigation, palette pick or opening a session), followed by ten continuous
seconds with that session in front and the app foreground. Loss of focus resets
the dwell; returning starts a fresh front period for that user-selected session.
Startup, restore, server apply, respawn, automatic switches, Inbox step-jumps and
attention stepping cannot start looks. Each qualifying period records its start
time once. Android requires its app foreground with the session open in its
reader or terminal. Every look enters layout publishing independently of `used`.

Frequent is the first split, then All, Favorites and workspaces, with persisted
selected-split migration. A tab qualifies when `input >= now - 24h`, or when at
least three visits are `>= now - 6h`. Boundaries are inclusive and future values
count. No local-front or globally-newest exception remains. The order key is
input when its rule applies, otherwise the newest visit. Android follows
`newestSessionsAtBottom`; desktop has no equivalent setting and paints oldest
to newest, so the newest key is the last bottom row. Shared fixture:
`tools/fixtures/issue-415-frequent.json`; at its fixed clock the screen reads
beta, alpha, gamma (bottom). `src/fixtures/issue-415-frequent.json` is identical.

Clients send the `hosts` feature token to share up to three server addresses, users, ports and public host keys, never private keys or identity files.
Hosts are hidden from older clients, whose saves preserve them; host-aware saves replace only the server slots they send.

## Opt-in laptop record sync

ISSUE-252 adds `GET|PUT /v1/sync-records` and the additive `sync_records` table. The endpoint requires a non-revoked device Bearer token, scopes all rows to its account, rejects unknown/secret fields, and merges document metadata by field stamps and monotonic activity; tombstones expire after 30 days. PUTs accept at most 16 changed records and require the authenticated device ID; stale writes, races and capacity errors are explicit. The desktop uses records only for supplemental deletion history: `/v1/layout` remains authoritative for every existing host, workspace, tab and settings field. Payloads contain no SSH keys, passwords, machine-local paths or window geometry. No deployment is performed by the desktop PR. Apply the schema and deploy the Worker separately before enabling this feature. See [the protocol and full field inventory](../docs/laptop-sync.md). The existing `/v1/layout` API is unchanged for legacy clients.
