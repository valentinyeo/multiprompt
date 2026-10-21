import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

export const defaults = JSON.parse(fs.readFileSync(new URL('./config.json', import.meta.url)));
export const hash = file => crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
export const atomic = (file, data) => { fs.writeFileSync(`${file}.tmp`, data); fs.renameSync(`${file}.tmp`, file); };
export const winPath = file => `Z:${path.resolve(file).replaceAll('/', '\\')}`;
export const percentile = (values, p) => values.length ? [...values].sort((a, b) => a - b)[Math.ceil(values.length * p) - 1] : null;

export function parseArgs(argv, override = {}) {
  const options = { smoke: false };
  for (let i = 0; i < argv.length; i++) {
    const key = argv[i];
    if (key === '--smoke') { options.smoke = true; continue; }
    if (!['--exe', '--minutes', '--out', '--config'].includes(key) || !argv[i + 1] || argv[i + 1].startsWith('--')) throw new Error('Usage: node tools/chat-bench/run.mjs --exe <path> [--smoke] [--minutes N] [--out dir] [--config file]');
    options[key.slice(2)] = argv[++i];
  }
  if (!options.smoke && (options.minutes || options.config)) throw new Error('--minutes and --config require --smoke; install-laptop1.sh only accepts default-config receipts');
  const config = { ...defaults, ...override, rules: { ...defaults.rules, ...override.rules }, capacity: { ...defaults.capacity, ...override.capacity } };
  if (options.minutes) config.minutes = Number(options.minutes);
  for (const key of ['minutes', 'tabs', 'windows', 'width', 'height', 'warmupSeconds', 'switchSeconds', 'idleSettleSeconds', 'idleSeconds', 'appendSeconds', 'sampleMs', 'hangSeconds', 'startupSeconds']) {
    if (!Number.isFinite(config[key]) || config[key] <= 0) throw new Error(`Invalid config ${key}`);
  }
  for (const [key, value] of Object.entries(config.rules)) {
    if (!Number.isFinite(value) || value <= 0) throw new Error(`Invalid rule ${key}`);
  }
  for (const [key, value] of Object.entries(config.capacity)) {
    if (!Number.isFinite(value) || value <= 0) throw new Error(`Invalid capacity ${key}`);
  }
  if (![config.tabs, config.windows, config.width, config.height].every(Number.isInteger) || config.windows > config.tabs) throw new Error('Invalid fixture dimensions');
  return { options, config, installable: !options.smoke };
}

export function capacity(loadavgText, meminfoText, cores, config) {
  const load = Number(loadavgText.trim().split(/\s+/)[0]);
  const memAvailableMiB = Number(meminfoText.match(/^MemAvailable:\s+(\d+)\s+kB$/m)?.[1]) / 1024;
  const reasons = [];
  if (!(load < cores * config.capacity.maxLoadPerCore)) reasons.push(`load ${load} >= ${cores * config.capacity.maxLoadPerCore}`);
  if (!(memAvailableMiB >= config.capacity.minMemAvailableMiB)) reasons.push(`memory ${memAvailableMiB} MiB < ${config.capacity.minMemAvailableMiB} MiB`);
  return { ok: !reasons.length, load, cores, memAvailableMiB, reason: reasons.join('; ') };
}
export const isOutsideKill = signal => signal === 'SIGKILL';

const image = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';
export function records(provider, sid, turn, live = false) {
  const timestamp = new Date(Date.UTC(2026, 0, 1, 0, 0, turn)).toISOString();
  const question = live ? `LIVE-${turn}: new input in ${sid}` : `Turn ${turn} in ${sid}: examine the rendering and explain the result.`;
  const reply = `## ${sid} — ${live ? 'LIVE' : 'Fixture'} ${turn}\n\n` +
    'A real conversation paragraph with **bold**, *emphasis*, `inline code`, and a [safe link](https://example.invalid/bench).\n\n' +
    'The transcript includes enough visible conversational text to exercise wrapping, measurement, and paint. '.repeat(38) + '\n\n' +
    '| Case | Expected | Observed |\n| --- | --- | --- |\n| cold | readable | yes |\n| warm | cached | yes |\n\n' +
    '```zig\nconst greeting = "Hello, Kraków 世界";\n// CPU must settle after painting.\n```\n\n';
  if (provider === 'codex') return [
    { type: 'response_item', timestamp, payload: { type: 'message', role: 'user', id: `${sid}-u-${turn}`, content: [{ type: 'input_text', text: question }] } },
    { type: 'response_item', timestamp, payload: { type: 'function_call', name: 'exec_command', arguments: '{"cmd":"true"}', call_id: `${sid}-${turn}` } },
    { type: 'response_item', timestamp, payload: { type: 'function_call_output', call_id: `${sid}-${turn}`, output: 'ok' } },
    { type: 'response_item', timestamp, payload: { type: 'message', role: 'assistant', id: `${sid}-a-${turn}`, content: [{ type: 'output_text', text: reply }] } }
  ];
  const entry = (role, content, suffix) => ({ type: role, uuid: `${sid}-${suffix}-${turn}`, parentUuid: turn ? `${sid}-a-${turn - 1}` : null, sessionId: sid, cwd: '/bench/project', timestamp, isSidechain: false, message: { role, id: `${sid}-${suffix}-${turn}`, content } });
  return [
    entry('user', [{ type: 'text', text: question }, ...(turn % 17 ? [] : [{ type: 'image', source: { type: 'base64', media_type: 'image/png', data: image } }])], 'u'),
    entry('assistant', [{ type: 'tool_use', id: `${sid}-tool-${turn}`, name: 'Read', input: { file_path: '/bench/project/file.zig' } }], 'tool'),
    entry('user', [{ type: 'tool_result', tool_use_id: `${sid}-tool-${turn}`, content: 'Synthetic tool output, deliberately not conversation text. '.repeat(turn % 3 === 2 ? 1100 : 12) }], 'result'),
    ...(turn % 11 ? [] : [entry('user', [{ type: 'text', text: `<cross-session-message from-session="bench-other" from-name="Fixture peer">Cross-session update ${turn}: &lt;safe&gt; content.</cross-session-message>` }], 'injected')]),
    entry('assistant', [{ type: 'text', text: reply }], 'a')
  ];
}

export function generate(root, config = defaults) {
  const home = path.join(root, 'home');
  const sizes = [10_000, 100_000, 1_000_000, 5_000_000, 10_000_000, 25_000_000, 50_000_000];
  const tabs = [];
  for (let i = 0; i < config.tabs; i++) {
    const provider = i >= config.tabs - 2 ? 'shell' : i >= config.tabs - 4 ? 'codex' : 'claude';
    const sid = `${provider}-${String(i).padStart(3, '0')}`;
    const file = provider === 'claude' ? path.join(home, '.claude/projects/-bench-project', `${sid}.jsonl`) :
      provider === 'codex' ? path.join(home, '.codex/sessions/2026/01/01', `rollout-2026-01-01-${sid}.jsonl`) : null;
    let bytes = 0, turns = 0;
    const target = sizes[i % sizes.length];
    if (file) {
      fs.mkdirSync(path.dirname(file), { recursive: true });
      const fd = fs.openSync(file, 'w');
      if (provider === 'codex') {
        const meta = JSON.stringify({ type: 'session_meta', timestamp: '2026-01-01T00:00:00Z', payload: { id: sid, cwd: '/bench/project' } }) + '\n';
        bytes += fs.writeSync(fd, meta);
      }
      while (bytes < target) bytes += fs.writeSync(fd, records(provider, sid, turns++).map(r => JSON.stringify(r) + '\n').join(''));
      fs.closeSync(fd);
    }
    tabs.push({ index: i, provider, sid, file, initialBytes: bytes, targetBytes: target, turns, browser: config.browserTabs ? ["none", "pending", "docked"][i % 3] : "none" });
  }
  const instances = Array.from({ length: config.windows }, (_, index) => {
    const appdata = path.join(root, `appdata-${index}`), mailbox = path.join(root, `mailbox-${index}`), sshDir = path.join(root, `ssh-${index}`);
    fs.mkdirSync(path.join(appdata, 'ZigShell'), { recursive: true });
    fs.mkdirSync(mailbox, { recursive: true });
    fs.mkdirSync(sshDir, { recursive: true });
    atomic(path.join(appdata, 'ZigShell/ssh-path.txt'), winPath(path.join(root, 'ssh-fixture.exe')));
    const owned = tabs.filter(t => t.index % config.windows === index).sort((a, b) => a.initialBytes - b.initialBytes);
    const session = { hide_pills: false, active_tab: 0, single_window: false, chat_view_mode: 'everywhere', chat_active: true, tabs: owned.map(t => ({
      kind: t.file ? 'tmux' : 'cmd', name: `Bench ${t.sid}`, manual: true, cv: true, cwd: 'C:\\', pid: 0,
      ...(t.file ? { tmux_session: t.sid, csid: t.sid, ccwd: '/bench/project' } : {})
    })) };
    atomic(path.join(appdata, 'ZigShell/session.json'), JSON.stringify(session));
    atomic(path.join(appdata, `ZigShell/session-bench-${index}.json`), JSON.stringify(session));
    return { index, appdata, mailbox, sshDir, tabs: owned };
  });
  const manifest = { home, tabs, instances };
  atomic(path.join(root, 'fixtures.json'), JSON.stringify(manifest, null, 2));
  return manifest;
}

export function parseLog(text) {
  const paints = [...text.matchAll(/\[bench\] painted seq=(\d+) tab=(\d+) ms=(\d+) blocks=(\d+) chars=(\d+) first=(\d+) file=(\d+)/g)].map(m => ({ seq: +m[1], tab: +m[2], ms: +m[3], blocks: +m[4], chars: +m[5], first: !!+m[6], file: !!+m[7] }));
  const heartbeat = [...text.matchAll(/\[bench\] heartbeat seq=(\d+) tabs=(\d+) active=(\d+)/g)].at(-1);
  const perf = [...text.matchAll(/PERF[^\r\n]*/g)].map(m => m[0]);
  const switches = [...text.matchAll(/\[switch\][^\r\n]*/g)].map(m => m[0]);
  const chat = [...text.matchAll(/\[chat\][^\r\n]*/g)].map(m => m[0]);
  return { paints, heartbeat: heartbeat ? { seq: +heartbeat[1], tabs: +heartbeat[2], active: +heartbeat[3] } : null, perf, switches, chat };
}

export function procSnapshot(prefix, exe, proc = '/proc', ownedPids = new Map()) {
  const result = new Map();
  const image = new RegExp(`(?:^|/)${path.basename(exe).replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?:$|[\\s"])`, 'i');
  for (const pid of fs.readdirSync(proc).filter(n => /^\d+$/.test(n))) {
    try {
      if (!/\/wine(?:64)?(?:-preloader)?$/.test(fs.readlinkSync(`${proc}/${pid}/exe`))) continue;
      const stat = fs.readFileSync(`${proc}/${pid}/stat`, 'utf8');
      const fields = stat.slice(stat.lastIndexOf(')') + 2).trim().split(/\s+/);
      if (fields[0] === 'Z' || fields.length < 22) continue;
      const owned = ownedPids.has(+pid) && ownedPids.get(+pid) === fields[19];
      const cmd = fs.readFileSync(`${proc}/${pid}/cmdline`, 'utf8').split('\0');
      if (!owned && !cmd.some(arg => image.test(arg.replaceAll('\\', '/')))) continue;
      const env = fs.readFileSync(`${proc}/${pid}/environ`, 'utf8').split('\0');
      if (!owned && !env.includes(`WINEPREFIX=${prefix}`)) continue;
      result.set(+pid, { ticks: +fields[11] + +fields[12], rssPages: +fields[21], start: fields[19], gui: owned || !/(?:^|\s)--usage-telemetry(?:\s|$)/.test(cmd.join(' ')) });
    } catch {  }
  }
  return result;
}

export function cpuDelta(previous, current, elapsedMs, hz, pageSize) {
  let ticks = 0, rss = 0;
  for (const [pid, value] of current) {
    rss += value.rssPages * pageSize;
    const old = previous.get(pid);
    if (old?.start === value.start) ticks += Math.max(0, value.ticks - old.ticks);
  }
  return { cpu: ticks / hz / (elapsedMs / 1000) * 100, rssBytes: rss, pids: [...current.keys()] };
}

export function imageInk(rgb) {
  if (!rgb.length || rgb.length % 3) throw new Error('Invalid RGB capture');
  const counts = new Map();
  for (let i = 0; i < rgb.length; i += 3) {
    const color = (rgb[i] >> 3) * 1024 + (rgb[i + 1] >> 3) * 32 + (rgb[i + 2] >> 3);
    counts.set(color, (counts.get(color) || 0) + 1);
  }
  return { colors: counts.size, inkPixels: rgb.length / 3 - Math.max(...counts.values()) };
}

export function geometryInside(geometry) {
  if (!geometry) return false;
  const inside = rect => !!rect && rect.left >= geometry.pane_left && rect.right <= geometry.pane_right && rect.right > rect.left;
  const aligned = (a, b) => ['left', 'right', 'top', 'bottom'].every(k => Math.abs(a[k] - b[k]) <= 1);
  return [geometry.title, geometry.layout.transcript, geometry.layout.composer_card, geometry.layout.attach_btn, geometry.layout.send_btn, geometry.transcript, geometry.composer].every(inside) && aligned(geometry.transcript, geometry.layout.transcript) && aligned(geometry.composer, geometry.layout.composer);
}

export function evaluate(run, config) {
  const infra = (run.infra || []).filter(f => !(run.oomKills > 0 && f.includes('killed by SIGKILL from outside the bench')));
  const failures = [...run.errors.filter(f => !(run.oomKills > 0 && f.includes('killed by SIGKILL from outside the bench'))), ...infra];
  const samples = run.samples.filter(s => s.measured);
  const idle = samples.filter(s => s.idle);
  const weighted = rows => rows.length ? rows.reduce((n, s) => n + s.cpu * s.elapsedMs, 0) / rows.reduce((n, s) => n + s.elapsedMs, 0) : null;
  const windowPeak = milliseconds => {
    let peak = null;
    for (let i = 0; i < samples.length; i++) {
      const end = samples[i].timeMs;
      let weight = 0, sum = 0;
      for (let j = i; j >= 0 && samples[j].timeMs > end - milliseconds && samples[j].phase === samples[i].phase; j--) {
        const s = samples[j];
        const duration = Math.min(s.elapsedMs, s.timeMs - (end - milliseconds));
        weight += duration; sum += duration * s.cpu;
      }
      if (weight >= milliseconds - 10) peak = Math.max(peak ?? 0, sum / weight);
    }
    return peak;
  };
  const fiveSecondPeakCpu = windowPeak(5000);
  const thirtySecondPeakCpu = windowPeak(30000);
  const completePaintP95 = rows => rows.length && rows.every(s => Number.isFinite(s.firstPaintMs)) ? percentile(rows.map(s => s.firstPaintMs), .95) : null;
  const metrics = { idleAverageCpu: weighted(idle), averageCpu: weighted(samples), peakCpu: samples.length ? Math.max(...samples.map(s => s.cpu)) : null,
    fiveSecondPeakCpu, thirtySecondPeakCpu, peakRssMiB: samples.length ? Math.max(...samples.map(s => s.rssBytes)) / 1048576 : null,
    averageRssMiB: samples.length ? samples.reduce((n, s) => n + s.rssBytes, 0) / samples.length / 1048576 : null,
    switchPaintP95Ms: completePaintP95(run.switches),
    acknowledgedPaintP95Ms: percentile(run.switches.map(s => s.firstPaintMs).filter(Number.isFinite), .95),
    switchContentP95Ms: percentile(run.switches.map(s => s.contentPaintMs).filter(Number.isFinite), .95),
    coldPaintP95Ms: completePaintP95(run.switches.filter(s => s.phase === 'cold')),
    warmPaintP95Ms: completePaintP95(run.switches.filter(s => s.phase === 'warm')),
    warmContentP95Ms: percentile(run.switches.filter(s => s.phase === 'warm' && run.fixtures.tabs.find(t => t.index === s.index)?.file).map(s => s.contentPaintMs).filter(Number.isFinite), .95),
    idleSamples: idle.length, samples: samples.length };
  const rules = config.rules;
  const memoryExceeded = run.oomKills > 0 || metrics.peakRssMiB > rules.maxRssMiB;
  if (run.oomKills > 0) failures.push(`memory cap ${rules.maxRssMiB} MiB exceeded (${run.oomKills} process(es) killed by the bench's own memory limit)`);
  else if (memoryExceeded) failures.push(`memory cap ${rules.maxRssMiB} MiB exceeded (peak RSS ${metrics.peakRssMiB} MiB)`);
  if (idle.length < rules.minimumIdleSamples || metrics.idleAverageCpu === null) failures.push('insufficient idle CPU evidence');
  else if (metrics.idleAverageCpu >= rules.idleAverageCpuPercent) failures.push('idle average CPU');
  if (thirtySecondPeakCpu === null) failures.push('insufficient thirty-second CPU evidence');
  else if (thirtySecondPeakCpu > rules.maxThirtySecondCpuPercent) failures.push('thirty-second CPU');
  if (metrics.switchPaintP95Ms === null || metrics.switchPaintP95Ms >= rules.switchPaintP95Ms) failures.push('switch paint p95');
  for (const phase of ['cold', 'warm']) for (const tab of run.fixtures.tabs) {
    if (!run.switches.some(s => s.phase === phase && s.index === tab.index && s.screenshot && s.nonEmpty && Number.isFinite(s.firstPaintMs))) failures.push(`${phase} tab ${tab.index}: missing paint/non-empty screenshot`);
  }
  if (config.browserTabs) {
    for (const mode of ['pending', 'docked']) {
      if (!run.switches.some(s => run.fixtures.tabs.find(t => t.index === s.index)?.browser === mode)) failures.push(`missing ${mode} browser coverage`);
    }
    for (const shot of run.switches) {
      if (run.fixtures.tabs.find(t => t.index === shot.index)?.browser === 'docked' && (!shot.geometry?.browser_foreign || !shot.geometry?.browser_live)) failures.push(`${shot.phase} tab ${shot.index}: missing foreign docked browser HWND`);
      if (Number.isFinite(shot.foreignBrowsersOnScreen) && shot.foreignBrowsersOnScreen > rules.maxForeignBrowsersOnScreen) failures.push(`${shot.phase} tab ${shot.index}: ${shot.foreignBrowsersOnScreen} browser panes on screen`);
      if (!Number.isFinite(shot.foreignBrowsersOnScreen)) failures.push(`${shot.phase} tab ${shot.index}: browser panes on screen not counted`);
      if (!shot.geometryInside || !shot.headerInk || !shot.composerInk) failures.push(`${shot.phase} tab ${shot.index}: header/composer outside chat pane or missing screenshot ink`);
      if (shot.phase === 'warm' && run.fixtures.tabs.find(t => t.index === shot.index)?.file && (!Number.isFinite(shot.contentPaintMs) || shot.contentPaintMs >= rules.cachedPaintP95Ms || !shot.earlyContent)) failures.push(`warm tab ${shot.index}: cached rows delayed behind remote fetch`);
      if (shot.phase === 'cold' && run.fixtures.tabs.find(t => t.index === shot.index)?.file && !shot.earlyContent && !shot.loadingInk) failures.push(`cold tab ${shot.index}: blank loading state`);
    }
  }
  if (!run.restarted) failures.push('missing restart');
  if (!run.appends.length || !run.readerResponses.some(r => r.hasLive)) failures.push('missing observed live append');
  if (!run.readerResponses.length || run.readerResponses.some(r => r.error)) failures.push('fixture transport failure');
  for (const tab of run.fixtures.tabs.filter(t => t.file)) {
    if (!run.readerResponses.some(r => r.sid === tab.sid && r.ok)) failures.push(`transcript ${tab.sid} never parsed by production reader`);
  }
  return { pass: failures.length === 0, status: failures.length === 0 ? 'PASS' : !memoryExceeded && infra.length ? 'INFRA' : 'FAIL', failures: [...new Set(failures)], metrics };
}
