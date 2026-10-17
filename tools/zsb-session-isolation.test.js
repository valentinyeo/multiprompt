const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const wrapper = fs.readFileSync(path.join(root, "tools", "vps-multiprompt-browser.sh"), "utf8");
const source = require('./app-source').readAppSource();

function functionBody(name, nextName) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const end = source.indexOf(`fn ${nextName}(`, start);
  assert.notEqual(end, -1, `${nextName} must follow ${name}`);
  return source.slice(start, end);
}

test("headless VPS workers cannot borrow tmux's ambient current session", () => {
  const identityStart = wrapper.indexOf("fallback_sess=\"${ZSB_SESSION:-}\"");
  const identityEnd = wrapper.indexOf("\nsend_zsb()", identityStart);
  assert.notEqual(identityStart, -1);
  assert.notEqual(identityEnd, -1);
  const identity = wrapper.slice(identityStart, identityEnd);

  assert.match(identity, /if \[ -n "\$\{TMUX:-\}" \]; then[\s\S]*?tmux display-message -p '#S'/,
    "tmux lookup must require proof that the caller is inside tmux");
  assert.equal((identity.match(/tmux display-message/g) || []).length, 1,
    "the wrapper must not retry an unscoped tmux lookup for headless callers");
  assert.match(identity, /if \[ -z "\$sess" \]; then\s+json_error "no_session"/,
    "a caller with neither TMUX nor ZSB_SESSION must fail closed");
  assert.doesNotMatch(identity, /sess="\$\{sess\}\|\$\{fallback_sess\}"/,
    "a live tmux identity must not carry a restart-stale zss fallback");
});

test("the Windows resolver ignores every token after the primary session identity", () => {
  const primary = functionBody("zsbPrimarySessionToken", "webView2SessionFilePathA");
  assert.match(primary, /c == '\\|' or c == ',' or c == ';'/);

  for (const [name, next] of [
    ["zsbFindPaneWindowIdSilent", "zsbPollPaneWindowIdSilent"],
    ["zsbResolvePaneWindowId", "zsbReadPipeBytes"],
    ["findZsbPaneTarget", "trimLeftTitleWhitespaceU8"],
  ]) {
    const body = functionBody(name, next);
    assert.match(body, /zsbPrimarySessionToken\(session\)/,
      `${name} must resolve only the primary identity`);
    assert.doesNotMatch(body, /tokenizeAny\(u8, session, "\|,;"\)/,
      `${name} must not fall through to a stale secondary identity`);
  }
});
