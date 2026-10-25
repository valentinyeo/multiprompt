import assert from 'node:assert/strict';
import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tokenize } from './strip-comments.mjs';
import { checkRouting, readSources } from './check-routing-ids.mjs';

const read = file => fs.readFileSync(file, 'utf8');
const render = read('src/chat_render.zig');
const state = read('src/app_state.zig');
const palette = read('src/command_palette.zig');
const sidebar = read('src/sidebar.zig');
const main = read('src/main.zig');
const session = read('src/session.zig');
const snapshot = read('src/launch_snapshot.zig');
const cache = read('src/launch_cache.zig');
const body = name => {
  const start = render.search(new RegExp(`^(?:pub )?fn ${name}\\(`, 'm'));
  assert.ok(start >= 0, name);
  const rest = render.slice(start);
  return rest.slice(0, rest.indexOf('\n}\n') + 3);
};
const contains = (source, text) => assert.ok(source.includes(text), text);
const absent = (source, text) => assert.ok(!source.includes(text), text);
const scenes = ['sending', 'queued', 'waiting', 'not_sent', 'unconfirmed', 'retry', 'remove', 'shell_queue', 'injected_queue', 'model', 'context', 'todo_summary', 'todo_done', 'todo_working', 'todo_pending', 'todo_chevron', 'empty', 'missing', 'loading', 'failed', 'tool', 'tool_detail', 'tool_diff'];

switch (process.argv[2]) {
  case 'inventory': {
    const ledger = read('GATES.md');
    const inventory = ledger.slice(ledger.indexOf('## Inventory'));
    assert.equal([...inventory.matchAll(/^\d+\./gm)].length, 9);
    for (const text of ['✓✓ Read', 'Sending…', 'Queued in Claude', 'Waiting for connection', 'Delivery unconfirmed', 'Not sent', 'Send again', 'Remove', 'context left', 'done', 'chevron', 'todo', 'missing_message', 'retrying', 'Loading conversation...', 'No conversation yet', 'Tool', 'timestamp', 'separators', 'currently working']) contains(inventory, text);
    for (const name of ['chatPaintTime', 'chatPaintEchoStatus', 'chatPaintEcho', 'chatPaintShellRow', 'chatStatusWndProc', 'chatTranscriptWndProc']) {
      contains(inventory, name);
      contains(render, name);
    }
    console.log('INVENTORY VERIFIED');
    break;
  }
  case 'renderer': {
    contains(body('chatPaintTime'), 'if (!app_state.clean_chat and confirmed and block.role == .user)');
    for (const name of ['chatPaintEchoStatus', 'chatPaintShellRow', 'chatPaintStatus', 'chatPaintEmpty']) contains(body(name), 'if (app_state.clean_chat) return;');
    contains(body('chatPaintBlock'), 'if (app_state.clean_chat and block.role == .tool) return;');
    contains(body('chatPaintEcho'), 'if (!app_state.clean_chat and actions.send_again)');
    contains(body('chatMeasureEchoRect'), 'if (app_state.clean_chat) @as(i32, 0) else uiScaled(CHAT_STATUS_H)');
    contains(body('chatRelayout'), 'if (!app_state.clean_chat and chat_echo.pendingActions(e.state).send_again)');
    contains(body('chatStatusHeight'), 'if (app_state.clean_chat) return 0;');
    for (const name of ['chatEchoRetryAt', 'chatEchoRetryHover']) contains(body(name), 'if (app_state.clean_chat) return false;');
    contains(body('chatToggleClean'), 'app_state.g_chat_layout_reuse = 0;');
    contains(body('chatToggleClean'), 'app_state.g_chat_layout_dirty = true;');
    contains(body('chatToggleClean'), 'layoutChatControls();');
    contains(body('chatTranscriptWndProc'), 'chatPaintEmpty(mem_dc, w, message);');
    contains(body('chatStatusWndProc'), 'chatPaintStatus(hdc, status, rc, brush);');
    contains(body('chatTranscriptWndProc'), 'if (app_state.g_chat_blocks[i].role == .tool) continue;');
    for (const name of ['chatMeasureBlockRect', 'chatPaintBlockImages', 'chatImgDrawThumb', 'chatPaintAgentHeader']) absent(body(name), 'clean_chat');
    const shellPaint = body('chatPaintShellRow');
    assert.ok(shellPaint.indexOf('chatFlowText(hdc, text') < shellPaint.indexOf('if (app_state.clean_chat) return;'));
    contains(body('chatPaintEcho'), 'chatFlowText(hdc, e.text');
    absent(read('src/window_layout.zig'), 'clean_chat');
    contains(body('chatPaintBlock'), 'chatPaintTime(hdc, block, chatStatusRowRect(bubble)');
    console.log('RENDERER VERIFIED');
    break;
  }
  case 'setting': {
    contains(state, 'pub var clean_chat: bool = false;');
    contains(session, 'const setting = ",\\\"clean_chat\\\":true";');
    contains(session, 'app_state.clean_chat = json_reader.boolTrue(json, "clean_chat");');
    contains(snapshot, 'clean_chat: bool = false,');
    contains(cache, 'state.clean_chat = s.clean_chat;');
    contains(cache, '.clean_chat = state.clean_chat,');
    const id = Number(state.match(/pub const SEARCH_CLEAN_CHAT_OFFSET: usize = (\d+);/)[1]);
    const values = [...state.matchAll(/pub const (SEARCH_\w+): usize = (\d+);/g)];
    assert.equal(values.filter(([, , value]) => Number(value) === id).length, 1);
    const routing = checkRouting(readSources('.'), JSON.parse(read('tools/routing-id-bands.json')));
    assert.deepEqual(routing.errors, []);
    for (const source of [palette, sidebar, main]) contains(source, 'const SEARCH_CLEAN_CHAT_OFFSET = @import("app_state.zig").SEARCH_CLEAN_CHAT_OFFSET;');
    contains(palette, 'g_search_results[app_state.g_search_result_count] = SEARCH_CLEAN_CHAT_OFFSET;');
    contains(palette, '"chat view toggle CLEAN chat"');
    contains(palette, 'SEARCH_CLEAN_CHAT_OFFSET => "Chat View: Toggle CLEAN chat');
    contains(palette, 'SEARCH_CLEAN_CHAT_OFFSET, SEARCH_CHAT_AC_OFFSET,');
    contains(sidebar, 'is_clean_chat or is_chat_todo or is_chat_tools');
    contains(sidebar, 'Chat View: CLEAN chat: ON (toggle)');
    contains(sidebar, 'Chat View: CLEAN chat: OFF (toggle)');
    const handler = main.slice(main.indexOf('if (target == SEARCH_CLEAN_CHAT_OFFSET)'), main.indexOf('if (target == SEARCH_CHAT_TODO_OFFSET)'));
    contains(handler, 'chatToggleClean();');
    contains(handler, 'saveSession();');
    absent(read('src/shortcuts.zig'), 'CLEAN chat');
    absent(read('openwiki/operations/keyboard-shortcuts.md'), 'CLEAN chat');
    console.log('SETTING VERIFIED');
    break;
  }
  case 'coverage': {
    for (const scene of scenes) assert.match(render, new RegExp(`test "IGSH-816 CLEAN[^"\\n]+" \\{\\n    try expectCleanChatRowHidden\\(\\.${scene}\\);\\n\\}`));
    const oracle = body('expectCleanChatRowHidden');
    contains(oracle, 'expect(!std.mem.eql(u32, off, blank))');
    contains(oracle, 'expectEqualSlices(u32, blank, on)');
    contains(body('cleanChatPixels'), 'CreateDIBSection');
    contains(body('cleanChatPixels'), 'chatPaintStatus(dc, &status, area, brush);');
    contains(body('cleanChatPixels'), 'chatPaintEmpty(dc, width, switch (scene)');
    contains(render, 'CLEAN hides read ticks but preserves the timestamp and timezone pixels');
    contains(render, 'expectEqualSlices(u32, timestamp, on)');
    contains(render, 'CLEAN preserves message markdown code tables and attribution pixels');
    contains(render, 'CLEAN off-mode rendered rows are unchanged after toggling');
    contains(render, 'expectEqualSlices(u32, before, after)');
    contains(snapshot, 'CLEAN launch snapshot round trips both modes and legacy defaults off');
    assert.ok([...render.matchAll(/test "IGSH-816 CLEAN/g)].length >= scenes.length + 3);
    console.log('COVERAGE VERIFIED');
    break;
  }
  case 'scope': {
    assert.throws(() => absent('sentinel', 'sentinel'));
    const changed = execFileSync('git', ['diff', '--name-only'], { encoding: 'utf8' }).trim().split('\n');
    const allowed = ['GATES.md', '.claude/skills/verify-multiprompt/features/chat-messages-only.md', 'src/app_state.zig', 'src/chat_render.zig', 'src/command_palette.zig', 'src/sidebar.zig', 'src/main.zig', 'src/session.zig', 'src/launch_cache.zig', 'src/launch_snapshot.zig'];
    assert.deepEqual(changed.sort(), allowed.sort());
    const untracked = execFileSync('git', ['ls-files', '--others', '--exclude-standard'], { encoding: 'utf8' }).trim().split('\n').filter(file => file && file !== '.unlazy-hook-state.json');
    assert.deepEqual(untracked.sort(), ['changelog.d/IGSH-816-clean-chat.md', 'tools/check-clean-chat-static.mjs']);
    for (const file of [...changed.filter(file => file.endsWith('.zig')), 'tools/check-clean-chat-static.mjs']) {
      assert.equal(tokenize(read(file), file.endsWith('.zig') ? 'zig' : 'javascript').comments.length, 0, file);
    }
    const fragment = read('changelog.d/IGSH-816-clean-chat.md').trim();
    assert.equal(fragment.split('\n').length, 1);
    contains(fragment, 'CLEAN chat');
    const added = execFileSync('git', ['diff', '--unified=0', '--', 'src'], { encoding: 'utf8' }).split('\n').filter(line => line.startsWith('+') && !line.startsWith('+++')).join('\n');
    for (const forbidden of ['Sleep(', 'SetTimer(', 'Thread.spawn', 'pub const APP_VERSION', 'timeout']) absent(added, forbidden);
    console.log('SCOPE VERIFIED');
    break;
  }
  default: throw new Error('Choose inventory, renderer, setting, coverage, or scope');
}
