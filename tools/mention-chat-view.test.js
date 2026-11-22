const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(path.join(__dirname, "..", "src", "chat_mention.zig"), "utf8");

test("the @ list offers every chat view tab, not only live- sessions", () => {
  const body = source.slice(source.indexOf("pub fn currentLive"), source.indexOf("pub fn show"));
  assert.match(body, /isLive\(session\) or shell\.chat_view_on/);
});

test("the @ list test covers a chat with a non-live session name", () => {
  assert.match(source, /"Multi Bot Android", "multiprompt-android"/);
});
