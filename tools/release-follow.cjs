const fs = require('node:fs');

function runId(run) {
  return run.id ?? run.databaseId;
}

function followDecision({ tip, built, releaseResult, runs, selfId }) {
  const list = Array.isArray(runs) ? runs : [];
  const active = list.some(run => String(runId(run)) !== String(selfId) && run.headSha === tip && run.status !== 'completed');
  const published = list.some(run => String(runId(run)) !== String(selfId) && run.headSha === tip && run.conclusion === 'success');
  if (published) return { dispatch: false, reason: 'already released' };
  if (active) return { dispatch: false, reason: 'already queued' };
  if (String(tip) !== String(built)) return { dispatch: true, reason: 'master moved' };
  if (releaseResult === 'cancelled') return { dispatch: true, reason: 'release cancelled' };
  return { dispatch: false, reason: 'this commit is current' };
}

function main() {
  const decision = followDecision(JSON.parse(fs.readFileSync(0, 'utf8')));
  process.stdout.write(decision.dispatch ? 'dispatch\n' : 'skip\n');
}

module.exports = { followDecision };

if (require.main === module) main();
