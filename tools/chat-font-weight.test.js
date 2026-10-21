const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');

function bodyRequests(source) {
  return [...source.matchAll(/(?:\bCreateFontW|@import\("fonts\.zig"\)\.create)\([^;]+;/g)]
    .map(match => match[0].split(' else ')[0])
    .filter(call => !call.includes('MONO_FACE'));
}

test('shipped chat body is 400 and strictly lighter than bold 700', () => {
  const fonts = read('src/fonts.zig');
  const body = Number(fonts.match(/body_weight: i32 = (\d+)/)[1]);
  const bold = Number(fonts.match(/bold_weight: i32 = (\d+)/)[1]);
  assert.equal(body, 400);
  assert.equal(bold, 700);
  assert.ok(body < bold);
  assert.match(fonts, /CHAT_QUALITY: w\.DWORD = 4;/);
  assert.match(fonts, /if \(bold\) options\.bold_weight else options\.body_weight/);
});

test('all Chat View prose font requests use shipped shared defaults, never direct Medium', () => {
  for (const name of fs.readdirSync(path.join(__dirname, '../src')).filter(name => /^chat.*\.zig$/.test(name))) {
    const source = read(`src/${name}`);
    assert.deepEqual(bodyRequests(source), [], name);
    for (const call of source.matchAll(/@import\("fonts\.zig"\)\.chat\([^;]+;/g)) {
      assert.match(call[0], /, \.\{\}\)/, name);
    }
  }
  assert.match(read('src/chat_composer.zig'), /\.chat\(-uiScaled\(app_state\.g_chat_font_pt\), false, false, false, \.\{\}\)/);
  const render = read('src/chat_render.zig');
  assert.match(render, /false, false, true, \.\{\}\)/);
  assert.match(render, /style\.bold or level > 0, style\.italic, false, \.\{\}\)/);
  assert.match(render, /g_chat_font_pt - 3\)\), false, false, false, \.\{\}\)/);
});

test('body request guard catches direct 500 and conditional 500 but allows unchanged mono', () => {
  const medium = 'CreateFontW(-uiScaled(size), 0, 0, 0, 500, 0, 0, 0, 0, 0, 0, CHAT_QUALITY, 0, L(UI_MEDIUM_FACE));';
  assert.equal(bodyRequests(medium).length, 1);
  assert.equal(bodyRequests(medium.replace('500,', 'if (bold) 700 else 500,')).length, 1);
  assert.equal(bodyRequests(medium.replace('UI_MEDIUM_FACE', 'MONO_FACE')).length, 0);
});
