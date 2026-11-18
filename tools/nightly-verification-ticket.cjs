const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { boardApi } = require('./auto-revert-board.js');
const { summarize, runOutcome } = require('./pr-verifier.cjs');

async function reportNightly({ api, failures, runUrl, sha }) {
  if (!failures.length) return 'clean';
  const title = 'Multiprompt nightly feature journeys failed';
  const matches = [];
  const cursors = new Set();
  let cursor;
  do {
    const query = new URLSearchParams({ project_id: '2060', q: title, limit: '100' });
    if (cursor) query.set('cursor', cursor);
    const page = await api('GET', `/tasks/search?${query}`);
    if (!Array.isArray(page.tasks)) throw new Error('Invalid task search response');
    matches.push(...page.tasks.filter(task => task.title === title && task.section !== 'Done'));
    cursor = page.nextCursor;
    if (cursor && cursors.has(cursor)) throw new Error('Repeated task cursor');
    if (!cursor && page.has_more) throw new Error('Incomplete task search');
    if (cursor) cursors.add(cursor);
  } while (cursor);
  if (matches.length > 1) throw new Error('Multiple open nightly failure tickets');
  let task = matches[0];
  if (!task) {
    const { labels } = await api('GET', '/projects/2060/labels');
    const { sections } = await api('GET', '/projects/2060/sections');
    const labelIds = ['Poteto', 'brain-medium'].map(name => {
      const label = labels?.find(label => label.name === name && !label.deleted);
      if (!label) throw new Error(`Required label missing: ${name}`);
      return label.id;
    });
    const section = sections?.find(section => section.section_title === 'Todo' && !section.deleted);
    if (!section) throw new Error('Todo section unavailable');
    const created = await api('POST', '/tasks/create', {
      project_id: 2060, title, section_id: section.id, labels: labelIds,
      description: '<h2>Problem</h2><p>Nightly journeys found broken or unverified features.</p><h2>Fix</h2><p>Reproduce each failure on its matching screen.</p><p>Revert first if users cannot work.</p><h2>Done when</h2><p>The failed journeys pass on master.</p><h2>Risk</h2><p>Some features may remain broken.</p><h2>Decision</h2><p>None.</p>',
    });
    task = created.task ?? created.tasks?.[0];
    if (!task?.id) throw new Error('Missing created task');
  }
  const receipt = `Nightly feature verification ${runUrl}`;
  const comments = [];
  const seen = new Set();
  cursor = null;
  do {
    const query = new URLSearchParams({ ticket_number: task.ticketNumber, limit: '100' });
    if (cursor) query.set('cursor', cursor);
    const page = await api('GET', `/comments?${query}`);
    if (!Array.isArray(page.comments)) throw new Error('Invalid comment response');
    comments.push(...page.comments);
    cursor = page.nextCursor;
    if (cursor && seen.has(cursor)) throw new Error('Repeated comment cursor');
    if (!cursor && page.has_more) throw new Error('Incomplete comment history');
    if (cursor) seen.add(cursor);
  } while (cursor);
  if (!comments.some(comment => comment.text?.includes(receipt))) {
    await api('POST', '/comments', { ticket_number: task.ticketNumber, text: `${receipt}\nCommit: ${sha}\nFailures: ${failures.join(', ')}` });
  }
  return task.ticketNumber;
}

async function main(env = process.env) {
  const gh = args => execFileSync('gh', args, { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  const repo = env.GITHUB_REPOSITORY;
  const run = env.GITHUB_RUN_ID;
  const pages = JSON.parse(gh(['api', '--paginate', '--slurp', `repos/${repo}/actions/runs/${run}/jobs?per_page=100`]));
  const jobs = pages.flatMap(page => page.jobs);
  const failures = jobs.filter(job => ['failure', 'cancelled', 'timed_out'].includes(job.conclusion)).map(job => job.name);
  const features = JSON.parse(env.FEATURES || '[]');
  const directory = path.join(env.RUNNER_TEMP, 'nightly-evidence');
  fs.mkdirSync(directory, { recursive: true });
  if (features.length) {
    try { gh(['run', 'download', run, '--repo', repo, '--pattern', 'verify-*', '--dir', directory]); }
    catch { failures.push('Journey evidence could not be downloaded'); }
    const summary = summarize(directory, features, '');
    for (const feature of features) {
      const runs = summary.head[feature];
      if (!runs.length || runs.some(item => runOutcome(item) !== 'passed')) failures.push(feature);
    }
  } else failures.push('Feature discovery did not complete');
  if (failures.length && !env.HYPERTASK_AGENT_TOKEN) throw new Error('HYPERTASK_AGENT_TOKEN is required');
  const outcome = await reportNightly({ api: boardApi(env.HYPERTASK_AGENT_TOKEN), failures: [...new Set(failures)], runUrl: `https://github.com/${repo}/actions/runs/${run}`, sha: env.GITHUB_SHA });
  console.log(`Nightly verification: ${outcome}`);
}

module.exports = { reportNightly };
if (require.main === module) main().catch(error => { console.error(error.message); process.exitCode = 1; });
