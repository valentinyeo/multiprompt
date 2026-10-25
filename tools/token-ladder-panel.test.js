const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const source = require('./app-source').readAppSource();
const wiki = fs.readFileSync(path.join(root, "openwiki", "operations", "keyboard-shortcuts.md"), "utf8");

test("Token Ladder feeds the usage panel from Host 2 in the background", () => {
  assert.match(source, /fn parseLadderStatus\(/);
  assert.match(source, /token-ladder\/status\.json/);
  assert.match(source, /LADDER_REFRESH_MS: u64 = 180_000/);
  const thread = source.slice(source.indexOf("fn aiPaceFetchThread()"));
  assert.match(thread.slice(0, 600), /ladderSnapshotForPanel\(\)/);
  assert.doesNotMatch(source.slice(source.indexOf("fn paintSidebarAiPaceCard")), /ladderFetchRemote/);
  assert.match(thread.slice(0, 900), /fetchAiPaceSnapshot\(&response\)/);
});

test("Token Ladder commands exist on all three surfaces", () => {
  for (const label of ["Token Ladder: Auto", "Token Ladder: Burn Claude", "Token Ladder: Burn Codex", "Token Ladder: Open Dashboard"]) {
    assert.ok(source.includes(`L("${label}")`), `palette row ${label}`);
  }
  assert.match(source, /Ctrl\+K \\u\{2192\} Token Ladder: Auto \/ Burn Claude \/ Burn Codex/);
  assert.match(source, /Ctrl\+K \\u\{2192\} Token Ladder: Open Dashboard/);
  assert.match(wiki, /Token Ladder: Auto \/ Burn Claude \/ Burn Codex/);
  assert.match(wiki, /Token Ladder: Open Dashboard/);
  assert.doesNotMatch(wiki.match(/Token Ladder[^\n]*/g).join("\n"), /Ctrl\+Alt/);
});

test("Token Ladder rows are excluded from generic palette rows, marked current, and versioned", () => {
  assert.equal((source.match(/!is_ladder and result_idx >=/g) || []).length, 4);
  assert.match(source, /g_ai_pace\.ladder_override == 1/);
  assert.match(source, /APP_VERSION = build_config\.app_version orelse "0\.28\.\d+"/);
  assert.match(source, /\.ver = "0\.28\.687"[\s\S]{0,700}\.items = &\.\{/);
});
