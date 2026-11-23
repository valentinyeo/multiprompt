const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');

const palette = readFileSync('src/command_palette.zig', 'utf8');
const sidebar = readFileSync('src/sidebar.zig', 'utf8');

function functionBody(source, name, nextName) {
  const start = source.indexOf(`fn ${name}(`);
  const end = source.indexOf(`\nfn ${nextName}(`, start);
  assert.notStrictEqual(start, -1, `${name} is missing`);
  assert.notStrictEqual(end, -1, `could not isolate ${name}`);
  return source.slice(start, end);
}

test('SOFT-3075 the folder name is the first column and never yields to the path', () => {
  const columns = functionBody(palette, 'pickRepoColumns', 'appendJsonEscaped');
  assert.match(columns, /const host_right = overlay_right - PICK_REPO_SCROLL_GUTTER;/,
    'the host column must stop short of the palette scrollbar');
  assert.match(columns, /const path_right = host_left - PICK_REPO_COLUMN_GAP;/,
    'the path must not run into the host column');
  assert.match(columns, /const name_right = @min\(text_left \+ @max\(name_w, 0\), path_right\);/,
    'the folder name keeps every pixel it needs before the path is drawn');
  assert.match(columns, /const path_left = if \(name_right \+ PICK_REPO_COLUMN_GAP <= path_right\) name_right \+ PICK_REPO_COLUMN_GAP else path_right;/,
    'a long folder name collapses the path instead of the other way round');
  assert.match(columns, /std\.math\.clamp\(host_w, PICK_REPO_HOST_MIN_W, PICK_REPO_HOST_MAX_W\)/,
    'the host column is measured, not a fixed guess');
});

test('SOFT-3075 pick repo rows draw the name, path and host from the shared columns', () => {
  assert.match(palette, /pub fn pickRepoFolderName\(path: \[\]const u8\) \[\]const u8 \{/,
    'the row needs the folder name from the end of the path');
  assert.match(sidebar, /const name = pickRepoFolderName\(row\.path\[0\.\.row\.path_len\]\);/,
    'the sidebar must draw the folder name, not the whole path, as the row title');
  assert.match(sidebar, /const columns = pickRepoColumns\(text_left, ox \+ overlay_w, name_w, host_w\);/,
    'the sidebar must lay the row out through the shared columns');
  assert.match(sidebar, /\.right = columns\.name_right/);
  assert.match(sidebar, /\.left = columns\.path_left/);
  assert.match(sidebar, /\.left = columns\.host_left, \.top = ry, \.right = columns\.host_right/,
    'the host must be drawn inside its own column');
  assert.doesNotMatch(sidebar, /const host_rc = RECT\{ \.left = ox \+ overlay_w - 175/,
    'the host must not be drawn against the overlay edge where the scrollbar sits');
  assert.doesNotMatch(sidebar, /drawAscii\(hdc, row\.path\[0\.\.row\.path_len\], &pr_rc, DT_SINGLELINE \| DT_VCENTER \| DT_NOPREFIX \| DT_END_ELLIPSIS\);/,
    'the raw path must not stay the row title');
});

test('SOFT-3075 the row gutter is wider than the palette scrollbar', () => {
  const gutter = palette.match(/pub const PICK_REPO_SCROLL_GUTTER: i32 = (\d+);/);
  assert.ok(gutter, 'the shared gutter constant is missing');
  const thumb = sidebar.match(/RECT\{ \.left = ox \+ overlay_w - (\d+), \.top = thumb_top, \.right = ox \+ overlay_w - (\d+)/);
  assert.ok(thumb, 'could not find the palette scrollbar thumb');
  assert.ok(Number(gutter[1]) > Number(thumb[1]),
    'row content must stop before the scrollbar starts');
});
