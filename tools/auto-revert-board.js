const { execFileSync } = require('node:child_process');

function main() {
  const board = process.env.CEO_HT;
  if (!board) throw new Error('CEO_HT must name the authenticated board-agent command');
  const repository = 'valentinyeo/multiprompt';
  const command = (name, args) => JSON.parse(execFileSync(name, args, { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 }));
  const api = path => command('gh', ['api', path, '--paginate', '--slurp']);
  const ht = args => {
    const result = command(board, [...args, '--json']);
    if (result.success !== true) throw new Error('Board request failed');
    return result;
  };
  const pulls = api(`repos/${repository}/pulls?state=all&per_page=100`).flat();
  for (const pull of pulls) {
    const runId = pull.head?.ref.match(/^auto-revert\/([1-9]\d*)$/)?.[1];
    const ticket = pull.title.match(/^Revert (IGSH-\d+):/)?.[1];
    if (!runId || !ticket || pull.user?.login !== 'github-actions[bot]' || (pull.state !== 'open' && !pull.merged_at)) continue;
    const body = pull.body || '';
    const sha = body.match(/^This reverts commit ([a-f0-9]{40})\.$/m)?.[1];
    const journeys = body.match(/^Failed journeys: ([a-z-]+(?:, [a-z-]+)*)$/m)?.[1];
    if (!sha || !journeys || !body.split('\n').includes(`Auto-Revert-Run: ${runId}`)) continue;
    const run = command('gh', ['api', `repos/${repository}/actions/runs/${runId}`]);
    if (String(run.id) !== runId || run.path !== '.github/workflows/verify.yml' || run.event !== 'push' || run.head_branch !== 'master' || run.head_sha !== sha || run.status !== 'completed' || run.conclusion !== 'failure' || run.repository?.full_name !== repository || run.head_repository?.full_name !== repository) continue;
    const tasks = ht(['task', 'get', ticket]).tasks;
    if (tasks?.length !== 1 || !['Todo', 'Doing', 'AI Review', 'Done'].includes(tasks[0].section)) throw new Error(`Unexpected board task: ${ticket}`);
    const url = `https://github.com/${repository}/actions/runs/${runId}`;
    const comments = [];
    const cursors = new Set();
    let cursor;
    do {
      const page = ht(['comment', 'list', ticket, ...(cursor ? ['--cursor', cursor] : [])]);
      if (!Array.isArray(page.comments)) throw new Error('Invalid board comment response');
      comments.push(...page.comments);
      cursor = page.has_more ? page.nextCursor : null;
      if (page.has_more && (!cursor || cursors.has(cursor))) throw new Error('Incomplete board comment history');
      if (cursor) cursors.add(cursor);
    } while (cursor);
    if (comments.some(comment => comment.text?.includes(url))) continue;
    if (tasks[0].section === 'Done') ht(['task', 'move', ticket, '--section', 'Todo']);
    ht(['comment', 'add', ticket, '--kind', 'qa', '--improve', '--text', `**Checks caught a broken update.** Automatic rollback requested for: ${journeys}.\nProof: ${url}\nNext: fix the failed update.`]);
    console.log(`REOPENED ${ticket} run ${runId}: ${journeys}`);
  }
  console.log('BOARD_RECONCILED');
}

if (require.main === module) {
  try {
    main();
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
