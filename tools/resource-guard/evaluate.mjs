import fs from 'node:fs';
import { isIP } from 'node:net';
import { pathToFileURL } from 'node:url';

export function evaluateResources(limits, baseline, candidate) {
  const failures = [];
  const fields = ['processes', 'syntheticSshProcesses', 'syntheticSshReaders', 'jobConsoleProcesses', 'workingSetBytes', 'idleCpuPercent', 'establishedTcpConnections'];
  if (!Number.isInteger(limits.sessionCount) || limits.sessionCount < 1 || !Number.isFinite(limits.resources?.memoryToleranceBytes) || limits.resources.memoryToleranceBytes < 0 || limits.resources.cardinalityGrowth !== 0) failures.push('invalid comparator policy');
  for (const [label, run] of [['baseline', baseline], ['candidate', candidate]]) {
    if (run?.workload !== limits.workload || run?.sessionCount !== limits.sessionCount || run?.readySessions !== limits.sessionCount || run?.cleaned !== true || run?.appAlive !== true || !Array.isArray(run?.rawProcesses) || run.rawProcesses.length !== run.processes || run?.jobActiveProcesses !== run.processes || run?.syntheticSshProcesses < 1 || run?.syntheticSshReaders < 1) failures.push(`${label}: incomplete workload or process evidence`);
    for (const field of fields) if (!Number.isFinite(run?.[field]) || run[field] < 0) failures.push(`${label}: missing ${field}`);
    const ownedIds = new Set((Array.isArray(run?.rawProcesses) ? run.rawProcesses : []).map(process => process?.id));
    const tcp = run?.rawTcpConnections;
    const validPid = id => Number.isSafeInteger(id) && id > 0;
    const port = value => Number.isInteger(value) && value > 0 && value <= 65535;
    const validRow = row => row && row.state === 5 && validPid(row.owningProcess) && ownedIds.has(row.owningProcess) && typeof row.localAddress === 'string' && isIP(row.localAddress) && typeof row.remoteAddress === 'string' && isIP(row.remoteAddress) && port(row.localPort) && port(row.remotePort);
    const keys = Array.isArray(tcp) ? tcp.map(row => JSON.stringify([row?.owningProcess, row?.localAddress, row?.localPort, row?.remoteAddress, row?.remotePort])) : [];
    if (!Array.isArray(tcp) || !Number.isSafeInteger(run?.establishedTcpConnections) || run.establishedTcpConnections !== tcp.length || tcp.some(row => !validRow(row)) || new Set(keys).size !== keys.length || ownedIds.size !== run?.rawProcesses?.length || [...ownedIds].some(id => !validPid(id))) failures.push(`${label}: invalid TCP connection evidence`);
    const consoles = run?.associatedExternalConsoles;
    if (!Array.isArray(consoles) || new Set(consoles.map(console => console?.ProcessId)).size !== consoles.length || consoles.some(console => !Number.isSafeInteger(console?.ProcessId) || console.ProcessId <= 0 || !Number.isSafeInteger(console.ParentProcessId) || console.ParentProcessId <= 0 || !ownedIds.has(console.ParentProcessId) || ownedIds.has(console.ProcessId) || !/^(conhost|OpenConsole)\.exe$/i.test(console.Name || ''))) failures.push(`${label}: invalid associatedExternalConsoles evidence`);
    for (const name of ['exe', 'bridge', 'config', 'helper']) {
      const file = run?.staging?.[name];
      if (!file?.inputPath || !file?.stagedPath || !/^[a-f0-9]{64}$/i.test(file?.inputSha256 || '') || file.inputSha256 !== file.stagedSha256) failures.push(`${label}: invalid ${name} staging evidence`);
    }
  }
  for (const name of ['config', 'helper']) if (!baseline?.staging?.[name]?.stagedSha256 || baseline.staging[name].stagedSha256 !== candidate?.staging?.[name]?.stagedSha256) failures.push(`telemetry ${name} differs between measurements`);
  for (const field of ['processes', 'syntheticSshProcesses', 'syntheticSshReaders', 'jobConsoleProcesses', 'establishedTcpConnections']) if (candidate?.[field] > baseline?.[field]) failures.push(`${field}: ${candidate[field]} exceeds baseline ${baseline[field]}`);
  if (Array.isArray(candidate?.associatedExternalConsoles) && Array.isArray(baseline?.associatedExternalConsoles) && candidate.associatedExternalConsoles.length > baseline.associatedExternalConsoles.length) failures.push(`associatedExternalConsoles: ${candidate.associatedExternalConsoles.length} exceeds baseline ${baseline.associatedExternalConsoles.length}`);
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
  const fields = ['processes', 'syntheticSshProcesses', 'syntheticSshReaders', 'jobConsoleProcesses', 'workingSetBytes', 'idleCpuPercent', 'establishedTcpConnections'];
  let text = `## 30-session synthetic SSH resource guard: ${failures.length ? 'FAIL' : 'PASS'}\n\nBaseline: ${limits.baselineTag}; candidate and baseline on same host.\n\n| Metric | Baseline | Candidate |\n|---|---:|---:|\n`;
  for (const field of fields) text += `| ${field} | ${baseline?.[field] ?? 'MISSING'} | ${candidate?.[field] ?? 'MISSING'} |\n`;
  text += `| associatedExternalConsoles | ${Array.isArray(baseline?.associatedExternalConsoles) ? baseline.associatedExternalConsoles.length : 'MISSING'} | ${Array.isArray(candidate?.associatedExternalConsoles) ? candidate.associatedExternalConsoles.length : 'MISSING'} |\n`;
  text += `\n${failures.map(x => `- ${x}`).join('\n')}\n\nCPU is informational. Synthetic SSH does not use TCP; TCP counts cover all established connections owned by the job. External console attribution is incomplete.\n`;
  for (const [metric, result] of Object.entries(latency)) text += `\n30-session ${metric}: ${result.status}${result.worstMs === undefined ? ` (${result.reason})` : ` (${result.worstMs} ms; target ${result.limitMs} ms)`}.\n`;
  fs.mkdirSync('resource-evidence', { recursive: true });
  fs.writeFileSync('resource-evidence/summary.md', text);
  fs.writeFileSync('resource-evidence/verdict.json', JSON.stringify({ failures, latency, baseline, candidate }, null, 2));
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, text);
  console.log(text);
  for (const [metric, result] of Object.entries(latency)) if (result.status !== 'pass') console.log(`::warning::${metric} latency ${result.status}`);
  if (failures.length) process.exitCode = 1;
}
