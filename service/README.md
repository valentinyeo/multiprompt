# Optional account and layout service

A Cloudflare Worker and D1 database implementing device enrollment, PKCE authorization codes, rotating refresh tokens, device revocation, and revision-based workspace synchronization. Layout metadata is plaintext in D1, not end-to-end encrypted. Tokens are stored hashed; the desktop protects local credentials with Windows DPAPI.

## Configure your own deployment

`wrangler.jsonc` is an example, not a ready-to-deploy production configuration. Replace:

- `account_id`: your Cloudflare account ID
- route `pattern`: your account-service domain
- `database_id`: the ID from `npx wrangler d1 create multiprompt-account`
- `ACCESS_TEAM`: your Cloudflare Access team domain
- `ACCESS_AUD`: your Access application's audience tag
- `ACCOUNT_EMAIL`: the email permitted by your Access allow policy

Protect `/login` with Cloudflare Access email one-time-code authentication and a policy allowing that same account email. The Worker independently verifies the signed Access JWT, issuer, audience, expiry, and email. Missing configuration or invalid assertions deny login; there is no plaintext development authentication bypass.

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

## Tests and API

`npm test` runs the actual Worker against local D1 through Miniflare, using freshly generated RSA keys and signed example-account assertions. `npx wrangler dev` cannot complete production Access login; use the tests for local enrollment verification.

- `GET /health`: service/schema identity
- `GET /login`: Access-protected login with random state and PKCE S256
- `POST /oauth/token`: authorization-code or refresh-token grant
- `GET /v1/devices`, `DELETE /v1/devices/{id}`: list and revoke devices
- `GET /v1/layout`, `PUT /v1/layout`: revision-based layout sync; stale writes return 409

Callbacks accept only exact Android companion callback schemes or `http://127.0.0.1:<port>/callback`. Layout schema allows workspace names and tmux tab names, identities, host-slot indices (0/1/2), workspace membership, and optional manual-title flags. It rejects local paths, PIDs, SSH keys, and credential fields. Limits match desktop capacity: nine workspaces and 256 tabs.
