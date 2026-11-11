import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const mode = process.argv[2];
const session = 'ht-or-runner-3';
const fixes = {
  'v0.28.1672': 'c1f9306428',
  'v0.28.1673': '5ac02e51d3',
};

function run(cmd, args, timeout, env) {
  return execFileSync(cmd, args, {
    encoding: 'utf8',
    timeout,
    maxBuffer: 8 * 1024 * 1024,
    env,
  });
}

function lh(script) {
  return run('lh', ['shell', script, '--timeout', '90'], 120000).replace(/\r/g, '').trim();
}

function releaseSums(tag) {
  const dir = mkdtempSync(join(tmpdir(), 'igsh-1892-'));
  try {
    run('gh', ['release', 'download', tag, '--repo', 'valentinyeo/multiprompt', '--pattern', 'SHA256SUMS.txt', '--dir', dir], 60000);
    const text = readFileSync(join(dir, 'SHA256SUMS.txt'), 'utf8');
    const line = text.split(/\n/).find((row) => row.endsWith('multiprompt-x64.exe'));
    if (!line) throw new Error(`missing x64 sum for ${tag}`);
    return line.slice(0, 64).toLowerCase();
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

function identity() {
  const raw = lh(`
$ErrorActionPreference='Stop'
$root = Join-Path $env:USERPROFILE 'Documents\\GitHub\\zigshell\\zig-out\\bin'
$exe = Join-Path $root 'multiprompt.exe'
$disk = (Get-FileHash -Algorithm SHA256 $exe).Hash.ToLower()
$procs = @(Get-CimInstance Win32_Process -Filter "Name='multiprompt.exe'" | ForEach-Object {
  $hash = ''
  if ($_.ExecutablePath) { $hash = (Get-FileHash -Algorithm SHA256 $_.ExecutablePath).Hash.ToLower() }
  [pscustomobject]@{ Id=$_.ProcessId; Start=$_.CreationDate.ToUniversalTime().ToString('o'); Path=$_.ExecutablePath; Hash=$hash }
})
[pscustomobject]@{ Disk=$disk; Procs=$procs } | ConvertTo-Json -Compress
`);
  const info = JSON.parse(raw);
  const procs = Array.isArray(info.Procs) ? info.Procs : info.Procs ? [info.Procs] : [];
  const sums = Object.fromEntries(Object.keys(fixes).map((tag) => [tag, releaseSums(tag)]));
  const diskTag = Object.entries(sums).find(([, sum]) => sum === info.Disk)?.[0] ?? 'none';
  const runningTags = [...new Set(procs.map((proc) => Object.entries(sums).find(([, sum]) => sum === proc.Hash)?.[0] ?? 'other'))];
  console.log(`disk=${info.Disk} diskTag=${diskTag}`);
  for (const proc of procs) {
    const tag = Object.entries(sums).find(([, sum]) => sum === proc.Hash)?.[0] ?? 'other';
    console.log(`proc id=${proc.Id} start=${proc.Start} tag=${tag} path=${proc.Path} hash=${proc.Hash}`);
  }
  const fixedRunning = procs.some((proc) => Object.values(sums).includes(proc.Hash));
  if (!fixedRunning) {
    console.error('IGSH-1892 identity fail: running process is not v0.28.1672 or v0.28.1673');
    process.exit(1);
  }
  console.log(`runningTags=${runningTags.join(',')}`);
  console.log('IGSH-1892 identity pass');
}

function zsb(args, timeoutSec) {
  const timeoutMs = Math.ceil((timeoutSec + 5) * 1000);
  const env = { ...process.env, TMUX: '', ZSB_SESSION: session, ZSB_TIMEOUT: String(timeoutSec) };
  let last;
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    try {
      return run('zsb', args, timeoutMs, env);
    } catch (error) {
      last = error;
      const text = `${error.stdout ?? ''}\n${error.stderr ?? ''}`;
      if (attempt === 4 || !/empty_reply|reply_timeout/.test(text)) throw error;
      console.log(`retry ${args[0]} after ${text.includes('empty_reply') ? 'empty_reply' : 'reply_timeout'}`);
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 2000);
    }
  }
  throw last;
}

function parseJson(text) {
  const start = text.indexOf('{');
  const list = text.indexOf('[');
  const at = start >= 0 && (list < 0 || start < list) ? start : list;
  if (at < 0) throw new Error(text.slice(0, 400));
  return JSON.parse(text.slice(at));
}

function pane() {
  const text = zsb(['pane-info'], 25);
  const body = parseJson(text);
  console.log(text.trim());
  return body.result ?? body;
}

function tabs() {
  const text = zsb(['tabs'], 25);
  console.log(text.trim());
  const body = parseJson(text);
  const result = body.result ?? body;
  const list = Array.isArray(result) ? result : result.tabs;
  if (!Array.isArray(list) || list.length === 0) throw new Error('no tabs');
  return list;
}

function pageRead() {
  const list = tabs();
  const tab = list.find((item) => item.target) ?? list.find((item) => String(item.url ?? '').startsWith('http')) ?? list[0];
  const text = zsb(['eval', 'location.href', '--tab', String(tab.id)], 30);
  console.log(text.trim());
  const body = parseJson(text);
  const value = body.result ?? body;
  if (typeof value !== 'string' || !/^https?:/.test(value)) throw new Error('page read was not an http URL');
  return value;
}

function probe() {
  const info = pane();
  const id = info.windowId ?? 0;
  if (!(id > 0)) {
    console.error('IGSH-1892 probe fail: no window');
    process.exit(1);
  }
  const href = pageRead();
  console.log(`window=${id} href=${href}`);
  console.log('IGSH-1892 probe pass');
}

function recover() {
  const before = pane();
  const beforeId = before.windowId ?? 0;
  if (!(beforeId > 0)) {
    console.log('pane missing before recovery call');
  } else {
    const closed = lh(`
$ErrorActionPreference='Stop'
$wid = ${Number(beforeId)}
$closed = $false
Get-Process msedge,chrome,msedgewebview2 -ErrorAction SilentlyContinue | Out-Null
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class WinClose { [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam); }'
Get-Process | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object {
  $title = $_.MainWindowTitle
  if ($title -match [regex]::Escape([string]$wid)) {
    [void][WinClose]::PostMessage($_.MainWindowHandle, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $closed = $true
    Write-Output ("closed-title=" + $title)
  }
}
if (-not $closed) { Write-Output 'close-skipped-no-title-match' }
`);
    console.log(closed);
    if (!closed.includes('closed-title=')) {
      console.error('IGSH-1892 recover fail: refused to close a window without this pane id in the title');
      process.exit(1);
    }
  }
  const opened = zsb(['open', 'https://example.com/'], 40);
  console.log(opened.trim());
  let after = pane();
  let afterId = after.windowId ?? 0;
  const waitUntil = Date.now() + 45000;
  while (!(afterId > 0) && Date.now() < waitUntil) {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 3000);
    after = pane();
    afterId = after.windowId ?? 0;
  }
  if (!(afterId > 0)) {
    console.error('IGSH-1892 recover fail: pane did not reopen');
    process.exit(1);
  }
  const href = pageRead();
  if (!href.startsWith('http')) {
    console.error('IGSH-1892 recover fail: page read was not a URL');
    process.exit(1);
  }
  console.log(`before=${beforeId} after=${afterId} href=${href}`);
  console.log('IGSH-1892 recover pass');
}

function soak() {
  const started = Date.now();
  const limit = 15 * 60 * 1000;
  let n = 0;
  while (Date.now() - started < limit) {
    n += 1;
    const info = pane();
    const id = info.windowId ?? 0;
    if (!(id > 0)) throw new Error(`drop at call ${n}: no window`);
    const href = pageRead();
    if (!href.startsWith('http')) throw new Error(`drop at call ${n}: bad href`);
    const elapsed = Math.round((Date.now() - started) / 1000);
    console.log(`soak n=${n} elapsed=${elapsed}s window=${id}`);
    const remain = limit - (Date.now() - started);
    if (remain <= 0) break;
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, Math.min(20000, remain));
  }
  const minutes = (Date.now() - started) / 60000;
  if (minutes < 15 || n < 2) {
    console.error(`IGSH-1892 soak fail: minutes=${minutes} calls=${n}`);
    process.exit(1);
  }
  console.log(`calls=${n} minutes=${minutes.toFixed(2)}`);
  console.log('IGSH-1892 soak pass');
}

function soakAudit() {
  const text = readFileSync(new URL('./soak.log', import.meta.url), 'utf8');
  const calls = [...text.matchAll(/^soak n=(\d+) elapsed=(\d+)s window=(\d+)$/gm)];
  const summary = text.match(/^calls=(\d+) minutes=([0-9.]+)$/m);
  const windows = new Set(calls.map((match) => match[3]));
  const lastElapsed = calls.length ? Number(calls[calls.length - 1][2]) : 0;
  if (!summary || !text.includes('IGSH-1892 soak pass') || calls.length < 2 || windows.size !== 1 || windows.has('0') || Number(summary[1]) !== calls.length || Number(summary[2]) < 15 || lastElapsed < 840) {
    console.error(`IGSH-1892 soak fail: lines=${calls.length} windows=${[...windows].join(',')} last=${lastElapsed}`);
    process.exit(1);
  }
  console.log(`calls=${summary[1]} minutes=${summary[2]} window=${[...windows][0]}`);
  console.log('IGSH-1892 soak pass');
}

if (mode === 'identity') identity();
else if (mode === 'probe') probe();
else if (mode === 'recover') recover();
else if (mode === 'soak') soak();
else if (mode === 'soak-audit') soakAudit();
else {
  console.error('usage: live-check.mjs identity|probe|recover|soak');
  process.exit(2);
}
