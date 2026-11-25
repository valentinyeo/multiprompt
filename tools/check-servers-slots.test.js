const test = require("node:test");
const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { resolve, join } = require("node:path");
const api = import("./check-servers-slots.mjs");
const root = resolve(__dirname, "..");

const server = extra => ({ id: "site-one", hostname: "site-one.example.invalid", ...extra });
const file = servers => JSON.stringify({ schema: 1, main_server: "site-one", servers });

test("a current servers file names a slot for every server", async () => {
  const { problemsIn } = await api;
  assert.deepEqual(problemsIn("tools/fixtures/servers.json", file([
    server({ multiprompt_slot: 0 }),
    server({ id: "site-two", hostname: "site-two.example.invalid", multiprompt_slot: 1 })
  ])), []);
});

test("a server without a slot, or with an impossible one, names the file and the field", async () => {
  const { problemsIn } = await api;
  for (const extra of [{}, { multiprompt_slot: 3 }, { multiprompt_slot: "1" }, { multiprompt_slot: 1.5 }, { multiprompt_slot: true }]) {
    const problems = problemsIn("tools/fixtures/servers.json", file([server(extra)]));
    assert.equal(problems.length, 1, JSON.stringify(extra));
    assert.match(problems[0], /tools\/fixtures\/servers\.json/);
    assert.match(problems[0], /multiprompt_slot/);
  }
});

test("a server needs an id and a hostname to be matched at all", async () => {
  const { problemsIn } = await api;
  for (const broken of [{ id: "", hostname: "site-one.example.invalid" }, { id: "site-one" }, { id: "site-one", hostname: 7 }]) {
    const problems = problemsIn("tools/fixtures/servers.json", file([{ ...broken, multiprompt_slot: 0 }]));
    assert.equal(problems.length, 1, JSON.stringify(broken));
    assert.match(problems[0], /"id"|"hostname"/);
  }
});

test("an unreadable or empty servers file is refused", async () => {
  const { problemsIn } = await api;
  assert.match(problemsIn("tools/fixtures/servers.json", "not json")[0], /not JSON/);
  assert.match(problemsIn("tools/fixtures/servers.json", JSON.stringify({ servers: [] }))[0], /non-empty/);
  assert.match(problemsIn("tools/fixtures/servers.json", JSON.stringify({ schema: 1 }))[0], /non-empty/);
});

test("the snapshots of older servers files may omit the slot", async () => {
  const { problemsIn, OLD_SHAPE_FILES } = await api;
  for (const name of OLD_SHAPE_FILES) {
    assert.deepEqual(problemsIn(name, file([server()])), []);
    assert.equal(problemsIn("tools/fixtures/new-install.json", file([server()])).length, 1);
  }
});

test("every servers file in the repo passes the check", async () => {
  const { problemsIn, serversFileNames, OLD_SHAPE_FILES } = await api;
  const names = serversFileNames();
  assert.ok(names.length >= 2, names.join(", "));
  for (const name of OLD_SHAPE_FILES) assert.ok(names.includes(name), name);
  for (const name of names) assert.deepEqual(problemsIn(name, readFileSync(join(root, name), "utf8")), [], name);
});
