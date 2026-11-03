// The ticket itself is Done and carries the green master run link for a reader.
import { ghJson } from './lib.mjs';
import { fail } from './lib.mjs';
import { execFileSync } from 'node:child_process';

const VCC = `${process.env.HOME}/.local/bin/vcc`;
const raw = execFileSync(VCC, ['task', 'get', 'HYCI-94', '--json'], {
  encoding: 'utf8', maxBuffer: 32 * 1024 * 1024, shell: false,
});
const task = JSON.parse(raw).tasks[0];
if (task.section !== 'Done') fail(`ticket sits in ${task.section}, not Done`);

const comments = execFileSync(VCC,
  ['comment', 'list', 'HYCI-94', '--json'], { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
const parsed = JSON.parse(comments);
const list = parsed.comments || parsed.data || [];
const text = list.map((c) => c.text || '').join('\n');
const runId = ghJson(['pr', 'view', '726', '--repo', 'valentinyeo/multiprompt', '--json', 'mergeCommit']).mergeCommit.oid.slice(0, 8);
if (!/https:\/\/github\.com\/valentinyeo\/multiprompt\/actions\/runs\/\d+/.test(text)) {
  fail('no full master run link on the ticket');
}
if (!text.includes(runId)) fail(`the merge sha ${runId} is not named on the ticket`);

console.log(`section=${task.section} run-link=yes sha=${runId}`);
console.log('OK the ticket is Done with the green master run proof');
