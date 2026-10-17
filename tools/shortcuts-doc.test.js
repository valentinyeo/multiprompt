const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { pathToFileURL } = require('node:url');
const root = path.resolve(__dirname, '..');
const generator = import(pathToFileURL(path.join(__dirname, 'shortcuts-doc.mjs')).href);
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function checkHints(sidebar, rows) {
  const keys = new Set([...sidebar.matchAll(/\bL\("((?:(?:Ctrl|Alt|Shift)\+[^"\s]+|F\d+))"\)/g)].map(([, key]) => key));
  assert.ok(keys.size > 0, 'sidebar shortcut hints were found');
  for (const key of keys) {
    const escaped = key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const chord = new RegExp(`(?<![\\w+])${escaped}(?![\\w+])`);
    assert.ok(rows.some(row => chord.test(row.a)), `Palette hint ${key} is missing from src/shortcuts.zig SHORTCUT_ROWS; add its F1 row`);
  }
}

test('keyboard shortcuts Full list is generated and current', () => {
  const result = spawnSync(process.execPath, [path.join(__dirname, 'shortcuts-doc.mjs'), '--check'], { cwd: root, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('every single-token sidebar shortcut hint appears in the F1 list', async () => {
  const { parseShortcutRows } = await generator;
  checkHints(read('src/sidebar.zig'), parseShortcutRows(read('src/shortcuts.zig')));
  assert.throws(() => checkHints('L("Ctrl+Missing")', [{ a: 'Ctrl+Other' }]), /Ctrl\+Missing.*src\/shortcuts.zig SHORTCUT_ROWS/);
  assert.throws(() => checkHints('L("Ctrl+Shift+S")', [{ a: 'Ctrl+Shift+Space' }]), /Ctrl\+Shift\+S.*SHORTCUT_ROWS/);
});

test('generator decodes Zig strings, groups rows and escapes table pipes', async () => {
  const { parseShortcutRows, renderShortcutRows } = await generator;
  const rows = parseShortcutRows(String.raw`pub const SHORTCUT_ROWS = [_]ShortcutRow{
    .{ .a = "Group", .b = "", .header = true },
    .{ .a = "Ctrl+|", .b = "Say \"hi\" \\ \u{2192} \x41 | <name>", .header = false },
};`);
  assert.deepEqual(rows, [
    { a: 'Group', b: '', header: true },
    { a: 'Ctrl+|', b: 'Say "hi" \\ → A | <name>', header: false },
  ]);
  const table = renderShortcutRows(rows);
  assert.match(table, /## Full list\n\n### Group\n\n\| Keys \| Action \|/);
  assert.ok(table.includes('| Ctrl+\\| | Say "hi" \\ → A \\| &lt;name&gt; |'));
  assert.throws(() => parseShortcutRows('pub const SHORTCUT_ROWS = [_]ShortcutRow{\n.{ .a = "lost" },\n};'), /Cannot parse every/);
});
