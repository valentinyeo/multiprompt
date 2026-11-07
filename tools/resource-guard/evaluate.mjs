import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

export function evaluateResources(limits, baseline, candidate) {
  const failures = [];
  const fields = ['processes', 'syntheticSshProcesses', 'syntheticSshReaders', 'jobConsoleProcesses', 'workingSetBytes', 'idleCpuPercent'];
  if (!Number.isInteger(limits.sessionCount) || limits.sessionCount < 1 || !Number.isFinite(limits.resources?.memoryToleranceBytes) || limits.resources.memoryToleranceBytes < 0 || limits.resources.cardinalityGrowth !== 0) failures.push('invalid comparator policy');
  for (const [label, run] of [['baseline', baseline], ['candidate', candidate]]) {
    if (run?.workload !== limits.workload || run?.sessionCount !== limits.sessionCount || run?.readySessions !== limits.sessionCount || run?.cleaned !== true || run?.appAlive !== true || !Array.isArray(run?.rawProcesses) || run.rawProcesses.length !== run.processes || run?.jobActiveProcesses !== run.processes || run?.syntheticSshProcesses < 1 || run?.syntheticSshReaders < 1) failures.push(`${label}: incomplete workload or process evidence`);
    for (const field of fields) if (!Number.isFinite(run?.[field]) || run[field] < 0) failures.push(`${label}: missing ${field}`);
    for (const name of ['exe', 'bridge', 'config', 'helper']) {
      const file = run?.staging?.[name];
      if (!file?.inputPath || !file?.stagedPath || !/^[a-f0-9]{64}$/i.test(file?.inputSha256 || '') || file.inputSha256 !== file.stagedSha256) failures.push(`${label}: invalid ${name} staging evidence`);
    }
  }
  for (const name of ['config', 'helper']) if (!baseline?.staging?.[name]?.stagedSha256 || baseline.staging[name].stagedSha256 !== candidate?.staging?.[name]?.stagedSha256) failures.push(`telemetry ${name} differs between measurements`);
  for (const field of ['processes', 'syntheticSshProcesses', 'syntheticSshReaders', 'jobConsoleProcesses']) if (candidate?.[field] > baseline?.[field]) failures.push(`${field}: ${candidate[field]} exceeds baseline ${baseline[field]}`);
  if (candidate?.workingSetBytes > baseline?.workingSetBytes + limits.resources?.memoryToleranceBytes) failures.push(`workingSetBytes: ${candidate.workingSetBytes} exceeds baseline ${baseline.workingSetBytes} plus tolerance`);
  return failures;
}
export function evaluateLatency(limits, proof, metric) {
  const maximum = metric === 'typing' ? limits.latency.typingMs : limits.latency.sendPaintMs;
  const samples = proof?.latency?.[metric];
  if (!Number.isFinite(maximum) || maximum < 0 || proof?.cleaned !== true || proof?.appAlive !== true || !proof?.latency?.method?.[metric] || !Array.isArray(samples) || samples.length !== limits.sessionCount || new Set(samples.map(s => String(s.shellId))).size !== limits.sessionCount || samples.some(s => !Number.isFinite(s.elapsedMs) || s.elapsedMs < 0 || !proof.loadedShellIds?.map(String).includes(String(s.shellId)))) return { status: 'unmeasured', reason: 'valid samples from all loaded sessions required' };
  const worst = Math.max(...samples.map(s => s.elapsedMs));
  return { status: worst > maximum ? 'warning' : 'pass', worstMs: worst, limitMs: maximum };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const limits = JSON.parse(fs.readFileSync('tools/resource-guard/limits.json', 'utf8'));
  const read = file => { try { return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')); } catch { return null; } };
  const baseline = read('resource-evidence/baseline/measurement.json');
  const candidate = read('resource-evidence/candidate/measurement.json');
  const failures = evaluateResources(limits, baseline, candidate);
  const latency = { typing: evaluateLatency(limits, candidate, 'typing'), send: evaluateLatency(limits, candidate, 'send') };
  const fields = ['processes', 'syntheticSshProcesses', 'syntheticSshReaders', 'jobConsoleProcesses', 'workingSetBytes', 'idleCpuPercent'];
  let text = `## 30-session synthetic SSH resource guard: ${failures.length ? 'FAIL' : 'PASS'}\n\nBaseline: ${limits.baselineTag}; candidate and baseline on same host.\n\n| Metric | Baseline | Candidate |\n|---|---:|---:|\n`;
  for (const field of fields) text += `| ${field} | ${baseline?.[field] ?? 'MISSING'} | ${candidate?.[field] ?? 'MISSING'} |\n`;
  text += `\n${failures.map(x => `- ${x}`).join('\n')}\n\nCPU is informational. SSH processes are a synthetic proxy, not TCP connections. External console attribution is incomplete.\n`;
  for (const [metric, result] of Object.entries(latency)) text += `\n30-session ${metric}: ${result.status}${result.worstMs === undefined ? ` (${result.reason})` : ` (${result.worstMs} ms; target ${result.limitMs} ms)`}.\n`;
  fs.mkdirSync('resource-evidence', { recursive: true });
  fs.writeFileSync('resource-evidence/summary.md', text);
  fs.writeFileSync('resource-evidence/verdict.json', JSON.stringify({ failures, latency, baseline, candidate }, null, 2));
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, text);
  console.log(text);
  for (const [metric, result] of Object.entries(latency)) if (result.status !== 'pass') console.log(`::warning::${metric} latency ${result.status}`);
  if (failures.length) process.exitCode = 1;
}
