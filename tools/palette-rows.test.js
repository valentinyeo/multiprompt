const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const state = read('src/app_state.zig');
const palette = read('src/command_palette.zig');
const sidebar = read('src/sidebar.zig');
const main = read('src/main.zig');

function offsets(text) {
  return new Map([...text.matchAll(/pub const (SEARCH_\w+_OFFSET): usize = (\d+);/g)]
    .map(([, name, value]) => [name, Number(value)]));
}

function uniqueOffsets(values) {
  const names = new Map();
  for (const [name, value] of values) {
    names.set(value, [...(names.get(value) || []), name]);
  }
  const collisions = [...names].filter(([, group]) => group.length > 1);
  assert.equal(collisions.length, 0, collisions.map(([value, group]) =>
    `SEARCH offsets collide at ${value}: ${group.join(', ')}`).join('\n'));
}

function comparisons(text, variable, values) {
  const found = new Set();
  const comparison = new RegExp(`\\b${variable}\\s*(?:==|>=|<=|>|<)\\s*(SEARCH_\\w+_OFFSET)\\b`, 'g');
  for (const [, name] of text.matchAll(comparison)) found.add(name);
  const range = new RegExp(`\\b${variable}\\s*(>=|>)\\s*(SEARCH_\\w+_OFFSET)\\s+and\\s+${variable}\\s*(<=|<)\\s*(SEARCH_\\w+_OFFSET)\\b(?!\\s*\\+)`, 'g');
  for (const [, lowerOp, lower, upperOp, upper] of text.matchAll(range)) {
    for (const [name, value] of values) {
      if ((lowerOp === '>=' ? value >= values.get(lower) : value > values.get(lower)) &&
          (upperOp === '<=' ? value <= values.get(upper) : value < values.get(upper))) found.add(name);
    }
  }
  const switches = new RegExp(`switch\\s*\\(${variable}\\)\\s*\\{([^]*?)\\n\\s*\\}`, 'g');
  for (const [, body] of text.matchAll(switches)) {
    for (const [, names] of body.matchAll(/((?:SEARCH_\w+_OFFSET\s*(?:\.\.\.\s*SEARCH_\w+_OFFSET)?\s*,?\s*)+) =>/g)) {
      for (const name of names.match(/SEARCH_\w+_OFFSET/g)) found.add(name);
      const bounds = names.match(/(SEARCH_\w+_OFFSET)\s*\.\.\.\s*(SEARCH_\w+_OFFSET)/);
      if (bounds) {
        for (const [name, value] of values) {
          if (value >= values.get(bounds[1]) && value <= values.get(bounds[2])) found.add(name);
        }
      }
    }
  }
  return found;
}

function painted(text, values) {
  const start = text.indexOf('const result_idx = app_state.g_search_results[ri];');
  assert.notEqual(start, -1, 'palette paint loop');
  text = text.slice(start);
  const definitions = new Map([...text.matchAll(/const (is_\w+) = ([^;]+);/g)]
    .map(([, name, expression]) => [name, expression]));
  text = text.replace(/const is_\w+ = [^;]+;/g, '');
  const conditions = [...text.matchAll(/\bif\s*\(([^{};]+?)\)/g)].map(([, condition]) => condition);
  const reached = new Set();
  for (let i = 0; i < conditions.length; i++) {
    for (const [, name] of conditions[i].matchAll(/(?<!!)\b(is_\w+)\b/g)) {
      if (!reached.has(name) && definitions.has(name)) {
        reached.add(name);
        conditions.push(definitions.get(name));
      }
    }
  }
  const switches = [...text.matchAll(/switch\s*\(result_idx\)\s*\{[^]*?\n\s*\}/g)].map(([body]) => body);
  return comparisons([...conditions, ...switches].join('\n'), 'result_idx', values);
}

function checkRows(paletteText, paintText, confirmText, values) {
  const rows = new Set([...paletteText.matchAll(/\bg_search_results\[[^\]]+\]\s*=\s*(SEARCH_\w+_OFFSET)\s*;/g)]
    .map(([, name]) => name));
  assert.ok(rows.size > 0, 'palette rows were found');
  const paint = painted(paintText, values);
  const confirm = comparisons(confirmText, 'target', values);
  for (const name of rows) {
    assert.ok(values.has(name), `${name} must be declared in src/app_state.zig`);
    assert.ok(paint.has(name), `Ctrl+K row ${name} is added in src/command_palette.zig but never painted in src/sidebar.zig paint (it falls through to the shell-row branch and crashes, see b2cefed); add an is_x branch`);
    assert.ok(confirm.has(name), `Ctrl+K row ${name} is added in src/command_palette.zig but never handled in src/main.zig confirm; add a target comparison and handler`);
  }
}

const values = offsets(state);
const confirmStart = main.indexOf('WM_APP_SEARCH_CONFIRM => {');
assert.notEqual(confirmStart, -1, 'palette confirm message');
const confirm = main.slice(confirmStart, main.indexOf('\n        WM_', confirmStart + 1));

test('every SEARCH offset has a unique numeric value', () => {
  assert.ok(values.size > 0);
  uniqueOffsets(values);
  assert.throws(() => uniqueOffsets(offsets('pub const SEARCH_A_OFFSET: usize = 1;\npub const SEARCH_B_OFFSET: usize = 1;')),
    /SEARCH_A_OFFSET, SEARCH_B_OFFSET/);
});

test('every directly added Ctrl+K row is painted and confirmed', () => {
  checkRows(palette, sidebar, confirm, values);
});

test('imports and unused classifiers cannot hide missing paint or confirm branches', () => {
  const row = 'g_search_results[0] = SEARCH_VOICE_STOP_OFFSET;';
  const missingPaint = sidebar.replace('} else if (is_voice_stop) {', '} else if (false) {');
  assert.notEqual(missingPaint, sidebar);
  assert.throws(() => checkRows(row, missingPaint, confirm, values), /SEARCH_VOICE_STOP_OFFSET.*never painted/);
  assert.throws(() => checkRows(row, sidebar, 'const SEARCH_VOICE_STOP_OFFSET = @import("app_state.zig").SEARCH_VOICE_STOP_OFFSET;', values),
    /SEARCH_VOICE_STOP_OFFSET.*never handled/);
});

test('bounded comparisons and switch ranges cover intermediate row offsets', () => {
  const sample = new Map([['SEARCH_A_OFFSET', 1], ['SEARCH_B_OFFSET', 2], ['SEARCH_C_OFFSET', 3]]);
  assert.ok(comparisons('target >= SEARCH_A_OFFSET and target <= SEARCH_C_OFFSET', 'target', sample).has('SEARCH_B_OFFSET'));
  assert.ok(comparisons('switch (target) {\nSEARCH_A_OFFSET ... SEARCH_C_OFFSET => {},\n}', 'target', sample).has('SEARCH_B_OFFSET'));
  assert.ok(!comparisons('target >= SEARCH_A_OFFSET', 'target', sample).has('SEARCH_B_OFFSET'));
});
