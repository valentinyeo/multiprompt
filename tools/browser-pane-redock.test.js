const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const source = require('./app-source').readAppSource();

function functionBody(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, `${name} must exist`);
  const end = source.indexOf('\nfn ', start + 1);
  assert.notEqual(end, -1, `could not find the end of ${name}`);
  return source.slice(start, end);
}

function moduleSource(file) {
  const full = path.join(root, file);
  return fs.existsSync(full) ? fs.readFileSync(full, 'utf8') : '';
}

test('MUBO-232 a connected pane off its dock re-docks instead of showing Opening browser', () => {
  assert.match(source, /pub const BrowserPlaceholder = enum \{ none, opening, not_open, failed, redock \}/, 'the placeholder has a redock state');
  const paint = functionBody('paintBrowserPlaceholder');
  assert.match(paint, /state == \.redock/, 'a connected uncovered slot re-docks rather than painting Opening browser');
  assert.match(functionBody('currentBrowserPlaceholder'), /connected/, 'the placeholder decision knows whether the pane is connected');
  const redock = moduleSource('src/browser_pane_redock.zig');
  assert.match(redock, /fn browserPlaceholderPure/, 'the real placeholder decision lives in the redock module');
  assert.match(redock, /if \(connected\) return \.redock;/, 'a connected pane resolves to redock before the opening deadline');
  assert.match(redock, /fn activePaneNeedsRedock/, 'the redock path checks the pane really needs a reposition');
});

test('MUBO-232 a bound pane off the foreground still re-docks', () => {
  assert.match(functionBody('updateBrowserVisibility'), /browserVisibilityAllowsBackgroundRedock/, 'a bound pane is repositioned even when the app is not foreground');
  assert.match(moduleSource('src/browser_pane_redock.zig'), /fn browserVisibilityAllowsBackgroundRedock/, 'the background redock admission is a named decision');
});
