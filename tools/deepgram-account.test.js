const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.join(__dirname, "..");
const read = file => fs.readFileSync(path.join(root, file), "utf8");

function functionBody(text, name) {
  const start = text.indexOf(`fn ${name}(`);
  assert.notStrictEqual(start, -1, `${name} is missing`);
  const next = text.slice(start + 1).search(/\n(?:pub )?fn /);
  return next === -1 ? text.slice(start) : text.slice(start, start + 1 + next);
}

test("IGSH-1889: the worker serves the Deepgram key per account to devices only", () => {
  const worker = read("service/worker.js");
  const route = worker.match(/if \(url\.pathname === '\/v1\/secrets\/deepgram'[^]*?\n      \}\n/)[0];
  assert.match(route, /request\.method === 'GET' \|\| request\.method === 'PUT'/);
  assert.match(route, /if \(!device\.id\) fail\(403/);
  assert.match(route, /bind\(device\.account, 'deepgram'/);
  assert.match(route, /FROM account_secrets WHERE account=\? AND name=\?/);
  assert.match(worker, /const validSecret = .*length <= 256.*\\x21-\\x7e/);
  assert.doesNotMatch(worker.match(/async function authenticateKey[^]*?\n\}\n/)[0], /secrets/);
});

test("IGSH-1889: the account table is additive and keyed by account and name", () => {
  const schema = read("service/schema.sql");
  assert.match(schema, /CREATE TABLE IF NOT EXISTS account_secrets \([^)]*PRIMARY KEY \(account,name\)/);
});

test("IGSH-1889: saving the key in settings also sends it to the account", () => {
  const panel = functionBody(read("src/settings_panel.zig"), "finishKeyCheck");
  const save = panel.indexOf("saveDeepgramApiKey");
  const push = panel.indexOf("accountPushDeepgramKey()");
  assert.ok(save !== -1 && push > save, "the account push follows the local save");
  const entry = functionBody(read("src/account_desktop.zig"), "accountPushDeepgramKey");
  assert.ok(entry.indexOf("g_deepgram_push_pending.store(true") < entry.indexOf("g_account_has_token"), "the pending flag is set even when signed out");
  assert.match(entry, /!app_state\.g_account_has_token or app_state\.g_account_reauth\) return/);
  assert.match(entry, /pullSessionLayout\(\)/);
});

test("IGSH-1889: account sync pulls the key into the registry when it is missing or different", () => {
  const desktop = read("src/account_desktop.zig");
  const sync = functionBody(desktop, "accountSyncDeepgramKey");
  assert.match(sync, /"GET", "\/v1\/secrets\/deepgram"/);
  assert.match(sync, /std\.mem\.eql\(u8, key, remote\)/);
  assert.match(sync, /voice\.saveDeepgramApiKey\(/);
  assert.match(sync, /\[voice\] deepgram key source=account/);
  assert.match(functionBody(desktop, "putDeepgramKey"), /"PUT", "\/v1\/secrets\/deepgram"/);
  assert.match(functionBody(desktop, "accountRequest"), /accountSyncDeepgramKey\(access, job\.kind\)/);
});

test("IGSH-1889: no log line in the account key sync carries a value", () => {
  const desktop = read("src/account_desktop.zig");
  for (const name of ["accountSyncDeepgramKey", "putDeepgramKey", "accountPushDeepgramKey"]) {
    const lines = functionBody(desktop, name).split("\n").filter(line => /debugLog|syncLog/.test(line));
    for (const line of lines) assert.match(line, /^\s*(?:if \([^)]*\) )?debugLog\("[^"{}]*"\);?$|debugLog\("[^"{}]*"\)/, line);
  }
});
