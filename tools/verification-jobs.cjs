const { execFileSync } = require('node:child_process');

function runJobs(repo, run) {
  const pages = JSON.parse(execFileSync('gh', ['api', '--paginate', '--slurp', `repos/${repo}/actions/runs/${run}/jobs?per_page=100`], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }));
  return pages.flatMap(page => page.jobs);
}

module.exports = { runJobs };
