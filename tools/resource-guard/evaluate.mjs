import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

export function evaluateResources(limits, baseline, candidate) {
  const failures = [];
  const fields = ['processes', 'syntheticSshProcesses', 'syntheticSshReaders', 'jobConsoleProcesses', 'workingSetBytes', 'idleCpuPercent'];
  if (!Number.isInteger(limits.sessionCount) || limits.sessionCount < 1 || !Number.isFinite(limits.resources?.memoryToleranceBytes) || limits.resources.memoryToleranceBytes < 0 || limits.resources.cardinalityGrowth !== 0) failures.push('invalid comparator policy');
  for (const [label, run] of [['baseline', baseline], ['candidate', candidate]]) {
    if (run?.workload !== limits.workload || run?.sessionCount !== limits.sessionCount || run?.readySessions !== limits.sessionCount || run?.cleaned !== true || run?.appAlive !== true || !Array.isArray(run?.rawProcesses) || run.rawProcesses.length !== run.processes || run?.jobActiveProcesses !== run.processes || run?.syntheticSshProcesses < 1 || run?.syntheticSshReaders < 1) failures.push(`${label}: incomplete workload or process evidence`);
    for (const field of fields) if (!Number.isFinite(run?.[field]) || run[field] < 0) failures.push(`${label}: missing ${field}`);
  }
  for (const field of ['processes', 'syntheticSshProcesses', 'syntheticSshReaders', 'jobConsoleProcesses']) if (candidate?.[field] > baseline?.[field]) failures.push(`${field}: ${candidate[field]} exceeds baseline ${baseline[field]}`);
  if (candidate?.workingSetBytes > baseline?.workingSetBytes + limits.resources?.memoryToleranceBytes) failures.push(`workingSetBytes: ${candidate.workingSetBytes} exceeds baseline ${baseline.workingSetBytes} plus tolerance`);
  return failures;
}
export function evaluateLatency(limits, proof) {
  const maximum = limits.latency.sendPaintMs;
  if (!Number.isFinite(maximum) || maximum < 0 || !Array.isArray(proof?.samples) || proof.samples.length !== 20 || proof.samples.some(s => !Number.isFinite(s.paintedMs) || s.paintedMs < 0)) return { status: 'unmeasured', reason: '20 valid paint samples required' };
  const worst = Math.max(...proof.samples.map(s => s.paintedMs));
  return { status: worst > maximum ? 'warning' : 'pass', worstMs: worst, limitMs: maximum };
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const limits = JSON.parse(fs.readFileSync('tools/resource-guard/limits.json', 'utf8'));
  const read = file => { try { return JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '')); } catch { return null; } };
  const baseline = read('resource-evidence/baseline/measurement.json');
  const candidate = read('resource-evidence/candidate/measurement.json');
  const failures = evaluateResources(limits, baseline, candidate);
  const journey = read('resource-evidence/latency/result.json');
  const latency = journey?.scratchRemoved === true && journey.cleanup === 'owned process tree stopped; scratch copied to evidence/data then removed' && (journey.status === 'passed' || /^chat-send-latency: \d+ of 20 sends took longer/.test(journey.error || '')) ? evaluateLatency(limits, read('resource-evidence/latency/chat-send-latency.json')) : { status: 'unmeasured', reason: 'journey or cleanup evidence unavailable' };
  const fields = ['processes', 'syntheticSshProcesses', 'syntheticSshReaders', 'jobConsoleProcesses', 'workingSetBytes', 'idleCpuPercent'];
  let text = `## 30-session synthetic SSH resource guard: ${failures.length ? 'FAIL' : 'PASS'}\n\nBaseline: ${limits.baselineTag}; candidate and baseline on same host.\n\n| Metric | Baseline | Candidate |\n|---|---:|---:|\n`;
  for (const field of fields) text += `| ${field} | ${baseline?.[field] ?? 'MISSING'} | ${candidate?.[field] ?? 'MISSING'} |\n`;
  text += `\n${failures.map(x => `- ${x}`).join('\n')}\n\nCPU is informational. SSH processes are a synthetic proxy, not TCP connections. External console attribution is incomplete.\n\nSingle-session synthetic send paint: ${latency.status}${latency.worstMs === undefined ? ` (${latency.reason})` : ` (${latency.worstMs} ms; target ${latency.limitMs} ms)`}. Typing target ${limits.latency.typingMs} ms: unmeasured. Not hosted delivery or a 30-session latency measurement.\n`;
  fs.mkdirSync('resource-evidence', { recursive: true });
  fs.writeFileSync('resource-evidence/summary.md', text);
  fs.writeFileSync('resource-evidence/verdict.json', JSON.stringify({ failures, latency, baseline, candidate }, null, 2));
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, text);
  console.log(text);
  if (latency.status !== 'pass') console.log(`::warning::Send latency ${latency.status}`);
  if (failures.length) process.exitCode = 1;
}
