import assert from 'node:assert/strict';
import { execFile, spawn } from 'node:child_process';
import { once } from 'node:events';
import fs from 'node:fs/promises';
import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { createRequire } from 'node:module';
import { promisify } from 'node:util';

assert.equal(process.env.GITHUB_ACTIONS, 'true', 'Run only through GitHub verify.yml');
assert.equal(process.platform, 'win32', 'Run only on the GitHub Windows desktop');
const exec = promisify(execFile);
const evidence = path.resolve('evidence');
const scratch = await fs.mkdtemp(path.join(os.tmpdir(), 'zsb-emulation-'));
const exe = path.resolve('verify-bin/zigshell-bridge.exe');
const extension = path.resolve('extension');
const require = createRequire(path.join(process.env.VERIFY_BROWSER_MODULE, 'package.json'));
const chrome = require('puppeteer').executablePath();
const registry = 'HKCU\\Software\\Google\\Chrome\\NativeMessagingHosts\\com.zigshell.bridge';
const actions = [];
const requests = [];
const result = { feature: 'browser-emulation', status: 'failed', checks: [], boundary: 'Real Chrome for Testing, unpacked extension and native zsb CLI; not the embedded pane, SSH tunnel, browser-chrome keys or DevTools.' };
let browser;
let socket;
let registered = false;
let windowId;
let sequence = 0;
const pending = new Map();
const server = http.createServer((request, response) => {
  requests.push({ url: request.url, userAgent: request.headers['user-agent'] });
  response.writeHead(200, { 'Content-Type': 'text/html', 'Cache-Control': 'no-store' });
  response.end('<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><title>Device preview verification</title><style>body{font:20px sans-serif;background:#eef4ff;color:#123;padding:16px}main{max-width:600px}a{display:block;padding:24px;background:#cde}</style><main><h1>Device preview verification</h1><p>This synthetic page checks persistent mobile previews.</p><a id="next" href="/next">Navigate to the next page</a><pre id="state"></pre></main><script>function update(){document.querySelector("#state").textContent=JSON.stringify({width:innerWidth,height:innerHeight,touch:navigator.maxTouchPoints,userAgent:navigator.userAgent},null,2)}update();addEventListener("resize",update)</script>');
});

async function waitFor(check, label, timeout = 60000) {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const value = await check();
    if (value) return value;
    await new Promise(resolve => setTimeout(resolve, 200));
  }
  throw new Error(`Timed out: ${label}`);
}

async function cdp(method, params = {}) {
  const id = ++sequence;
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`${method} timed out`)); }, 15000);
    pending.set(id, { resolve(value) { clearTimeout(timer); resolve(value); }, reject(error) { clearTimeout(timer); reject(error); } });
    socket.send(JSON.stringify({ id, method, params }));
  });
}

async function cli(args, scoped = true) {
  const command = scoped ? ['--window', String(windowId), ...args] : args;
  const { stdout, stderr } = await exec(exe, command, { timeout: 45000, maxBuffer: 16 * 1024 * 1024 });
  assert.equal(stderr, '');
  actions.push({ arguments: command, reply: stdout });
  if (!scoped) return stdout;
  const response = JSON.parse(stdout);
  assert.equal(response.ok, true, stdout);
  return response.result;
}

async function measure(name) {
  const state = await cli(['eval', '({width:innerWidth,height:innerHeight,screenWidth:screen.width,screenHeight:screen.height,userAgent:navigator.userAgent,touch:navigator.maxTouchPoints,url:location.href})']);
  await fs.writeFile(path.join(evidence, `${name}.json`), JSON.stringify(state, null, 2));
  return state;
}

async function screenshot(name) {
  const shot = await cli(['cdp', 'Page.captureScreenshot', '{"format":"png","fromSurface":true}']);
  const png = Buffer.from(shot.data, 'base64');
  assert.equal(png.subarray(1, 4).toString(), 'PNG');
  await fs.writeFile(path.join(evidence, `${name}.png`), png);
}

function mobile(state, width, height, agent) {
  assert.equal(state.width, width);
  assert.equal(state.height, height);
  assert.match(state.userAgent, agent);
  assert.ok(state.touch > 0);
}

try {
  await fs.mkdir(evidence, { recursive: true });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}/`;
  browser = spawn(chrome, [`--user-data-dir=${scratch}`, `--load-extension=${extension}`, `--disable-extensions-except=${extension}`, '--remote-debugging-port=0', '--no-first-run', '--no-default-browser-check', '--silent-debugger-extension-api', '--window-size=1200,900', url], { stdio: 'ignore' });
  browser.on('error', error => { result.launchError = error.message; });
  const activePort = await waitFor(async () => {
    try { return (await fs.readFile(path.join(scratch, 'DevToolsActivePort'), 'utf8')).trim().split(/\r?\n/); } catch { return null; }
  }, 'owned browser debugging endpoint');
  socket = new WebSocket(`ws://127.0.0.1:${activePort[0]}${activePort[1]}`);
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    const request = pending.get(message.id);
    if (!request) return;
    pending.delete(message.id);
    if (message.error) request.reject(new Error(message.error.message));
    else request.resolve(message.result);
  });
  await once(socket, 'open');
  const targets = await waitFor(async () => {
    const { targetInfos } = await cdp('Target.getTargets');
    return targetInfos.some(target => target.type === 'service_worker' && target.url.endsWith('/bridge.js')) && targetInfos;
  }, 'real extension service worker');
  const worker = targets.find(target => target.type === 'service_worker' && target.url.endsWith('/bridge.js'));
  const extensionId = new URL(worker.url).hostname;
  assert.match(extensionId, /^[a-p]{32}$/);
  const manifest = path.join(scratch, 'native-host.json');
  await fs.writeFile(manifest, JSON.stringify({ name: 'com.zigshell.bridge', description: 'Synthetic browser verification', path: exe, type: 'stdio', allowed_origins: [`chrome-extension://${extensionId}/`] }));
  await exec('reg.exe', ['add', registry, '/ve', '/t', 'REG_SZ', '/d', manifest, '/f']);
  registered = true;
  await waitFor(() => new Promise(resolve => {
    const probe = net.createConnection('\\\\.\\pipe\\multiprompt-browser-isolated');
    probe.once('error', () => resolve(false));
    probe.once('connect', () => { probe.end(); resolve(true); });
    probe.setTimeout(1000, () => { probe.destroy(); resolve(false); });
  }), 'native messaging host reconnect on extension keepalive', 90000);
  const target = targets.find(target => target.type === 'page' && target.url === url);
  assert.ok(target, 'synthetic page target exists');
  ({ windowId } = await cdp('Browser.getWindowForTarget', { targetId: target.targetId }));
  assert.match(await cli(['emulate', '--help'], false), /usage: zsb emulate/);
  const baseline = await measure('baseline');
  await screenshot('before');
  await cli(['emulate', 'iphone']);
  mobile(await measure('iphone'), 390, 844, /iPhone/);
  await screenshot('action');
  await cli(['click', '#next']);
  await waitFor(async () => (await measure('navigated')).url.endsWith('/next'), 'real link navigation');
  mobile(await measure('after-navigation'), 390, 844, /iPhone/);
  assert.ok(requests.some(request => request.url === '/next' && /iPhone/.test(request.userAgent)), 'navigation request uses mobile UA');
  await cli(['reload']);
  await waitFor(async () => {
    const state = await measure('reloaded');
    return state.width === 390 && state.touch > 0;
  }, 'mobile state after reload');
  mobile(await measure('after-reload'), 390, 844, /iPhone/);
  await screenshot('after');
  await cli(['emulate', 'pixel']);
  mobile(await measure('pixel'), 412, 915, /Android.*Pixel/);
  await cli(['emulate', '360x740', '--mobile']);
  mobile(await measure('custom-mobile'), 360, 740, /Mobile/);
  await cli(['emulate', '800x600']);
  const desktopSize = await measure('custom-desktop');
  assert.equal(desktopSize.width, 800);
  assert.equal(desktopSize.height, 600);
  assert.equal(desktopSize.userAgent, baseline.userAgent);
  assert.equal(desktopSize.touch, baseline.touch);
  await cli(['emulate', 'off']);
  const restored = await measure('off');
  assert.equal(restored.width, baseline.width);
  assert.equal(restored.height, baseline.height);
  assert.equal(restored.userAgent, baseline.userAgent);
  assert.equal(restored.touch, baseline.touch);
  await screenshot('off');
  await cli(['reload']);
  await waitFor(async () => (await measure('off-reloaded')).width === baseline.width, 'off remains off after reload');
  const offReloaded = await measure('after-off-reload');
  assert.equal(offReloaded.userAgent, baseline.userAgent);
  assert.equal(offReloaded.touch, baseline.touch);
  result.checks.push('iphone viewport/UA/touch', 'ordinary CDP screenshot retains emulation', 'real link navigation and request UA', 'reload persistence', 'pixel preset', 'custom mobile and desktop sizes', 'off restores desktop through reload', 'local native help');
  result.browser = await cdp('Browser.getVersion');
  result.extensionId = extensionId;
  result.status = 'passed';
} catch (error) {
  result.error = error.stack;
} finally {
  try {
    if (browser && browser.exitCode === null) {
      await exec('taskkill.exe', ['/PID', String(browser.pid), '/T', '/F'], { timeout: 15000 });
      if (browser.exitCode === null) await once(browser, 'exit');
    }
    socket?.close();
    if (registered) await exec('reg.exe', ['delete', registry, '/f']);
    await new Promise(resolve => server.close(resolve));
    await fs.rm(scratch, { recursive: true, force: true, maxRetries: 20, retryDelay: 250 });
    result.cleanup = 'owned browser process tree terminated; native registry entry and scratch removed';
    result.scratchRemoved = true;
  } catch (error) {
    result.cleanup = error.stack;
    result.status = 'failed';
  }
  await fs.writeFile(path.join(evidence, 'actions.json'), JSON.stringify(actions, null, 2));
  await fs.writeFile(path.join(evidence, 'requests.json'), JSON.stringify(requests, null, 2));
  await fs.writeFile(path.join(evidence, 'result.json'), JSON.stringify(result, null, 2));
}
assert.equal(result.status, 'passed', JSON.stringify(result));
console.log('VERIFIED browser-emulation through real zsb and Chrome');
