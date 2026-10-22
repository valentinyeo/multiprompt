const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const srcDir = path.join(__dirname, "..", "src");

function zigFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return zigFiles(full);
    return entry.name.endsWith(".zig") ? [full] : [];
  });
}

function functionBody(text, name) {
  const start = text.indexOf(`fn ${name}(`);
  assert.notStrictEqual(start, -1, `${name} is missing`);
  const next = text.slice(start + 1).search(/\n(?:pub )?fn /);
  return next === -1 ? text.slice(start) : text.slice(start, start + 1 + next);
}

test("IGSH-540: no src file reads DEEPGRAM_API_KEY from the inherited process environment", () => {
  const offenders = [];
  for (const file of zigFiles(srcDir)) {
    const text = fs.readFileSync(file, "utf8");
    const patterns = [
      /GetEnvironmentVariable[AW]?\s*\(\s*(?:L\()?\s*"DEEPGRAM_API_KEY"/,
      /std\.process\.[\w.]*\([^)]*"DEEPGRAM_API_KEY"/,
      /(?:getEnvVar\w*|getAlloc|getPosix|get)\s*\([^)]*"DEEPGRAM_API_KEY"/,
    ];
    for (const pattern of patterns) {
      if (pattern.test(text)) offenders.push(`${path.relative(srcDir, file)} ${pattern}`);
    }
  }
  assert.deepStrictEqual(offenders, []);
});

test("IGSH-540: readDeepgramApiKey reads only the saved user variable", () => {
  const voice = fs.readFileSync(path.join(srcDir, "voice.zig"), "utf8");
  const body = functionBody(voice, "readDeepgramApiKey");
  assert.match(body, /readUserEnvRegistryAscii\("DEEPGRAM_API_KEY"/);
  assert.doesNotMatch(body, /GetEnvironmentVariable/);
});

test("IGSH-540: DEEPGRAM_API_KEY is only named by readDeepgramApiKey", () => {
  for (const file of zigFiles(srcDir)) {
    const text = fs.readFileSync(file, "utf8");
    const reads = [...text.matchAll(/\("DEEPGRAM_API_KEY"/g)].length;
    if (path.basename(file) === "voice.zig") {
      assert.strictEqual(reads, 1, "voice.zig must read DEEPGRAM_API_KEY in one place");
      assert.match(functionBody(text, "readDeepgramApiKey"), /\("DEEPGRAM_API_KEY"/);
    } else {
      assert.strictEqual(reads, 0, `${path.relative(srcDir, file)} reads DEEPGRAM_API_KEY directly`);
    }
  }
});

test("IGSH-540: launch logs the key source without the value", () => {
  const voice = fs.readFileSync(path.join(srcDir, "voice.zig"), "utf8");
  const log = functionBody(voice, "logDeepgramKeySource");
  assert.match(log, /\[voice\] deepgram key source=registry/);
  assert.match(log, /\[voice\] deepgram key source=none/);
  assert.doesNotMatch(log, /\{s\}|\{d\}|key_buf\[|\.len/);
  const main = fs.readFileSync(path.join(srcDir, "main.zig"), "utf8");
  assert.match(functionBody(main, "main"), /logDeepgramKeySource\(\)/);
});
