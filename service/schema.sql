CREATE TABLE IF NOT EXISTS devices (
 id TEXT PRIMARY KEY, account TEXT NOT NULL, name TEXT NOT NULL,
 refresh_hash TEXT NOT NULL UNIQUE, created INTEGER NOT NULL,
 last_seen INTEGER NOT NULL, revoked INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS codes (
 hash TEXT PRIMARY KEY, account TEXT NOT NULL, challenge TEXT NOT NULL,
 redirect TEXT NOT NULL, name TEXT NOT NULL, expires INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS access_tokens (
 hash TEXT PRIMARY KEY, device TEXT NOT NULL REFERENCES devices(id), expires INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS layouts (
 account TEXT PRIMARY KEY, revision INTEGER NOT NULL, layout TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS refresh_grace (
 hash TEXT PRIMARY KEY, device TEXT NOT NULL REFERENCES devices(id), expires INTEGER NOT NULL
);
-- ISSUE-295 additive: Better Auth identity (user/session/account/verification/passkey)
-- and the token-ladder usage snapshot. Existing tables above are never altered.
CREATE TABLE IF NOT EXISTS "user" (
 "id" TEXT PRIMARY KEY NOT NULL, "name" TEXT NOT NULL, "email" TEXT NOT NULL UNIQUE,
 "emailVerified" INTEGER NOT NULL, "image" TEXT, "createdAt" DATE NOT NULL, "updatedAt" DATE NOT NULL
);
CREATE TABLE IF NOT EXISTS "session" (
 "id" TEXT PRIMARY KEY NOT NULL, "expiresAt" DATE NOT NULL, "token" TEXT NOT NULL UNIQUE,
 "createdAt" DATE NOT NULL, "updatedAt" DATE NOT NULL, "ipAddress" TEXT, "userAgent" TEXT,
 "userId" TEXT NOT NULL REFERENCES "user"("id") ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS "session_userId_idx" ON "session"("userId");
CREATE TABLE IF NOT EXISTS "account" (
 "id" TEXT PRIMARY KEY NOT NULL, "accountId" TEXT NOT NULL, "providerId" TEXT NOT NULL,
 "userId" TEXT NOT NULL REFERENCES "user"("id") ON DELETE CASCADE, "accessToken" TEXT, "refreshToken" TEXT,
 "idToken" TEXT, "accessTokenExpiresAt" DATE, "refreshTokenExpiresAt" DATE, "scope" TEXT, "password" TEXT,
 "createdAt" DATE NOT NULL, "updatedAt" DATE NOT NULL
);
CREATE INDEX IF NOT EXISTS "account_userId_idx" ON "account"("userId");
CREATE TABLE IF NOT EXISTS "verification" (
 "id" TEXT PRIMARY KEY NOT NULL, "identifier" TEXT NOT NULL, "value" TEXT NOT NULL,
 "expiresAt" DATE NOT NULL, "createdAt" DATE NOT NULL, "updatedAt" DATE NOT NULL
);
CREATE INDEX IF NOT EXISTS "verification_identifier_idx" ON "verification"("identifier");
CREATE TABLE IF NOT EXISTS "passkey" (
 "id" TEXT PRIMARY KEY NOT NULL, "name" TEXT, "publicKey" TEXT NOT NULL,
 "userId" TEXT NOT NULL REFERENCES "user"("id") ON DELETE CASCADE, "credentialID" TEXT NOT NULL,
 "counter" INTEGER NOT NULL, "deviceType" TEXT NOT NULL, "backedUp" INTEGER NOT NULL,
 "transports" TEXT, "createdAt" DATE, "aaguid" TEXT
);
CREATE INDEX IF NOT EXISTS "passkey_userId_idx" ON "passkey"("userId");
CREATE INDEX IF NOT EXISTS "passkey_credentialID_idx" ON "passkey"("credentialID");
CREATE TABLE IF NOT EXISTS usage (
 account TEXT PRIMARY KEY, updated INTEGER NOT NULL, status TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS crash_reports (
 device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
 report_id TEXT NOT NULL, account TEXT NOT NULL, received_at INTEGER NOT NULL,
 captured_at INTEGER NOT NULL, app_version TEXT NOT NULL, android_version TEXT NOT NULL,
 thread TEXT NOT NULL, summary TEXT NOT NULL, stack_trace TEXT NOT NULL,
 PRIMARY KEY (device_id, report_id)
);
CREATE INDEX IF NOT EXISTS crash_reports_device_received_idx ON crash_reports(device_id, received_at);
CREATE TABLE IF NOT EXISTS device_keys (
 device_id TEXT PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
 account TEXT NOT NULL, public_key TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('pending','approved','denied','revoked')),
 requested INTEGER NOT NULL, decided INTEGER, decided_by TEXT
);

CREATE TABLE IF NOT EXISTS sync_records (
 account TEXT NOT NULL, kind TEXT NOT NULL, id TEXT NOT NULL,
 updated_at INTEGER NOT NULL, device_id TEXT NOT NULL, document TEXT NOT NULL,
 PRIMARY KEY (account,kind,id)
);
