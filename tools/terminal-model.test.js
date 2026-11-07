const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');
const root = path.resolve(__dirname, '..');

const fixture = String.raw`
#include "terminal_model.h"
#include "vterm_keycodes.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
static char output[4096];
static size_t used;
static void capture(const char *data, size_t length, void *user) {
    (void)user;
    assert(used + length < sizeof(output));
    memcpy(output + used, data, length);
    used += length;
    output[used] = 0;
}
static void feed(MPTerminal *t, const char *text) { mp_terminal_feed(t, text, strlen(text)); }
int main(void) {
    assert(!mp_terminal_new(0, 80, capture, NULL));
    MPTerminal *t = mp_terminal_new(4, 30, capture, NULL);
    assert(t);
    MPTerminalCell cell;
    feed(t, "\033[2J\033[Habc\033[2;5HZ");
    assert(mp_terminal_cell(t, 1, 4, 0, &cell) && cell.chars[0] == 'Z');
    feed(t, "\033[38;2;17;34;51m\033[48;2;68;85;102m\033[1;3;4mX");
    assert(mp_terminal_cell(t, 1, 5, 0, &cell));
    assert(cell.foreground == 0x332211 && cell.background == 0x665544 && cell.attributes == 7);
    feed(t, "\033[0m\033[H");
    mp_terminal_feed(t, "\xe9", 1);
    mp_terminal_feed(t, "\x9b\xaa", 2);
    assert(mp_terminal_cell(t, 0, 0, 0, &cell) && cell.chars[0] == 0x96ea && cell.width == 2);
    feed(t, "\033[?1049h\033[HALT\033[?1049l");
    assert(mp_terminal_cell(t, 0, 0, 0, &cell) && cell.chars[0] == 0x96ea);
    used = 0;
    feed(t, "\033[?1h");
    mp_terminal_key(t, VTERM_KEY_UP, VTERM_MOD_NONE);
    assert(!strcmp(output, "\033OA"));
    used = 0;
    feed(t, "\033[?1l");
    mp_terminal_key(t, VTERM_KEY_UP, VTERM_MOD_NONE);
    assert(!strcmp(output, "\033[A"));
    used = 0;
    feed(t, "\033[?2004h");
    mp_terminal_paste(t, 1);
    mp_terminal_char(t, 0x96ea, 0);
    mp_terminal_paste(t, 0);
    assert(!strcmp(output, "\033[200~\xe9\x9b\xaa\033[201~"));
    used = 0;
    feed(t, "\033[?1000h\033[?1006h");
    assert(mp_terminal_mouse_mode(t));
    mp_terminal_mouse(t, 2, 3, 1, 1, 0);
    assert(strstr(output, "\033[<0;4;3M"));
    mp_terminal_size(t, 8, 40);
    feed(t, "\033[8;40HY");
    assert(mp_terminal_cell(t, 7, 39, 0, &cell) && cell.chars[0] == 'Y');
    mp_terminal_free(t);
    t = mp_terminal_new(3, 20, capture, NULL);
    feed(t, "one\r\ntwo\r\nthree\r\nfour");
    assert(mp_terminal_history(t) >= 1);
    assert(mp_terminal_cell(t, 0, 0, 1, &cell) && cell.chars[0] == 'o');
    mp_terminal_free(t);
    MPTerminal *sessions[30];
    for (int i = 0; i < 30; i++) {
        sessions[i] = mp_terminal_new(24, 80, capture, NULL);
        assert(sessions[i]);
        feed(sessions[i], "independent session");
    }
    for (int i = 0; i < 30; i++) mp_terminal_free(sessions[i]);
    puts("TERMINAL_MODEL_PASS");
    return 0;
}
`;

test('terminal model preserves ANSI, true color, Unicode, alternate screen, input, scrollback and 30 lifetimes', () => {
  assert.ok(fs.existsSync(path.join(root, 'src/terminal_model.c')), 'native terminal model exists');
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-terminal-model-'));
  try {
    const file = path.join(folder, 'model.c');
    const exe = path.join(folder, process.platform === 'win32' ? 'model.exe' : 'model');
    fs.writeFileSync(file, fixture);
    const vendor = path.join(root, 'src/terminal/vendor/libvterm');
    const sources = fs.readdirSync(path.join(vendor, 'src')).filter((name) => name.endsWith('.c')).map((name) => path.join(vendor, 'src', name));
    const built = spawnSync(process.env.ZIG || 'zig', ['cc', '-std=c99', '-I' + path.join(root, 'src'), '-I' + path.join(vendor, 'include'), path.join(root, 'src/terminal_model.c'), ...sources, file, '-o', exe], { encoding: 'utf8', timeout: 60000 });
    assert.equal(built.status, 0, JSON.stringify({ signal: built.signal, error: built.error?.message, stdout: built.stdout, stderr: built.stderr }));
    const ran = spawnSync(exe, [], { encoding: 'utf8', timeout: 15000 });
    assert.equal(ran.status, 0, ran.stdout + ran.stderr);
    assert.match(ran.stdout, /TERMINAL_MODEL_PASS/);
  } finally {
    fs.rmSync(folder, { recursive: true, force: true });
  }
});
