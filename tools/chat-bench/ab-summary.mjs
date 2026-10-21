import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

function stats(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return {
    median: sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2,
    min: sorted[0],
    max: sorted.at(-1),
    spread: sorted.at(-1) - sorted[0],
  };
}

export function summarize(runs) {
  if (!Array.isArray(runs) || !runs.length) throw new Error('No benchmark runs');
  const groups = ['A', 'B'].map(label => {
    const rows = runs.filter(run => run.label === label);
    if (!rows.length) throw new Error(`Missing ${label} runs`);
    const tag = rows[0].tag;
    if (typeof tag !== 'string' || !/^v\d+\.\d+\.\d+$/.test(tag)) throw new Error('Invalid release tag');
    if (rows.some(row => row.tag !== tag)) throw new Error(`Mixed tags for ${label}`);
    const paint = [], failures = [];
    for (const row of rows) {
      const result = row.result;
      if (!['PASS', 'FAIL'].includes(result?.status)) throw new Error('Incomplete or infrastructure result');
      const p95 = result.metrics?.switchPaintP95Ms;
      if (!Number.isFinite(p95) || p95 < 0) throw new Error('Missing or invalid switch paint p95');
      if (!Array.isArray(result.failures) || result.failures.some(failure => typeof failure !== 'string')) throw new Error('Invalid failed checks');
      if (result.status === 'PASS' && result.failures.length) throw new Error('Inconsistent PASS result');
      paint.push(p95);
      failures.push(result.failures.length);
    }
    return { label, tag, runs: rows.length, switchPaintP95Ms: stats(paint), failedChecks: stats(failures) };
  });
  if (runs.some(run => !['A', 'B'].includes(run.label)) || groups[0].runs !== groups[1].runs) throw new Error('Unbalanced A/B runs');
  const difference = Object.fromEntries(['switchPaintP95Ms', 'failedChecks'].map(metric => {
    const [a, b] = groups.map(group => group[metric]);
    const delta = b.median - a.median;
    return [metric, {
      medianBMinusA: delta,
      withinTagSpread: Math.max(a.spread, b.spread),
      exceedsWithinTagSpread: Math.abs(delta) > Math.max(a.spread, b.spread),
    }];
  }));
  return { schema: 1, environment: 'Linux/Wine on a GitHub-hosted Windows runner (WSL2)', groups, difference };
}

export function markdown(summary) {
  const lines = [
    '# Chat bench A/B',
    '',
    summary.environment,
    '',
    '| Tag | Runs | Switch paint p95 ms: median [min, max] | Failed checks: median [min, max] |',
    '| --- | ---: | ---: | ---: |',
  ];
  const format = value => `${value.median} [${value.min}, ${value.max}]`;
  for (const group of summary.groups) lines.push(`| ${group.label}: ${group.tag} | ${group.runs} | ${format(group.switchPaintP95Ms)} | ${format(group.failedChecks)} |`);
  lines.push('', '| Metric | Median B − A | Largest within-tag range | Gap exceeds both ranges? |', '| --- | ---: | ---: | --- |');
  for (const [metric, value] of Object.entries(summary.difference)) lines.push(`| ${metric} | ${value.medianBMinusA} | ${value.withinTagSpread} | ${value.exceedsWithinTagSpread ? 'yes' : 'no'} |`);
  lines.push('', 'Spread is max − min; the gap comparison is descriptive, not a significance test.', 'Benchmark acceptance failures are counted, not treated as workflow infrastructure failures.', '');
  return lines.join('\n');
}

if (process.argv[1] && pathToFileURL(process.argv[1]).href === import.meta.url) {
  const [manifestFile, out] = process.argv.slice(2);
  if (!manifestFile || !out || process.argv.length !== 4) throw new Error('Usage: ab-summary.mjs <manifest.json> <output-directory>');
  const manifest = JSON.parse(fs.readFileSync(manifestFile, 'utf8'));
  const runs = manifest.map(run => ({ ...run, result: JSON.parse(fs.readFileSync(path.resolve(path.dirname(manifestFile), run.path), 'utf8')) }));
  const summary = summarize(runs);
  fs.mkdirSync(out, { recursive: true });
  fs.writeFileSync(path.join(out, 'summary.json'), JSON.stringify({ ...summary, runs: manifest }, null, 2) + '\n');
  const text = markdown(summary);
  fs.writeFileSync(path.join(out, 'summary.md'), text);
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, text);
  console.log(text);
}
