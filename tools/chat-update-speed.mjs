import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export function parseRun(log, exit) {
  const parsed = /CPU707 parse rows=(\d+) blocks=(\d+) messages=(\d+) parse_cpu_ms=(\d+) parse_wall_ms=(\d+)/.exec(log);
  const delta = /CPU707 delta cpu_ms=(\d+)\/(\d+)\/(\d+) wall_ms=(\d+)\/(\d+)\/(\d+) best_cpu_ms=(\d+) budget_ms=100 blocks=(\d+) changed_from=(\d+)/.exec(log);
  if (!parsed || !delta) throw new Error('Missing completed parse or append measurement');
  const [rows, blocks, messages, parseCpu, parseWall] = parsed.slice(1).map(Number);
  const [a, b, c, x, y, z, best, updated, changed] = delta.slice(1).map(Number);
  if (rows < 50 * 1024 * 1024 - 256 || messages < 26000 || blocks !== messages || updated !== messages + 1 || changed !== messages - 1) throw new Error('History workload or append output changed');
  const suffixes = [...log.matchAll(/CPU707 suffix rows=(\d+) expected_rows=(\d+)/g)];
  if (suffixes.length !== 3 || suffixes.some(match => Number(match[1]) !== Number(match[2]) || Number(match[1]) < 1900)) throw new Error('Suffix work was skipped or changed');
  if (best !== Math.min(a, b, c)) throw new Error('Reported best CPU time is not the original minimum');
  const reconcile = /CPU707 reconcile picked=(\d+) expected_pick=(\d+) represented=(\d+) extra_picks=(\d+) reconcile_cpu_ms=(\d+) reconcile_wall_ms=(\d+)/.exec(log);
  const budgetFailure = exit === 1 && best >= 100 && parseCpu < 3000;
  if (exit !== 0 && !budgetFailure) throw new Error('Unexplained workload failure');
  if (exit === 0 && (!reconcile || Number(reconcile[1]) !== messages || Number(reconcile[2]) !== messages || Number(reconcile[3]) !== messages || Number(reconcile[4]) !== 0)) throw new Error('Reconciliation output is missing or incorrect');
  return { rows, messages, parseCpu, parseWall, cpu: [a, b, c], wall: [x, y, z], best, exit, budgetFailure, reconcileCpu: reconcile ? Number(reconcile[5]) : null };
}

export function stats(values) {
  const ordered = [...values].sort((a, b) => a - b);
  const middle = Math.floor(ordered.length / 2);
  return { median: ordered.length % 2 ? ordered[middle] : (ordered[middle - 1] + ordered[middle]) / 2, min: ordered[0], max: ordered.at(-1) };
}

export function compare(before, after) {
  if (before.length !== 5 || after.length !== 5) throw new Error('Five complete runs per side are required');
  const workload = before[0];
  if ([...before, ...after].some(run => run.messages !== workload.messages || run.rows !== workload.rows)) throw new Error('Sides measured different histories');
  const summarize = runs => ({ bestCpuMs: stats(runs.map(run => run.best)), allCpuMs: stats(runs.flatMap(run => run.cpu)), wallMs: stats(runs.flatMap(run => run.wall)), parseCpuMs: stats(runs.map(run => run.parseCpu)), budgetFailures: runs.filter(run => run.budgetFailure).length, exits: runs.map(run => run.exit) });
  return { before: summarize(before), after: summarize(after), messages: workload.messages, bytes: workload.rows, passed: after.every(run => run.exit === 0 && run.best < 100 && run.parseCpu < 3000 && run.reconcileCpu < 1000) };
}

export function summarize(directory) {
  const read = file => fs.readFileSync(path.join(directory, file), 'utf8').trim();
  const sides = {};
  const revisions = {};
  for (const side of ['before', 'after']) {
    revisions[side] = read(`${side}-revision.txt`);
    if (!/^[0-9a-f]{40}$/.test(revisions[side])) throw new Error('Source identity is missing');
    sides[side] = Array.from({ length: 5 }, (_, index) => parseRun(read(`${side}-${index + 1}.log`), Number(read(`${side}-${index + 1}.exit`))));
  }
  const expectedOrder = Array.from({ length: 5 }, (_, index) => (index % 2 ? ['after', 'before'] : ['before', 'after']).map(side => `${index + 1} ${side}`)).flat().join('\n');
  if (read('order.txt') !== expectedOrder) throw new Error('Runs did not alternate on the same runner');
  const result = { revisions, ...compare(sides.before, sides.after), runs: sides };
  fs.writeFileSync(path.join(directory, 'comparison.json'), JSON.stringify(result, null, 2) + '\n');
  console.log(JSON.stringify(result, null, 2));
  if (!result.passed) throw new Error('Candidate failed the unchanged CPU707 limits or output checks');
  console.log('CHAT_UPDATE_SPEED_OK');
  return result;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) summarize(process.argv[2]);
