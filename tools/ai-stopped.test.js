const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = require('./app-source').readAppSource();
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} is missing`);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('IGSH-2283 the tmux poll records when a pane shows a bare shell', () => {
  assert.match(source, /pane_shell: bool = false/);
  assert.match(source, /entry\.pane_shell = nf >= 5 and paneCommandIsShell\(fields\[4\]\)/);
  assert.match(source, /\\"pane_shell\\":\{s\}/);
  assert.match(source, /entry\.pane_shell = vpsPollCacheJsonBool\(o\.get\("pane_shell"\)\)/);
  const shell = body('paneCommandIsShell');
  for (const name of ['bash', 'zsh', 'sh', 'dash', 'fish', 'ksh']) assert.ok(shell.includes(`"${name}"`), name);
});

test('IGSH-2283 the stopped state is set from the existing poll sync and starts no timer', () => {
  const sync = body('syncLiveTmuxMetadataFromCache');
  assert.match(sync, /aiStoppedAfterPoll\(/);
  assert.match(sync, /\.ai_stopped = step\.stopped/);
  assert.match(sync, /chatEchoResendHeldForShell\(/);
  assert.doesNotMatch(body('aiStoppedAfterPoll'), /SetTimer|Thread\.spawn/);
  assert.match(source, /const AI_RESTART_GRACE_MS: u64 = 45_000/);
});

test('IGSH-2283 a stopped chat says so and offers Restart on the title and in the held message label', () => {
  assert.match(body('chatTitleMetaText'), /ai_stopped\) return std\.mem\.span\(L\("AI stopped\. Click to restart"\)\)/);
  assert.match(body('chatTitleMetaText'), /ai_restart_tick != 0\) return std\.mem\.span\(L\("Restarting the AI"\)\)/);
  assert.match(body('chatTitleRestartHit'), /ai_stopped/);
  assert.match(source, /if \(chatTitleRestartHit\(mx, my\)\) \{\s*_ = @import\("chat_send\.zig"\)\.chatRestartAi\((?:app_state\.)?active_shell\);/);
  assert.match(source, /ai_stopped\) L\("AI stopped"\) else L\("Not sent"\)/);
});

test('IGSH-2283 restart goes through the host and then resends the held messages', () => {
  const restart = body('chatRestartAi');
  assert.match(restart, /!shell\.ai_stopped or shell\.ai_agent != 1/);
  assert.match(restart, /ai_restart_tick = @max\(GetTickCount64\(\), 1\)/);
  const thread = body('chatRestartAiThread');
  assert.match(thread, /\.op = "restart_ai"/);
  assert.match(thread, /\\trestart_ai\\tok\\t/);
  const resend = body('chatEchoResendHeldForShell');
  assert.match(resend, /showsNotSent\(/);
  assert.match(resend, /chatEchoSendAgain\(id\)/);
  const reader = read('src/chat_history_reader.py');
  assert.match(reader, /op"\) == "restart_ai"/);
  assert.match(reader, /def restart_ai_command\(/);
});

test('IGSH-2283 restart ships as a palette row and a shortcut row', () => {
  assert.match(read('src/app_state.zig'), /pub const SEARCH_TABCTX_CHAT_RESTART_AI: usize = 7199;/);
  const palette = read('src/command_palette.zig');
  assert.match(palette, /g_search_results\[app_state\.g_search_result_count\] = SEARCH_TABCTX_CHAT_RESTART_AI/);
  assert.match(palette, /shells\[tc_idx\.\?\]\.ai_stopped/);
  assert.match(read('src/sidebar.zig'), /result_idx == SEARCH_TABCTX_CHAT_RESTART_AI\) L\(ui_words\.tab_context_chat_restart_ai\)/);
  assert.match(read('src/ui_words.zon'), /\.tab_context_chat_restart_ai = "Chat View: Restart the AI"/);
  assert.match(read('src/main.zig'), /target == SEARCH_TABCTX_CHAT_RESTART_AI\) \{\s*_ = @import\("chat_send\.zig"\)\.chatRestartAi\(ti\)/);
  assert.match(read('src/shortcuts.zig'), /Chat View: Restart the AI/);
  assert.match(read('openwiki/operations/keyboard-shortcuts.md'), /Chat View: Restart the AI/);
});
