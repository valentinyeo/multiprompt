import { readFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';
import board from './auto-revert-board.js';

const title = 'Multi Bot messages are slow to send';
const requiredLabels = ['CI', 'Hypertask CI', 'Multiprompt', 'brain-medium'];

export async function fileLatencyWarning({ api, result, runUrl, sha }) {
  if (result?.status !== 'warning' || !Number.isFinite(result.worstMs) || !Number.isFinite(result.limitMs) || result.worstMs <= result.limitMs || result.limitMs < 0) return { outcome: 'skipped' };
  if (!/^https:\/\/github\.com\/valentinyeo\/multiprompt\/actions\/runs\/[1-9]\d*$/.test(runUrl || '') || !/^[a-fA-F0-9]{40}$/.test(sha || '')) throw new Error('Invalid run URL or commit SHA');
  if (typeof api !== 'function') throw new Error('Board API is required');

  const matches = [];
  const seen = new Set();
  let cursor;
  do {
    const query = new URLSearchParams({ q: title, project_id: '11514', status: 'Normal', limit: '100' });
    if (cursor) query.set('cursor', cursor);
    const page = await api('GET', `/tasks/search?${query}`);
    if (!Array.isArray(page.tasks)) throw new Error('Invalid task search response');
    for (const task of page.tasks) {
      if (task.title !== title) continue;
      if (typeof task.section !== 'string') throw new Error('Task search lacks a section');
      if (task.section !== 'Done') matches.push(task);
    }
    cursor = page.nextCursor;
    if (cursor != null && (typeof cursor !== 'string' || !cursor || seen.has(cursor))) throw new Error('Invalid task search cursor');
    if (!cursor && page.has_more === true) throw new Error('Incomplete task search');
    if (cursor) seen.add(cursor);
  } while (cursor);
  if (matches.length > 1) throw new Error('Multiple open warning tickets found');
  if (matches.length) return { outcome: 'existing', task: matches[0] };

  const labels = (await api('GET', '/projects/11514/labels')).labels;
  const sections = (await api('GET', '/projects/11514/sections')).sections;
  if (!Array.isArray(labels) || !Array.isArray(sections)) throw new Error('Invalid board settings');
  const ids = requiredLabels.map(name => {
    const found = labels.filter(label => label.name === name && !label.deleted);
    if (found.length !== 1 || !/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(found[0].id || '')) throw new Error(`Required label unavailable: ${name}`);
    return found[0].id;
  });
  const backlog = sections.filter(section => section.section_title === 'Backlog' && !section.deleted);
  if (backlog.length !== 1 || !Number.isSafeInteger(backlog[0].id) || backlog[0].id <= 0) throw new Error('Backlog section unavailable');
  const description = `<h2>Problem</h2><p>Multi Bot messages take too long to send.</p><p>Slowest: ${result.worstMs} ms. Limit: ${result.limitMs} ms.</p><h2>Fix</h2><p>Find and fix the delay.</p><h2>Done when</h2><p>Messages send within the limit.</p><h2>Risk</h2><p>Messages may still feel slow.</p><h2>Decision</h2><p>None.</p><p>Run: <a href="${runUrl}">${runUrl}</a></p>`;
  const created = await api('POST', '/tasks/create', { project_id: 11514, title, description, section_id: backlog[0].id, labels: ids });
  return { outcome: 'created', task: created.task ?? created.tasks?.[0] };
}

async function main() {
  const [file, runUrl, sha] = process.argv.slice(2);
  if (!file) throw new Error('Usage: node tools/resource-warning-ticket.mjs RESULT_JSON RUN_URL SHA');
  const evidence = JSON.parse(await readFile(file, 'utf8'));
  const result = evidence.latency ?? evidence;
  const api = async (...args) => {
    const token = process.env.HYPERTASK_AGENT_TOKEN;
    if (!token?.trim()) throw new Error('HYPERTASK_AGENT_TOKEN is required');
    return board.boardApi(token)(...args);
  };
  const outcome = await fileLatencyWarning({ api, result, runUrl, sha });
  console.log(outcome.outcome);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(() => {
    console.error('Could not process latency warning.');
    process.exitCode = 1;
  });
}
