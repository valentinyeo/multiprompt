const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');
const { spawn } = require('node:child_process');
const test = require('node:test');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=';

async function runSelftest(failure) {
  const calls = [];
  let page, input = '', clicked = false, closed = false, buildAttempts = 0, tabLists = 0;
  const server = net.createServer(socket => {
    let wire = '';
    socket.on('data', chunk => {
      wire += chunk;
      if (!wire.endsWith('\n')) return;
      const match = /^AUTH:relay-test-token:ZSB:remote-3:(.*)\n$/.exec(wire);
      assert.ok(match, 'every request retains the exact caller session');
      const args = Buffer.from(match[1], 'base64').toString().split('\x1f').slice(0, -1);
      calls.push(args);
      const [command] = args;
      let result = {};
      const tab = () => ({ id: 42, windowId: 99, active: true, title: page.title, url: page.url });
      switch (command) {
        case 'open': {
          assert.equal(args.length, 2);
          assert.match(args[1], /^https:\/\/example\.com\/\?zsb-selftest-[a-f0-9]{32}$/);
          page = { url: args[1], title: 'Example Domain', marker: args[1].split('?')[1], built: false };
          result = { tab: tab() };
          break;
        }
        case 'tabs':
          tabLists++;
          if (failure === 'tabs-error' && !closed) {
            socket.end(JSON.stringify({ ok: false, error: 'extension outdated, reload it in chrome://extensions' }));
            return;
          }
          result = { tabs: page && !closed ? [tab()] : [{ id: 7, windowId: 99, active: true, url: 'https://original.test/' }] };
          if (failure === 'tabs-persistent') result.tabs = [];
          if (['tabs-empty', 'active-wrong-url', 'active-wrong-window', 'active-inactive', 'active-error'].includes(failure) && !closed) result.tabs = [];
          if (failure === 'pending-url' && tabLists === 1) result.tabs = [{ ...tab(), url: 'about:blank', pendingUrl: page.url }];
          break;
        case 'active-tab':
          if (failure === 'active-error') {
            socket.end(JSON.stringify({ ok: false, error: 'pane window no longer exists' }));
            return;
          }
          result = { ...tab(), url: failure === 'active-wrong-url' ? 'https://unrelated.test/' : page.url,
            windowId: failure === 'active-wrong-window' ? 100 : 99, active: failure !== 'active-inactive' };
          break;
        case 'text':
          assert.deepEqual(args.slice(1), ['--full', '--tab', '42']);
          result = { text: failure === 'text' || !page.built ? 'wrong page' : `${page.title}\n${page.marker}` };
          break;
        case 'type':
          assert.deepEqual(args.slice(1, 4), ['--tab', '42', '#zsb-input']);
          assert.equal(args[4], page.marker);
          input = failure === 'type' || !page.built ? 'wrong input' : args[4];
          result = { typed: true };
          break;
        case 'click':
          assert.deepEqual(args.slice(1), ['#zsb-button', '--tab', '42']);
          clicked = failure !== 'click' && page.built; result = { clicked: true }; break;
        case 'eval': {
          assert.equal(args.length, 4);
          assert.deepEqual(args.slice(-2), ['--tab', '42']);
          if (args[1].startsWith('(document.title=')) {
            buildAttempts++;
            const build = /^\(document\.title=("(?:[^"\\]|\\.)*"),document\.body\.innerHTML=("(?:[^"\\]|\\.)*"),document\.title\)$/.exec(args[1]);
            assert.ok(build, 'page build is one comma expression returning its title');
            const title = JSON.parse(build[1]), html = JSON.parse(build[2]);
            assert.match(title, /^zsb selftest remote-3 \d{4}-/);
            assert.equal(/<title>(.*?)<\/title>/.exec(html)[1], title);
            assert.equal(/<p>(zsb-selftest-[a-f0-9]+)<\/p>/.exec(html)[1], page.marker);
            assert.match(html, /<input id="zsb-input"/);
            assert.match(html, /onclick=.*textContent/);
            if (failure === 'build' || failure === 'retry-error' && buildAttempts < 3) {
              socket.end(JSON.stringify({ ok: false, error: 'page is not ready' }));
              return;
            }
            if (failure === 'retry-result' && buildAttempts < 3) {
              result = 'Example Domain';
            } else {
              const document = { title: page.title, body: { innerHTML: '' } };
              result = vm.runInNewContext(args[1], { document }, { timeout: 1000 });
              assert.equal(result, title);
              assert.equal(document.body.innerHTML, html);
              page.title = failure === 'build-title' ? 'Example Domain' : document.title;
              page.built = true;
            }
          } else if (args[1] === "document.getElementById('zsb-input').value") {
            result = input;
          } else {
            assert.equal(args[1], "document.getElementById('zsb-result').textContent");
            result = clicked ? 'clicked' : 'not clicked';
          }
          break;
        }
        case 'screenshot':
          assert.deepEqual(args.slice(1), ['--tab', '42']);
          result = { data: failure === 'screenshot' ? Buffer.from('not a PNG').toString('base64') : png };
          break;
        case 'pane-info':
          result = { tab_name: 'Meta Klaviyo Connection', active: failure !== 'inactive', visible: failure !== 'hidden', windowId: failure === 'wrong-host' ? 100 : 99 };
          break;
        case 'close-tab':
          assert.equal(args[1], '42');
          closed = failure !== 'close'; break;
        default: throw new Error(`unexpected command ${command}`);
      }
      if (failure === 'open' && command === 'open') socket.end(JSON.stringify({ ok: false, error: 'verification failed after create' }));
      else if (command === 'open') socket.end('ok\n');
      else if (failure === 'page-error' && command === 'text') socket.end(JSON.stringify({ ok: true, result: { error: 'page_error' } }));
      else if (failure === 'malformed' && command === 'text') socket.end('not JSON');
      else socket.end(JSON.stringify({ ok: true, extensionVersion: '1.0.54', result }));
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const child = spawn('bash', [process.env.ZSB_WRAPPER_SH || path.join(root, 'tools/vps-multiprompt-browser.sh'), 'selftest'], {
    env: { ...process.env, MULTIPROMP_NOTIFY_RELAY_TOKEN: "relay-test-token", TMUX: '', ZSB_SESSION: 'remote-3', ZSB_PORT: String(server.address().port) },
  });
  let stdout = '', stderr = '';
  child.stdout.on('data', chunk => stdout += chunk);
  child.stderr.on('data', chunk => stderr += chunk);
  try {
    const code = await new Promise((resolve, reject) => { child.on('error', reject); child.on('exit', resolve); });
    assert.equal(stderr, '');
    const lines = stdout.trim().split('\n');
    assert.equal(lines.length, 2, 'one JSON summary followed by one human line');
    return { code, summary: JSON.parse(lines[0]), human: lines[1], calls, closed, buildAttempts };
  } finally { await new Promise(resolve => server.close(resolve)); }
}

test('selftest exercises the real wrapper transport and reports the visible hosting tab', async () => {
  const result = await runSelftest();
  assert.equal(result.code, 0);
  assert.equal(result.summary.ok, true);
  assert.equal(result.summary.tab_name, 'Meta Klaviyo Connection');
  assert.equal(result.summary.visible, true);
  assert.deepEqual(Object.keys(result.summary.steps), ['open', 'text', 'type', 'click', 'screenshot', 'hosting', 'close']);
  for (const step of Object.values(result.summary.steps)) assert.equal(step.pass, true);
  assert.equal(result.summary.steps.screenshot.width, 1);
  assert.equal(result.closed, true);
  assert.equal(result.human, 'PASS: pane for remote-3 is on tab "Meta Klaviyo Connection" (visible)');
  assert.equal(result.calls.at(-2)[0], 'close-tab');
  assert.equal(result.buildAttempts, 1);
  assert.deepEqual(result.calls.slice(0, 4).map(args => args[0]), ['open', 'tabs', 'eval', 'tabs']);
});

for (const retry of ['retry-error', 'retry-result']) {
  test(`selftest retries the exact-tab page build after ${retry}`, async () => {
    const result = await runSelftest(retry);
    assert.equal(result.code, 0);
    assert.equal(result.summary.ok, true);
    for (const step of Object.values(result.summary.steps)) assert.equal(step.pass, true);
    assert.equal(result.buildAttempts, 3);
    assert.deepEqual(result.calls.slice(0, 7).map(args => args[0]), ['open', 'tabs', 'eval', 'eval', 'eval', 'tabs', 'text']);
    assert.deepEqual(result.calls[2], result.calls[3]);
    assert.deepEqual(result.calls[2], result.calls[4]);
    assert.equal(result.closed, true);
  });
}

for (const failure of ['text', 'type', 'click', 'screenshot', 'hidden', 'inactive', 'wrong-host', 'open', 'close', 'page-error', 'malformed', 'build', 'build-title']) {
  test(`selftest fails honestly for ${failure} and attempts exact-tab cleanup`, async () => {
    const result = await runSelftest(failure);
    assert.equal(result.code, 1);
    assert.equal(result.summary.ok, false);
    assert.match(result.human, /^FAIL:/);
    assert.ok(result.calls.some(args => args[0] === 'close-tab' && args[1] === '42'));
    assert.equal(result.closed, failure !== 'close');
    const failedStep = ['hidden', 'inactive', 'wrong-host'].includes(failure) ? 'hosting'
      : ['page-error', 'malformed'].includes(failure) ? 'text'
      : ['build', 'build-title'].includes(failure) ? 'open' : failure;
    assert.equal(result.summary.steps[failedStep].pass, false);
    assert.equal(typeof result.summary.steps[failedStep].error, 'string');
    if (!['open', 'build', 'build-title'].includes(failure)) {
      for (const [name, step] of Object.entries(result.summary.steps)) {
        assert.equal(step.pass, name !== failedStep, `only ${failedStep} should fail`);
      }
    }
    if (failure === 'build' || failure === 'build-title') {
      assert.match(result.summary.steps.open.error, /selftest page is not this session's target browser tab/);
      assert.equal(result.buildAttempts, failure === 'build' ? 20 : 1);
    }
    if (failure === 'open') assert.equal(result.buildAttempts, 0);
    if (failure === 'hidden') assert.equal(result.summary.visible, false);
  });
}

test('data page scripts use the exact-tab serialized CDP session; exceptions fail', async () => {
  const source = fs.readFileSync(process.env.ZSB_BRIDGE_JS || path.join(root, 'extension/bridge.js'), 'utf8');
  const calls = [];
  let throws = false;
  const context = vm.createContext({
    chrome: { debugger: { sendCommand: async (debuggee, method, params) => {
      calls.push({ debuggee, method, params });
      return throws ? { exceptionDetails: { text: 'page scripting failed' } } : { result: { value: 'read-back' } };
    } } },
    withCdpSession: async (tabId, operation) => operation({ tabId }),
  });
  const start = source.indexOf('function isExtensionFrameAccessError(');
  const end = source.indexOf('\nasync function runInTab(', start);
  assert.ok(start >= 0 && end > start);
  vm.runInContext(source.slice(start, end) + '\nglobalThis.run = runInDataTab;', context);
  assert.equal(await context.run(42, function getValue() { return document.querySelector('input').value; }, []), 'read-back');
  assert.equal(calls[0].debuggee.tabId, 42);
  assert.equal(calls[0].method, 'Runtime.evaluate');
  assert.equal(calls[0].params.returnByValue, true);
  assert.equal(calls[0].params.awaitPromise, true);
  throws = true;
  await assert.rejects(context.run(42, function f() {}, []), /page scripting failed/);
  for (const name of ['evalAction', 'runInTab', 'runInFrame']) {
    const body = source.slice(source.indexOf(`async function ${name}(`));
    assert.match(body.slice(0, body.indexOf('\n}\n') + 3), /runInDataTab/);
  }
});

test('native restore, open, adoption and UI-thread diagnostics use identity guards', () => {
  const source = require('./app-source').readAppSource(process.env.ZSB_MAIN_ZIG);
  const body = name => {
    const start = source.indexOf(`fn ${name}(`);
    assert.ok(start >= 0, name);
    return source.slice(start, source.indexOf('\nfn ', start + 3));
  };
  assert.match(body('findZsbPaneTarget'), /tmux_identity.prefer/);
  assert.match(body('spawnShellWithSession'), /findLocalTmuxTab[\s\S]*switchToShell\(existing\)[\s\S]*return false/);
  assert.match(body('restoreSession'), /const restored_active_tab = selectedSavedTab\(json, tabs\[0\.\.tab_count\], if \(@import\("launch_cache.zig"\)\.pending\) @import\("launch_cache.zig"\)\.selected_shell_id else 0\)/);
  const selected = body('selectedSavedTab');
  assert.match(selected, /for \(\[_\]u64\{ selected, json_reader\.uint\(json, "active_shell_id"\) \}\)/);
  assert.match(selected, /json_reader\.restoredSessionTab\(json, tabs, id\)/);
  assert.match(selected, /if \(active < tabs\.len\) @intCast\(tmux_identity\.restoreWinner\(tabs, @intCast\(active\)\)\) else null/);
  assert.match(body('restoreSession'), /restoreWinner\(tabs\[0\.\.tab_count\], t\) != t\) continue/);
  assert.match(body('absorbWorkspaceIntoSlots'), /restoreWinner\(tabs\[0\.\.tab_count\], t\) != t\) continue/);
  assert.match(body('adoptRemoteTmuxSessionForShell'), /findLocalTmuxTab\(host, t\)[\s\S]*paneGuardKeepUser\(existing\)/);
  assert.match(body('pollShellNames'), /adoptRemoteTmuxSessionForShell/);
  assert.match(body('zsbResolvePaneWindowId'), /queueZsbBindRequestEx[\s\S]*return info.window_id/);
  assert.doesNotMatch(body('zsbResolvePaneWindowId'), /zsbReadPaneWindowIdForToken/);
  assert.match(body('handleZsbBindRequest'), /info_only[\s\S]*\.name = shells\[ti\].name[\s\S]*\.active = ti == active_shell[\s\S]*\.visible = ti == active_shell and shellPaneVisible/);
});

for (const mode of ['tabs-empty', 'tabs-error', 'pending-url']) {
  test(`selftest locates its marker despite ${mode} and cleans up the exact tab`, async () => {
    const result = await runSelftest(mode);
    assert.equal(result.code, 0, JSON.stringify(result.summary));
    assert.equal(result.summary.steps.open.tab_id, '42');
    assert.equal(result.closed, true);
    assert.equal(result.calls.some(args => args[0] === 'active-tab'), mode !== 'pending-url');
    assert.ok(result.calls.some(args => args[0] === 'close-tab' && args[1] === '42'));
  });
}
for (const mode of ['active-wrong-url', 'active-wrong-window', 'active-error']) {
  test(`selftest refuses unrelated fallback for ${mode} with a precise discovery error`, async () => {
    const result = await runSelftest(mode);
    assert.equal(result.code, 1);
    assert.match(result.summary.steps.open.error, /cannot locate selftest tab: tabs failed: empty session pane tab list/);
    assert.match(result.summary.steps.open.error, mode === 'active-error' ? /active-tab fallback failed: pane window no longer exists/ : /pane active-tab did not match marker URL/);
    assert.equal(result.buildAttempts, 0);
    assert.equal(result.calls.some(args => args[0] === 'close-tab'), false);
  });
}

test('issue: the selftest accepts its page as a background target tab (agents never activate tabs)', async () => {
  const result = await runSelftest('active-inactive');
  assert.equal(result.summary.steps.open.pass, true, JSON.stringify(result.summary.steps.open));
  assert.ok(result.calls.some(args => args[0] === 'active-tab'));
  assert.equal(result.calls.some(args => args[0] === 'activate'), false, 'the selftest never activates a tab');
});

test('selftest does not claim verified cleanup when tab enumeration remains unavailable', async () => {
  const result = await runSelftest('tabs-persistent');
  assert.equal(result.code, 1);
  assert.equal(result.summary.steps.open.pass, true);
  assert.equal(result.closed, true);
  assert.equal(result.summary.steps.close.pass, false);
  assert.match(result.summary.steps.close.error, /empty session pane tab list/);
});
