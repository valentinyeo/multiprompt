const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('chat UI approval guard', async t => {
  const guard = path.join(__dirname, 'check-chat-ui-approval.cjs');
  assert.ok(fs.existsSync(guard), 'trusted approval guard must exist');
  const workflowPath = path.join(__dirname, '../.github/workflows/chat-ui-approval.yml');
  assert.ok(fs.existsSync(workflowPath), 'trusted approval workflow must exist');
  const workflow = fs.readFileSync(workflowPath, 'utf8');
  const { evaluate, checkApproval, main } = require(guard);
  await t.test('workflow trust boundary', () => {
    const [tests, approval] = workflow.split(/\n  approval:\s*\n/);
    assert.ok(approval);
    assert.match(workflow, /pull_request_target:[\s\S]*?types: \[[^\]]*\bedited\b/);
    assert.match(tests, /github\.event_name == 'pull_request'/);
    assert.match(tests, /github\.event\.pull_request\.head\.sha/);
    assert.match(tests, /permissions:\s*\n\s+contents: read\s*\n/);
    assert.doesNotMatch(tests, /HYPERTASK_AGENT_TOKEN|secrets\.|statuses: write/);
    assert.match(approval, /github\.event\.pull_request\.base\.sha/);
    assert.doesNotMatch(approval, /ref:.*pull_request\.head/);
    assert.match(approval, /PR_HEAD_SHA: \$\{\{ github\.event\.pull_request\.head\.sha/);
    assert.match(approval, /statuses: write/);
    assert.match(approval, /HYPERTASK_AGENT_TOKEN: \$\{\{ secrets\.HYPERTASK_AGENT_TOKEN \}\}/);
    assert.match(approval, /node tools\/check-chat-ui-approval\.cjs/);
  });
  const link = 'UI approval: https://app.hypertask.ai/detail/project-2060/42';
  const ui = [{ filename: 'src/chat_render.zig', status: 'modified', patch: '@@ -1 +1 @@\n-old\n+new', changes: 2 }];
  const own = { creatorId: 6, creator: { id: 6 }, text: 'Approved' };
  const task = { boardId: 2060, description: '', createdBy: { id: 7 }, createdAt: 'a', updatedAt: 'b' };
  const board = (comments = [own], ticket = task, versions = []) => async url => {
    if (url.startsWith('/tasks/description-versions')) return { versions };
    if (url.startsWith('/tasks?')) return { success: true, tasks: [ticket] };
    return { success: true, comments, nextCursor: null };
  };
  const check = (body, files = ui, api = board()) => evaluate({ body, files, boardApi: api });
  await t.test('requires a link and authentic affirmative', async () => {
    assert.equal(await check(''), false);
    assert.equal(await check(link), true);
    for (const text of ['<p>Yes</p>', '<p>Yes, do this.</p>', '<p>👍</p>', '<p><strong>Approved</strong>.</p>', '<p>Y&#101;s</p>']) assert.equal(await check(link, ui, board([{ ...own, text }])), true, text);
    for (const text of ['> Approved', '```\nApproved\n```', 'Not approved', 'Approved?', '<s>Yes</s>', '<del>Approved</del>', '~~Yes~~', 'Approved if ready', 'The runner said approved', '<blockquote><p>Yes</p></blockquote>', '<script>Yes</script>', '<p hidden>Yes</p>', '<p style="display:none">Yes</p>', '<code>Yes</code>', '<p>Yes, but not yet.</p>', '<p>Yes, if ready.</p>', '<p>Yes?</p>', '<p>Yes</p><p>if ready.</p>']) {
      assert.equal(await check(link, ui, board([{ ...own, text }])), false, text);
    }
    for (const author of [
      { ...own, agent: { id: 1 } },
      { ...own, agent_display_name: 'agent' },
      { ...own, creatorId: 7 },
      { ...own, editedAt: 'x' },
      { ...own, editedAt: 'x', editedBy: { userId: 6, agentId: 1 } },
    ]) assert.equal(await check(link, ui, board([author])), false);
    assert.equal(await check(link, ui, board([{ ...own, editedAt: 'x', editedBy: { userId: 6, agentId: null } }])), true);
  });
  await t.test('PR approval field must be unquoted prose', async () => {
    for (const body of [`\`\`\`\n${link}\n\`\`\``, `~~~\n${link}\n~~~`, `> ${link}`, `<!--\n${link}\n-->`, `<!-- ${link} -->`, `    ${link}`, `<blockquote>\n${link}\n</blockquote>`]) assert.equal(await check(body), false, body);
    assert.equal(await check(`Example:\n\`\`\`\n${link}\n\`\`\`\n\n${link}`), true);
  });
  await t.test('canonical comment links select owner evidence', async () => {
    const yes = { ...own, id: 12, createdAt: '2025-01-01T00:00:00Z' };
    const agent = { ...own, id: 13, agent: true, createdAt: '2025-01-02T00:00:00Z' };
    const no = { ...own, id: 14, text: '<p>I do not approve this.</p>', createdAt: '2025-01-03T00:00:00Z' };
    assert.equal(await check(`${link}#comment-12`, ui, board([yes, agent])), true);
    assert.equal(await check(`${link}#comment-13`, ui, board([yes, agent])), false);
    assert.equal(await check(`${link}, https://app.hypertask.ai/detail/project-2060/42#comment-13`, ui, board([yes, agent])), false);
    assert.equal(await check(`${link}#comment-99`, ui, board([yes])), false);
    assert.equal(await check(`${link}#comment-14`, ui, board([yes, no])), false);
    assert.equal(await check(`${link}#comment-12`, ui, board([yes, no])), false);
    assert.equal(await check(link, ui, board([yes, { ...no, text: '<p>Do not add this.</p>' }])), false);
    assert.equal(await check(link, ui, board([{ ...own, text: '<p>Yes.</p><p>I do not approve this.</p>' }])), false);
    const ticket = { ...task, description: 'Yes', createdBy: { id: 6 }, createdAt: 'a', updatedAt: 'a' };
    assert.equal(await check(`${link}#comment-13`, ui, board([agent], ticket)), false);
    assert.equal(await check(`${link}#comment-12`, ui, board([yes, { ...yes }])), false);
  });
  await t.test('description provenance', async () => {
    const ticket = { ...task, description: 'Yes', createdBy: { id: 6 }, createdAt: 'a', updatedAt: 'a' };
    assert.equal(await check(link, ui, board([], ticket)), true);
    assert.equal(await check(link, ui, board([], { ...ticket, createdBy: { id: 6, agent: { id: 1 } } })), false);
    const edited = { ...ticket, updatedAt: 'b' };
    assert.equal(await check(link, ui, board([], edited)), false);
    assert.equal(await check(link, ui, board([], edited, [{ content: 'Yes', author_id: 6, agent_id: null, version: 2, created_at: 'b' }])), true);
    assert.equal(await check(link, ui, board([], edited, [{ content: 'Yes', author_id: 6, agent_id: 3, version: 2, created_at: 'b' }])), false);
    assert.equal(await check(link, ui, board([], { ...edited, description: '<p><strong>Yes</strong>, do this.</p>' }, [{ content: '**Yes**, do this.', author_id: 6, agent_id: null, version: 2, created_at: 'b' }])), true);
  });
  await t.test('surface and tampering', async () => {
    assert.equal(await check('', [{ filename: 'src/chat_send.zig', status: 'modified', changes: 2, patch: '@@ -1 +1 @@\n-old\n+new' }], null), true);
    assert.equal(await check('', [{ filename: 'src/chat_session.zig', status: 'modified', changes: 2, patch: '@@ -1 +1 @@\n-send()\n+sendLater()' }], null), true);
    assert.equal(await check('', [{ filename: 'src/chat_session.zig', status: 'modified', changes: 2, patch: '@@ -1 +1 @@\n-draw()\n+drawNew()' }]), false);
    for (const file of [
      { filename: 'src/new_render.zig', status: 'added' },
      { filename: 'src/other.zig', previous_filename: 'src/sidebar.zig', status: 'renamed' },
      { filename: 'src/chat_session.zig', status: 'modified' },
      { filename: 'tools/check-chat-ui-approval.cjs', status: 'modified' },
      { filename: '.github/workflows/chat-ui-approval.yml', status: 'modified' },
    ]) assert.equal(await check('', [file]), false);
    assert.equal(await check('', [{ filename: 'tools/check-chat-ui-approval.cjs', status: 'added' }], null), true);
    for (const filename of ['CLAUDE.md', 'AGENTS.md', 'GATES.md', 'tools/chat-ui-approval.test.js']) assert.equal(await check('', [{ filename, status: 'modified' }], null), true);
    for (const filename of ['src/telemetry_panel.zig', 'src/chat_float.zig', 'src/chat_skill.zig', 'src/chat_composer_text.zig', 'src/chat_markdown.zig', 'src/chat_capture.zig', 'src/fonts.zig', 'src/font_probe.zig', 'SRC/sidebar.zig', 'src/message_menu.zig', 'src/room_view.zig', 'src/bot_photo.zig', 'src/update_card.zig', 'src/workspace_switcher.zig', 'src/design_tokens.zig', 'src/bot_look.zig', 'src/star_badge_geometry.zig']) assert.equal(await check('', [{ filename, status: 'modified' }]), false, filename);
    assert.equal(await check('', [{ filename: 'src/capacity.zig', status: 'modified', changes: 2, patch: '@@ -1 +1 @@\n-oldAdmission()\n+newAdmission()' }], null), true);
    assert.equal(await check('', [{ filename: 'src/capacity.zig', status: 'modified', changes: 2, patch: '@@ -1 +1 @@\n-oldDraw()\n+newDraw()' }]), false);
    for (const symbol of ['chat_block', 'chat_capture', 'cache', 'tailFor', 'classification']) assert.equal(await check('', [{ filename: 'src/chat_session.zig', status: 'modified', changes: 2, patch: `@@ -1 +1 @@\n-old\n+${symbol}` }]), false, symbol);
    assert.equal(await check('', [{ filename: 'src/chat_transport.zig', status: 'added', patch: '@@ -0,0 +1 @@\n+fn send() {}', changes: 1 }], null), true);
    assert.equal(await check('', [{ filename: 'src/chat_transport.zig', status: 'added', patch: '@@ -0,0 +1 @@\n+drawChat();', changes: 1 }]), false);
  });
  await t.test('status is pending before file and ticket reads', async () => {
    const events = [];
    const logs = [];
    const fetchApi = async (url, options) => {
      let data;
      if (url.endsWith('/pulls/1')) { events.push('pr'); data = { head: { sha: 'a'.repeat(40) }, body: '', changed_files: 1 }; }
      else if (url.includes('/statuses/')) { data = JSON.parse(options.body); events.push(data.state); }
      else if (url.includes('/files?')) { events.push('files'); data = ui; }
      else throw new Error('unexpected request');
      return { ok: true, json: async () => data };
    };
    assert.equal(await main({ env: { GITHUB_REPOSITORY: 'example/repo', GH_TOKEN: 'token', PR_NUMBER: '1' }, fetchApi, log: value => logs.push(value) }), false);
    assert.deepEqual(events, ['pr', 'pending', 'files', 'failure']);
    assert.match(logs[0], /UI approval: ticket URL/);
    assert.doesNotMatch(logs[0], /token/);
  });
  await t.test('edited PR clears stale success before a failed PR read', async () => {
    const events = [];
    const fetchApi = async (url, options) => {
      if (url.endsWith(`/statuses/${'a'.repeat(40)}`)) {
        events.push(JSON.parse(options.body).state);
        return { ok: true, json: async () => ({}) };
      }
      events.push('failed PR read');
      throw new Error('unavailable');
    };
    await assert.rejects(main({ env: { GITHUB_REPOSITORY: 'example/repo', GH_TOKEN: 'token', PR_NUMBER: '1', PR_HEAD_SHA: 'a'.repeat(40) }, fetchApi }), /unavailable/);
    assert.deepEqual(events, ['pending', 'failed PR read']);
  });
  await t.test('authenticated drawing approval posts success without exposing evidence', async () => {
    const events = [];
    const logs = [];
    const fetchApi = async (url, options) => {
      const boardRequest = url.startsWith('https://api.hypertask.ai/api/mcp/');
      assert.equal(options.headers.Authorization, `Bearer ${boardRequest ? 'board-token' : 'github-token'}`);
      let data;
      if (url.endsWith('/pulls/1')) data = { head: { sha: 'a'.repeat(40) }, body: link, changed_files: 1 };
      else if (url.includes('/statuses/')) { data = JSON.parse(options.body); events.push(data.state); }
      else if (url.includes('/files?')) data = ui;
      else if (url === 'https://api.hypertask.ai/api/mcp/tasks?ticket_number=IGSH-42') data = { success: true, tasks: [task] };
      else if (url === 'https://api.hypertask.ai/api/mcp/comments?ticket_number=IGSH-42') data = { success: true, comments: [{ ...own, text: '<p>Yes, approved synthetic evidence.</p>' }] };
      else throw new Error('unexpected request');
      return { ok: true, json: async () => data };
    };
    assert.equal(await main({ env: { GITHUB_REPOSITORY: 'example/repo', GH_TOKEN: 'github-token', HYPERTASK_AGENT_TOKEN: 'board-token', PR_NUMBER: '1', PR_HEAD_SHA: 'a'.repeat(40) }, fetchApi, log: value => logs.push(value) }), true);
    assert.deepEqual(events, ['pending', 'success']);
    assert.doesNotMatch(logs.join('\n'), /token|synthetic evidence|IGSH-42/);
  });
  await t.test('pagination and incomplete data', async () => {
    let pages = 0;
    const api = async url => {
      if (url.startsWith('/tasks?')) return { success: true, tasks: [task] };
      if (url.includes('cursor=')) { pages++; return { success: true, comments: [own], nextCursor: null }; }
      return { success: true, comments: [], nextCursor: 'next' };
    };
    assert.equal(await check(link, ui, api), true);
    assert.equal(pages, 1);
    assert.equal(await check(link, ui, async () => ({})), false);
    assert.equal(await check(link, ui, async url => url.startsWith('/tasks?') ? { success: true, tasks: [task] } : { success: true, comments: [own], has_more: true }), false);
    for (const identity of [{ uniqueIndex: 43 }, { ticketNumber: 'IGSH-43' }, { boardId: 999 }]) assert.equal(await check(link, ui, board([own], { ...task, ...identity })), false);
    assert.equal(await check(link, ui, board([own], { ...task, uniqueIndex: 42, ticketNumber: 'IGSH-42' })), true);
    const yes = { ...own, text: '<p>Yes</p>', createdAt: '2025-01-01T00:00:00Z' };
    const no = { ...own, text: '<p>No</p>', createdAt: '2025-01-02T00:00:00Z' };
    assert.equal(await check(link, ui, board([no, yes])), false);
    assert.equal(await check(link, ui, board([yes, { ...no, agent: true }])), true);
    assert.equal(await check(link, ui, board([{ ...no, createdAt: '2024-01-01T00:00:00Z' }, yes])), true);
    assert.equal(await check(link, ui, board([own, { ...own, text: 'No' }])), false);
    assert.equal(await checkApproval({ body: link, boardApi: board(), files: ui, changedFiles: 2 }), false);
    const backend = Array.from({ length: 100 }, (_, i) => ({ filename: `src/backend${i}.zig`, status: 'modified' }));
    const requested = [];
    const githubApi = async page => { requested.push(page); return page === 1 ? backend : ui; };
    assert.equal(await checkApproval({ pr: { body: link, changed_files: 101 }, githubApi, boardApi: board() }), true);
    assert.deepEqual(requested, [1, 2]);
    assert.equal(await checkApproval({ pr: { body: link, changed_files: 102 }, githubApi, boardApi: board() }), false);
  });
});
