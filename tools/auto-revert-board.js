const boardBase = 'https://api.hypertask.ai/api/mcp';
const reopenable = ['Todo', 'Doing', 'AI Review', 'Done'];

const escapeHtml = text => String(text).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function boardApi(credential, base = boardBase) {
  return async (method, path, body) => {
    const response = await fetch(base + path, {
      method,
      headers: { Authorization: `Bearer ${credential}`, 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(30000),
    });
    const result = await response.json().catch(() => null);
    if (!response.ok || result?.success !== true) throw new Error(`Board ${method} ${path.split('?')[0]} failed with status ${response.status}`);
    return result;
  };
}

async function reopenTicket({ api, ticket, runUrl, journeys }) {
  const tasks = (await api('GET', `/tasks?ticket_number=${encodeURIComponent(ticket)}`)).tasks;
  if (tasks?.length !== 1 || !reopenable.includes(tasks[0].section)) throw new Error(`Unexpected board task: ${ticket}`);
  const comments = [];
  const cursors = new Set();
  let cursor;
  do {
    const page = await api('GET', `/comments?ticket_number=${encodeURIComponent(ticket)}${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`);
    if (!Array.isArray(page.comments)) throw new Error('Invalid board comment response');
    comments.push(...page.comments);
    cursor = page.nextCursor || null;
    if (cursor && cursors.has(cursor)) throw new Error('Incomplete board comment history');
    if (cursor) cursors.add(cursor);
  } while (cursor);
  if (comments.some(comment => comment.text?.includes(runUrl))) return 'already reopened';
  if (tasks[0].section === 'Done') {
    const sections = (await api('GET', `/projects/${tasks[0].boardId}/sections`)).sections;
    const todo = sections?.find(section => section.section_title === 'Todo' && !section.deleted);
    if (!todo) throw new Error('Board has no Todo column');
    await api('POST', '/tasks/update', { ticket_number: ticket, sectionId: todo.id });
  }
  const url = escapeHtml(runUrl);
  await api('POST', '/comments', {
    ticket_number: ticket,
    kind: 'qa',
    text: `<p><strong>Checks caught a broken update.</strong> Automatic rollback requested for: ${escapeHtml(journeys)}.</p><p>Proof: <a href="${url}">${url}</a></p><p>Next: fix the failed update.</p>`,
  });
  return 'reopened';
}

async function main() {
  const [ticket, runUrl, journeys] = process.argv.slice(2);
  const credential = process.env.HYPERTASK_AGENT_TOKEN;
  if (!credential) throw new Error('HYPERTASK_AGENT_TOKEN is not set');
  if (!/^IGSH-\d+$/.test(ticket || '') || !/^https:\/\/github\.com\/valentinyeo\/multiprompt\/actions\/runs\/[1-9]\d*$/.test(runUrl || '') || !journeys) throw new Error('Usage: auto-revert-board.js IGSH-N RUN_URL JOURNEYS');
  const outcome = await reopenTicket({ api: boardApi(credential, process.env.HYPERTASK_API_BASE || boardBase), ticket, runUrl, journeys });
  console.log(`${ticket} ${outcome}`);
}

module.exports = { reopenTicket, boardApi };

if (require.main === module) {
  main().catch(error => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
