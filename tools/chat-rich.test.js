const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const src = require('./app-source').readAppSource();
const build = fs.readFileSync('build.zig', 'utf8');
const docs = fs.readFileSync('openwiki/operations/keyboard-shortcuts.md', 'utf8');
function body(name) {
  const start = src.indexOf(`fn ${name}(`);
  assert.notEqual(start, -1, name);
  const end = src.indexOf('\nfn ', start + 1);
  return src.slice(start, end < 0 ? src.length : end);
}

test('conversation IO is off the UI thread and independent of the autocomplete channel', () => {
  assert.match(body('chatFileRequestForDelivery'), /std\.Thread\.spawn\([^]*chatFileFetchThread/);
  assert.match(body('chatFileFetchThread'), /chatHistoryFetch\(key/);
  assert.match(body('chatFileFetchThread'), /ready\.store\(true, \.release\)/);
  assert.match(body('chatFileOnReady'), /ready\.swap\(false, \.acq_rel\)/);
  assert.doesNotMatch(body('chatFileOnReady'), /fetchAcPersistent|sshOneShotCapture|Sleep\(/);
});
test('stable session identity gates results, backoff and local console fallback remain available', () => {
  assert.match(body('chatFileIdentity'), /chatFileIdentityForShell\(active_shell\)/);
  assert.match(body('chatFileIdentityForShell'), /key\.tmux/);
  assert.match(body('chatFileOnReady'), /sameSession\(key, entry\.key\)/);
  assert.match(body('refreshChatBlockCache'), /captureChatTranscript\(active_shell, &g_chat_screen, false\)/);
  assert.match(body('refreshChatBlockCache'), /chatHistoryEntry\(key\)/);
  assert.match(body('refreshChatBlockCache'), /chatClassifyBlocks/);
  assert.match(body('chatFileFailed'), /retryDelay/);
  assert.match(body('chatFileOnReady'), /refreshChatTranscript\(false\)/);
});
test('markdown measurement paint and link hit test share the same layout', () => {
  for (const name of ['chatMeasureBlockRect', 'chatPaintBlock', 'chatTranscriptLinkAt']) {
    assert.match(body(name), /chatFlowBlock/);
  }
  assert.match(body('chatTableLayout'), /g_chat_tables\.layout/);
  assert.match(body('chatFlowBlock'), /block\.kind == \.list/);
  assert.match(body('chatRichText'), /chat_markdown\.inlineSpans/);
  assert.match(body('chatRichFont'), /uiScaled\(g_chat_font_pt \+ extra\)/);
  assert.match(body('chatRichText'), /g_light_theme/);
  assert.match(body('resetFontCache'), /g_chat_rich_fonts/);
});
test('role paint and hit testing reserve the same avatar header, with real times only', () => {
  assert.match(body('chatMeasureBlockRect'), /chat_style\.headerHeight/);
  assert.match(body('chatMeasureBlockRect'), /chat_style\.bubbleWidth/);
  assert.match(body('chatPaintBlock'), /chatPaintAgentHeader/);
  assert.match(body('chatPaintBlock'), /chatPaintTime/);
  assert.match(body('chatTranscriptLinkAt'), /chat_style\.headerHeight/);
  assert.match(body('refreshChatBlockCache'), /chat_style\.markScreenMessages/);
  assert.match(body('chatUserBubbleColor'), /chat_style\.bubbleColors/);
  assert.match(body('chatRelayout'), /chat_style\.bubblePositions/);
  assert.match(body('chatPaintBlock'), /fillBubbleAA/);
  assert.match(body('chatTranscriptCharAt'), /chat_style\.topInset/);
  assert.match(body('chatPaintTime'), /if \(block.time\[0\] == 0 and block.role != \.injected\) return/);
  assert.match(docs, /Chat View message styles/);
});
test('pure parser tests are wired and existing Alt+C discovers automatic formatting', () => {
  for (const path of ['src/chat_markdown.zig', 'src/chat_transcript.zig']) assert.ok(build.includes(path));
  assert.match(docs, /Chat View formatting: Alt\+C/);
  assert.match(src, /\.ticket = ""/);
});

test('copy has button, keyboard, native-control fallback, palette label/results/draw/click and documentation', () => {
  assert.match(src, /SEARCH_CHAT_COPY_CODE_OFFSET: usize = 6362/);
  assert.match(src, /SEARCH_CHAT_COPY_CODE_OFFSET => "chat view copy latest code block/);
  assert.match(src, /g_search_results\[g_search_result_count\] = SEARCH_CHAT_COPY_CODE_OFFSET/);
  assert.match(src, /else if \(is_chat_copy\)/);
  assert.match(src, /if \(target == SEARCH_CHAT_COPY_CODE_OFFSET\)/);
  assert.match(src, /\.a = "Ctrl\+Shift\+D in Chat View"/);
  assert.match(docs, /Ctrl\+Shift\+D in Chat View/);
  assert.match(body('keyboardHookProc'), /chat_code\.copyKey/);
  assert.match(body('chatComposerSubclassCore'), /chatCopyCodeKeyDown/);
  assert.match(body('chatTranscriptWndProc'), /chatCopyCodeKeyDown/);
  assert.match(body('chatTranscriptWndProc'), /chatTranscriptCopyAt[\s\S]*chatCopyBlockToClipboard\(index\)/);
  assert.match(body('chatTranscriptCopyAt'), /chat_code\.copyButton/);
  assert.match(body('chatPaintCodeHeader'), /chat_code\.copyButton/);
  assert.match(body('chatTranscriptLinkAt'), /CHAT_CODE_PAD \+ CHAT_CODE_HEADER/);
  assert.match(body('chatFlowText'), /chat_code\.Iterator/);
  assert.match(body('chatFlowText'), /chatCodeTokenColor/);
  assert.match(build, /src\/chat_code\.zig/);
});

test('copy palette offset is exclusive in the complete draw classification chain', () => {
  const constants = {};
  for (const m of src.matchAll(/^const (\w+)(?:: [\w.]+)? = (\d+);/gm)) constants[m[1]] = Number(m[2]);
  const start = src.indexOf('const is_skills_menu = result_idx');
  const end = src.indexOf('const ry =', start);
  assert.ok(start > 0 && end > start);
  const declarations = [...src.slice(start, end).matchAll(/const (is_\w+) = ([^;]+);/g)];
  function classify(offset) {
    const env = { ...constants, result_idx: offset, g_search_ws_move_mode: false, IS_DEV: false };
    for (const [, name, raw] of declarations) {
      const expr = raw.replace(/\band\b/g, '&&').replace(/\bor\b/g, '||');
      assert.match(expr, /^[\w\s!<>=&|()+.\-]+$/);
      const names = [...new Set(expr.match(/[A-Za-z_]\w*/g) || [])].filter(n => n !== 'true' && n !== 'false');
      for (const n of names) assert.ok(n in env, `unknown classifier ${n}`);
      env[name] = Function(...names, `return (${expr})`)(...names.map(n => env[n]));
    }
    return Object.keys(env).filter(k => k.startsWith('is_') && env[k]);
  }
  assert.deepEqual(classify(constants.SEARCH_CHAT_COPY_CODE_OFFSET), ['is_chat_copy', 'is_chat_action', 'is_skill_action']);
  assert.deepEqual(classify(constants.SEARCH_CHAT_AC_OFFSET), ['is_chat_ac', 'is_chat_action', 'is_skill_action']);
  assert.ok(classify(constants.SEARCH_ADDFAVICON_OFFSET).includes('is_addfavicon'));
});

test('file attachment and inline image previews ship on every surface (issue)', () => {
  assert.match(src, /SEARCH_CHAT_ATTACH_OFFSET: usize = 6372/);
  assert.match(src, /SEARCH_CHAT_ATTACH_OFFSET => "chat view attach file/);
  assert.match(src, /is_chat_copy or is_chat_attach or/);
  assert.match(src, /L\("Chat View: Attach File"\)/);
  assert.match(src, /target == SEARCH_CHAT_ATTACH_OFFSET/);
  assert.match(src, /\.a = "\+ button \/ Ctrl\+V in Chat View"/);
  assert.match(docs, /\+ button \/ Ctrl\+V in Chat View/);
  assert.match(docs, /Chat View: Attach File/);
  assert.ok(build.includes('src/chat_image.zig'));
  assert.ok(build.includes('comdlg32'));
  assert.match(body('chatButtonAt'), /attach_btn/);
  assert.match(body('chatMeasureBlockRect'), /chatImgMeasure/);
  assert.match(body('chatRelayout'), /chatImgFirstBlock/);
  assert.match(body('chatImgWorker'), /chatImgLoadThumb/);
});


test('tool lines toggle before links and selection and expose all palette surfaces', () => {
  assert.match(body('chatTranscriptWndProc'), /WM_LBUTTONDOWN => \{\s*(?:if \((?:app_state\.)?g_chat_find_open and GET_Y\(lp\) < uiScaled\((?:app_state\.)?CHAT_FIND_TOP_H\)\) return 0;\s*)?if \(chatToolAt[^]*?tool_open = ![^]*?chatImageReady\(\);\s*return 0;/);
  assert.match(body('chatToolAt'), /role != \.tool/);
  assert.match(body('chatToggleAllTools'), /block\.role == \.tool[^]*?block\.tool_open = open/);
  assert.match(body('refreshChatBlockCache'), /open_tools\.contains\(block\.tool_id\)/);
  assert.match(src, /SEARCH_CHAT_TOOL_STEPS_OFFSET => "chat view open or fold all tool steps/);
  assert.match(src, /target == SEARCH_CHAT_TOOL_STEPS_OFFSET/);
  assert.match(src, /L\("Chat View: Open or fold all tool steps"\)/);
  assert.match(docs, /Chat View: Open or fold all tool steps/);
});


test('IGSH-404 every Chat View copy path owns selection-sized storage and reports failures', () => {
  assert.doesNotMatch(src, /g_chat_sel_text/);
  assert.match(body('chatCopyCapacity'), /std\.math\.mul\(usize, selected_len, 2\)/);
  assert.match(body('chatCopyCapacity'), /block_count -\| 1, 4/);
  const allocate = body('chatCopyTextAlloc');
  assert.match(allocate, /try chatCopyCapacity\(selected_len/);
  assert.match(allocate, /try allocator\.alloc\(u16, capacity\)/);
  assert.match(allocate, /errdefer allocator\.free\(out\)/);
  assert.match(allocate, /try chatCopyBlockText/);
  assert.match(allocate, /try chatSelectionToClipboard/);
  assert.match(allocate, /allocator\.realloc\(out, n\)/);
  for (const name of ['chatCopySelection', 'chatCopyBlockToClipboard']) {
    const copy = body(name);
    assert.match(copy, /chatCopyTextAlloc\(std\.heap\.page_allocator,/);
    assert.match(copy, /catch \{\s*showHeaderNoticeAscii\("Could not copy text; try again", 2500, true\);\s*return;/);
    assert.match(copy, /defer std\.heap\.page_allocator\.free\(text\)/);
    assert.match(copy, /chatCopyTextToClipboard\(text\)/);
  }
  const menu = body('chatTranscriptWndProc');
  assert.match(menu, /const selection_text = chatCopyTextAlloc/);
  assert.match(menu, /const message_text: \[\]u16 = if \(block_at\) \|idx\| chatCopyTextAlloc/);
  assert.match(menu, /defer std\.heap\.page_allocator\.free\(selection_text\)/);
  assert.match(menu, /defer std\.heap\.page_allocator\.free\(message_text\)/);
  assert.match(body('chatCopyTextToClipboard'), /else if \(setUnicodeClipboardTextWithRetry\(text\)\) \{\s*showHeaderNoticeAscii\("Copied"/);
  assert.match(body('chatCopyTextToClipboard'), /else \{\s*showHeaderNoticeAscii\("Could not copy to clipboard; try again", 2500, true\)/);
  assert.match(body('chatCopyRichText'), /else try std\.heap\.page_allocator\.alloc/);
  assert.match(body('chatCopyBlockText'), /try chat_markdown\.parseTable/);
  for (const name of ['chatCopyPlainText', 'chatCopyRichText', 'chatCopyBlockText', 'chatSelectionToClipboard']) {
    assert.match(body(name), /error\.NoSpaceLeft/);
  }
  assert.match(build, /"node", "--test", "tools\/chat-view-gaps\.test\.js"/);
  assert.match(build, /test_step\.dependOn\(&chat_view_gaps_tests\.step\)/);
});

test('IGSH-567 pending bubbles share transcript ranges, hit testing, highlighting and copying', () => {
  const display = body('chatSelectionDisplay');
  assert.match(display, /chatBlockDisplayRange/);
  assert.match(display, /g_chat_echo_layout_ids/);
  assert.match(display, /chatOutboxIndexById/);
  assert.match(display, /g_chat_last_len \+ 1/);
  for (const name of ['chatSelectAll', 'chatSelectionToClipboard', 'chatTranscriptSelectionBlockAt']) {
    assert.match(body(name), /g_chat_block_count \+ g_chat_echo_layout_count/);
    assert.match(body(name), /chatSelectionDisplay/);
  }
  assert.match(body('chatTranscriptCharAt'), /chatSelectionDisplay/);
  assert.match(body('chatTranscriptCharAt'), /chatSelectionRect/);
  assert.match(body('chatTranscriptCharAt'), /chatFlowBlock/);
  assert.match(body('chatTranscriptMouseDown'), /chatWordRangeAt\(display\.text/);
  assert.match(body('chatPaintEcho'), /chatFlowText\(hdc, e\.text, text_rc, false, true, null, offset,/);
  assert.match(body('chatTranscriptWndProc'), /chatPaintEcho\([^;]*display\.start\)/);
  assert.match(body('chatSelectionToClipboard'), /chatCopyPlainText\([^;]*display\.text/);
  assert.match(body('chatCopyTextAlloc'), /g_chat_block_count \+ g_chat_echo_layout_count/);
  assert.match(body('chatRelayout'), /old_echo_ids[^]*chatSelectionClear\(\)/);
});
