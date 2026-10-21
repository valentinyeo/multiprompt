const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = process.argv[2];
const result = {};
for (const revision of ['before', 'after']) {
  const log = fs.readFileSync(path.join(root, revision, 'ZigShell/debug.log'), 'utf8');
  const builds = [...log.matchAll(/CHAT_TABLE_BUILD index=(\d+) us=(\d+) cells=9/g)];
  assert.equal(builds.length, 2000, `${revision} build count`);
  builds.forEach((build, index) => assert.equal(Number(build[1]), index));
  const us = builds.map(build => Number(build[2]));
  result[revision] = { builds: us.length, totalUs: us.reduce((a, b) => a + b, 0) };
  result[revision].msPerBuild = result[revision].totalUs / us.length / 1000;
}
assert.ok(result.after.msPerBuild <= 0.35, `table layout exceeds 0.35 ms/build: ${result.after.msPerBuild}`);
fs.writeFileSync(path.join(root, 'summary.json'), JSON.stringify(result, null, 2));
console.log(`TABLE BUILD COST VERIFIED ${JSON.stringify(result)}`);
