import { writeFile } from 'node:fs/promises';
import board from './auto-revert-board.js';
import { fileLatencyWarning } from './resource-warning-ticket.mjs';

const evidence = { status: 'failed', runUrl: process.env.RUN_URL, sha: process.env.SOURCE_SHA, metrics: {}, cleanup: [] };
const owned = [];
let failed = false;
const token = process.env.HYPERTASK_AGENT_TOKEN;
const api = board.boardApi(token);
const result = { status: 'warning', worstMs: 2, limitMs: 1 };

try {
  if (!token?.trim()) throw new Error('HYPERTASK_AGENT_TOKEN is required');
  for (const metric of ['send', 'typing']) {
    const entry = evidence.metrics[metric] = { creates: 0 };
    const trackedApi = async (method, path, body) => {
      const response = await api(method, path, body);
      if (method === 'POST' && path === '/tasks/create') {
        entry.creates++;
        const task = response.task ?? response.tasks?.[0];
        if (task?.ticketNumber && /^HYCI-\d+$/.test(task.ticketNumber)) owned.push({ ticket: task.ticketNumber, title: body.title });
      }
      return response;
    };
    const args = { api: trackedApi, result, runUrl: process.env.RUN_URL, sha: process.env.SOURCE_SHA, metric, verification: true };
    const first = await fileLatencyWarning(args);
    if (first.outcome === 'existing') throw new Error(`${metric}: existing verification ticket; resolve leftover manually`);
    if (first.outcome !== 'created' || entry.creates !== 1 || !owned.at(-1) || first.task?.ticketNumber !== owned.at(-1).ticket) throw new Error(`${metric}: creation could not be identified`);
    entry.ticket = first.task.ticketNumber;
    const repeat = await fileLatencyWarning(args);
    if (repeat.outcome !== 'existing' || repeat.task?.ticketNumber !== entry.ticket || entry.creates !== 1) throw new Error(`${metric}: deduplication failed`);
    entry.repeat = repeat.outcome;
  }
} catch (error) {
  failed = true;
  evidence.error = error.message;
} finally {
  for (const item of owned) {
    const cleanup = { ticket: item.ticket, status: 'failed' };
    evidence.cleanup.push(cleanup);
    try {
      const tasks = (await api('GET', `/tasks?ticket_number=${encodeURIComponent(item.ticket)}`)).tasks;
      if (!Array.isArray(tasks) || tasks.length !== 1 || tasks[0].title !== item.title || Number(tasks[0].boardId) !== 11514) throw new Error('Created ticket identity could not be verified');
      const sections = (await api('GET', '/projects/11514/sections')).sections;
      const done = sections?.filter(section => section.section_title === 'Done' && !section.deleted);
      if (done?.length !== 1 || !Number.isSafeInteger(done[0].id) || done[0].id <= 0) throw new Error('Done section unavailable');
      await api('POST', '/tasks/update', { ticket_number: item.ticket, sectionId: done[0].id });
      const readback = (await api('GET', `/tasks?ticket_number=${encodeURIComponent(item.ticket)}`)).tasks;
      if (!Array.isArray(readback) || readback.length !== 1 || readback[0].title !== item.title || Number(readback[0].boardId) !== 11514 || readback[0].section !== 'Done') throw new Error('Done readback failed');
      cleanup.status = 'done';
    } catch (error) {
      failed = true;
      cleanup.error = error.message;
    }
  }
  evidence.status = failed ? 'failed' : 'passed';
  await writeFile('resource-warning-integration-evidence.json', `${JSON.stringify(evidence, null, 2)}\n`);
}
if (failed) {
  console.error('Integration proof failed; inspect evidence for details.');
  process.exitCode = 1;
}
