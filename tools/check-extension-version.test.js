const test = require("node:test");
const assert = require("node:assert/strict");
const { execFileSync, spawnSync } = require("node:child_process");
const { mkdtempSync, mkdirSync, writeFileSync, copyFileSync, rmSync } = require("node:fs");
const { tmpdir } = require("node:os");
const { resolve, join } = require("node:path");
const api = import("./check-extension-version.mjs");
const root = resolve(__dirname, "..");
const script = join(root, "tools/check-extension-version.mjs");

function expectStatus(result, status) {
  assert.equal(result.status, status, result.stdout + result.stderr);
}

test("parseVersion accepts numeric triples and rejects malformed or unsafe versions", async () => {
  const { parseVersion } = await api;
  assert.deepEqual(parseVersion("1.10.65"), [1, 10, 65]);
  assert.deepEqual(parseVersion("0.0.0"), [0, 0, 0]);
  for (const value of [null, 123, "1.0", [1, 0, 0, 0].join("."), "v1.0.0", "1.0.-1", "1.0.0-beta", "1.0.0\n", "9007199254740992.0.0"]) {
    assert.throws(() => parseVersion(value), /Invalid/);
  }
});

test("compareVersions compares major, minor and patch numerically", async () => {
  const { compareVersions } = await api;
  for (const [higher, lower] of [["2.0.0", "1.99.99"], ["1.10.0", "1.9.99"], ["1.0.10", "1.0.9"]]) {
    assert.equal(compareVersions(higher, lower), 1);
    assert.equal(compareVersions(lower, higher), -1);
  }
  assert.equal(compareVersions("1.0.65", "1.0.65"), 0);
  assert.throws(() => compareVersions("bad", "1.0.0"), /Invalid/);
});

test("isShippedFile includes extension assets but excludes only .test.js files", async () => {
  const { isShippedFile } = await api;
  for (const path of ["extension/bridge.js", "extension/manifest.json", "extension/icons/icon16.png", "extension/nested/script.js", "extension/test.js"]) {
    assert.equal(isShippedFile(path), true, path);
  }
  for (const path of ["", "extension/bridge.test.js", "extension/nested/bridge.test.js", "tools/test.js", "extension-other/bridge.js"]) {
    assert.equal(isShippedFile(path), false, path);
  }
});

test("CLI uses merge-base, defaults to HEAD and checks committed additions, deletions and renames", (t) => {
  const dir = mkdtempSync(join(tmpdir(), "extension-version-"));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  mkdirSync(join(dir, "tools"));
  mkdirSync(join(dir, "extension"));
  copyFileSync(script, join(dir, "tools/check-extension-version.mjs"));
  const git = (...args) => execFileSync("git", args, { cwd: dir, encoding: "utf8" }).trim();
  const write = (path, content) => writeFileSync(join(dir, path), content);
  const manifest = (version) => write("extension/manifest.json", JSON.stringify({ version }));
  const commit = (message) => { git("add", "."); git("commit", "-qm", message); return git("rev-parse", "HEAD"); };
  const run = (...args) => spawnSync(process.execPath, [join(dir, "tools/check-extension-version.mjs"), ...args], { cwd: dir, encoding: "utf8" });
  git("init", "-q");
  git("config", "user.name", "Version checker test");
  git("config", "user.email", "test@example.invalid");
  git("config", "commit.gpgsign", "false");
  manifest("1.0.9");
  write("extension/bridge.js", "original");
  const base = commit("base");
  manifest("2.0.0");
  const baseTip = commit("base advances independently");
  git("checkout", "-q", "--detach", base);
  write("extension/bridge.test.js", "test only");
  commit("test only");
  const testsOnly = run(baseTip);
  expectStatus(testsOnly, 0);
  assert.equal(testsOnly.stdout.trim(), "extension unchanged");
  write("extension/icon.png", "asset");
  const unchanged = commit("asset without bump");
  const noBump = run(baseTip);
  expectStatus(noBump, 1);
  assert.match(noBump.stderr, /extension\/icon\.png/);
  assert.match(noBump.stderr, /bump "version" in extension\/manifest\.json/);
  manifest("1.0.10");
  const bumped = commit("numeric patch bump");
  const increased = run(baseTip);
  expectStatus(increased, 0);
  assert.match(increased.stdout, /1\.0\.9 -> 1\.0\.10/);
  manifest("0.9.99");
  const lower = commit("version decrease");
  expectStatus(run(baseTip), 1);
  expectStatus(run(baseTip, bumped), 0);
  expectStatus(run(base, unchanged), 1);
  expectStatus(run(base, lower), 1);
  git("mv", "extension/bridge.js", "extension/bridge-renamed.test.js");
  manifest("1.0.9");
  const renamed = commit("shipped code renamed to test");
  const result = run(base, renamed);
  expectStatus(result, 1);
  assert.match(result.stderr, /extension\/bridge\.js/);
  write("extension/manifest.json", "uncommitted invalid JSON");
  expectStatus(run(baseTip, bumped), 0);
  expectStatus(run(), 1);
  expectStatus(run("not-a-real-ref"), 1);
});
