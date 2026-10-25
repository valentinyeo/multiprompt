const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawn, spawnSync } = require("node:child_process");
const net = require("node:net");
const test = require("node:test");
const vm = require("node:vm");

function browserHarness() {
  const tabs = new Map();
  const pages = new Map();
  let nextId = 1;
  let focused = true;
  const clicks = [];
  const event = { addListener() {} };
  const onActivated = { addListener(listener) { this.listener = listener; } };
  const onRemoved = { addListener(listener) { this.listener = listener; } };
  const chrome = {
    action: { onClicked: event },
    alarms: { create() {}, onAlarm: event },
    commands: { onCommand: event },
    contextMenus: { onClicked: event },
    debugger: {
      onDetach: event, onEvent: event,
      attach: async () => {}, detach: async () => {},
      sendCommand: async (debuggee, method) => {
        if (method === "Input.dispatchMouseEvent") clicks.push(debuggee.tabId);
        return {};
      },
    },
    runtime: { connectNative: () => ({ onMessage: event, onDisconnect: event }), onStartup: event, onInstalled: event, onMessage: event },
    storage: { local: { get: async () => ({}), set: async () => {}, remove: async () => {} } },
    webNavigation: {
      onCommitted: event,
      getAllFrames: async ({ tabId }) => {
        const page = pages.get(tabId);
        return [page, ...(page.frames || [])].map((frame, frameId) => ({ frameId, url: frame.url }));
      },
    },
    scripting: {
      executeScript: async ({ target, func, args = [] }) => {
        if (!func) return [];
        const page = pages.get(target.tabId);
        return [page, ...(page.frames || [])].map((frame, frameId) => ({ frame, frameId }))
          .filter(({ frameId }) => target.allFrames || (target.frameIds || [0]).includes(frameId))
          .map(({ frame, frameId }) => {
          context.document = {
            title: frame.title,
            body: { innerText: frame.text },
            links: frame.links.map((href) => ({ href, innerText: href })),
            querySelectorAll: () => [],
          };
          context.location = { href: frame.url };
          return { frameId, result: func(...args) };
        });
      },
    },
    tabs: {
      onRemoved, onCreated: event, onActivated, sendMessage: async () => {},
      query: async ({ windowId, active }) => [...tabs.values()].filter((tab) =>
        tab.windowId === windowId && (!active || tab.active)),
      get: async (id) => tabs.get(id),
      create: async ({ url, windowId, active, index }) => {
        const siblings = [...tabs.values()].filter((tab) => tab.windowId === windowId);
        index ??= siblings.length;
        for (const tab of siblings) if (tab.index >= index) tab.index += 1;
        if (active) for (const tab of tabs.values()) if (tab.windowId === windowId) tab.active = false;
        const tab = { id: nextId++, windowId, url, title: url, active, index };
        tabs.set(tab.id, tab);
        pages.set(tab.id, { url, title: url, text: url, links: [] });
        return tab;
      },
      update: async (id, options) => {
        const tab = tabs.get(id);
        if (options.active) for (const other of tabs.values()) if (other.windowId === tab.windowId) other.active = false;
        Object.assign(tab, options);
        if (options.active) onActivated.listener?.({ windowId: tab.windowId, tabId: id });
        return tab;
      },
      remove: async (id) => {
        const removed = tabs.get(id);
        tabs.delete(id);
        onRemoved.listener?.(id);
        if (removed?.active) {
          const remaining = [...tabs.values()].find((tab) => tab.windowId === removed.windowId);
          if (remaining) {
            remaining.active = true;
            onActivated.listener?.({ windowId: remaining.windowId, tabId: remaining.id });
          }
        }
      },
    },
    windows: { WINDOW_ID_NONE: -1, onRemoved: event, onFocusChanged: event, get: async () => ({ focused }), getAll: async () => [], getLastFocused: async () => null },
  };
  const context = vm.createContext({ chrome, console: { log() {}, warn() {} }, crypto: { randomUUID: () => "id" }, setTimeout: () => 1, clearTimeout() {} });
  const source = fs.readFileSync(process.env.ZSB_BRIDGE_JS || path.join(__dirname, "..", "extension", "bridge.js"), "utf8");
  vm.runInContext(`${source}\n;globalThis.api = { navigate, listTabs, textAction, getSnapshot, linksAction, findAction, clickAction, getTargetTab, dispatch, protect: (id) => protectedWindowIds.add(id) };`, context);
  vm.runInContext("locateSelectorAcrossFrames = async () => ({ frameId: 0, x: 10, y: 10, text: 'button' }); frameViewportOffset = async () => ({ x: 0, y: 0 });", context);
  return { api: context.api, chrome, tabs, pages, clicks, setFocused(value) { focused = value; } };
}

test("issue: navigation targets (never activates) the adjacent new tab for reads and clicks, with scoped --tab override", async () => {
  const { api, chrome, tabs, pages, clicks, setFocused } = browserHarness();
  const notion = (await api.navigate({ windowId: 10, url: "https://notion.test", newTab: true })).tab;
  pages.get(notion.id).text = "Notion page";
  setFocused(false);
  const other = (await api.navigate({ windowId: 10, url: "https://project.test", newTab: true })).tab;
  pages.get(other.id).text = "Project page";
  const { tabs: listed } = await api.listTabs({ windowId: 10 });
  assert.equal(other.active, false, "issue: agent tabs stay in the background");
  assert.equal(tabs.get(other.id).index, tabs.get(notion.id).index + 1);
  assert.equal(listed.some((tab) => tab.active), false, "nothing was activated by the agent");
  assert.equal(listed.find((tab) => tab.target).id, other.id);
  assert.equal(listed.find((tab) => tab.id === notion.id).target, false);
  assert.equal((await api.dispatch({ method: "activeTab", windowId: 10 })).id, other.id);
  assert.equal((await api.textAction({ windowId: 10 })).text, "Project page");
  for (const read of [api.textAction({ windowId: 10 }), api.getSnapshot(2000, { windowId: 10 }), api.linksAction({ windowId: 10 })]) {
    const result = await read;
    assert.equal(result.tab.id, other.id);
    assert.equal(result.tab.title, other.title);
    assert.equal(result.tab.url, other.url);
  }
  assert.equal((await api.getSnapshot(2000, { windowId: 10 })).text, "Project page");
  assert.equal((await api.findAction({ windowId: 10, query: "Project" })).tab.id, other.id);
  assert.equal((await api.clickAction({ windowId: 10, selector: "button" })).clicked, true);
  assert.deepEqual(clicks, [other.id, other.id, other.id]);
  assert.equal((await api.textAction({ windowId: 10, tabId: notion.id })).text, "Notion page");
  assert.equal((await api.getSnapshot(2000, { windowId: 10, tab: String(notion.id) })).tab.id, notion.id);
  assert.equal((await api.linksAction({ windowId: 10, tabId: notion.id })).tab.id, notion.id);
  assert.equal((await api.findAction({ windowId: 10, query: "Notion", tabId: notion.id })).tab.id, notion.id);
  assert.equal((await api.listTabs({ windowId: 10 })).tabs.find((tab) => tab.target).id, other.id);
  api.protect(10);
  await chrome.tabs.update(other.id, { active: true });
  await chrome.tabs.update(notion.id, { active: true });
  assert.equal((await api.listTabs({ windowId: 10 })).tabs.find((tab) => tab.target).id, notion.id);
  await chrome.tabs.update(other.id, { active: true });
  assert.equal((await api.listTabs({ windowId: 10 })).tabs.find((tab) => tab.target).id, other.id);
  await chrome.tabs.remove(other.id);
  assert.equal((await api.listTabs({ windowId: 10 })).tabs.find((tab) => tab.target).id, notion.id);
  tabs.set(99, { id: 99, windowId: 20, active: true });
  await assert.rejects(api.textAction({ windowId: 10, tabId: 99 }), /does not belong/);
  await assert.rejects(api.textAction({}), /no multiprompt browser window bound/);
  assert.deepEqual(Array.from((await api.listTabs({})).tabs), []);
});

test("navigation inserts after a middle active tab, not at the strip end or in another pane", async () => {
  const { api, chrome, tabs, setFocused } = browserHarness();
  const first = await chrome.tabs.create({ windowId: 10, active: false, url: "https://first.test" });
  const middle = await chrome.tabs.create({ windowId: 10, active: true, url: "https://middle.test" });
  const last = await chrome.tabs.create({ windowId: 10, active: false, url: "https://last.test" });
  const foreign = await chrome.tabs.create({ windowId: 20, active: true, url: "https://foreign.test" });
  setFocused(false);
  const opened = (await api.navigate({ windowId: 10, url: "https://new.test", newTab: true, activate: false })).tab;
  assert.equal(opened.active, false, "issue: agent tabs stay in the background");
  assert.equal(tabs.get(middle.id).active, true, "the user's tab stays selected");
  assert.equal(tabs.get(opened.id).index, 2);
  assert.equal(tabs.get(first.id).index, 0);
  assert.equal(tabs.get(middle.id).index, 1);
  assert.equal(tabs.get(last.id).index, 3);
  assert.equal(tabs.get(foreign.id).active, true);
  assert.equal(tabs.get(foreign.id).index, 0);
  assert.equal(tabs.get(last.id).url, "https://last.test");
});

test("tabs marks the active tab as target when no remembered tab survives", async () => {
  const { api, chrome, setFocused } = browserHarness();
  const original = await chrome.tabs.create({ windowId: 10, active: true, url: "https://first.test" });
  setFocused(false);
  assert.equal((await api.listTabs({ windowId: 10 })).tabs[0].target, true);
  const background = (await api.navigate({ windowId: 10, url: "https://second.test", newTab: true })).tab;
  assert.equal((await api.listTabs({ windowId: 10 })).tabs.find((tab) => tab.target).id, background.id);
  await chrome.tabs.remove(background.id);
  assert.equal((await api.listTabs({ windowId: 10 })).tabs.find((tab) => tab.target).id, original.id);
  assert.equal((await api.textAction({ windowId: 10 })).tab.id, original.id);
});

test("text, snapshot and links report full length and truncation across frames", async () => {
  const { api, pages } = browserHarness();
  const tab = (await api.navigate({ windowId: 10, url: "https://notion.test", newTab: true })).tab;
  const page = pages.get(tab.id);
  page.text = "A".repeat(2501);
  page.links = Array.from({ length: 55 }, (_, index) => `https://example.test/${index}`);
  page.frames = [{ url: "https://frame.test", title: "Frame", text: "B".repeat(9), links: ["https://frame.test/1", "https://frame.test/2"] }];
  for (const [read, limit, total, shown] of [
    [(value) => api.textAction({ windowId: 10, limit: value }), 2000, 2512, 2000],
    [(value) => api.getSnapshot(value, { windowId: 10 }), 2000, 2512, 2000],
    [(value) => api.linksAction({ windowId: 10, limit: value }), 50, 57, 50],
  ]) {
    const limited = await read(limit);
    assert.equal(limited.total_length, total);
    assert.equal(limited.truncated, true);
    assert.match(limited.hint, /use --limit \d+ for more/);
    assert.equal(limited.text?.length ?? limited.links.length, shown);
    const full = await read(total);
    assert.equal(full.total_length, total);
    assert.equal(full.truncated, false);
    assert.equal(full.hint, undefined);
  }
});

test("help-like literal text remains command data", async () => {
  const script = path.join(__dirname, "vps-multiprompt-browser.sh");
  for (const command of ["find", "type", "insert", "eval", "key", "cdp"]) {
    for (const text of ["literal --help", "literal -h"]) {
      let wire = "";
      const server = net.createServer((socket) => {
        socket.on("data", (chunk) => {
          wire += chunk.toString();
          if (wire.includes("\n")) socket.end('{"ok":true}\n');
        });
      });
      await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
      try {
        const child = spawn("bash", [script, command, text], {
          env: { ...process.env, MULTIPROMP_NOTIFY_RELAY_TOKEN: "relay-test-token", TMUX: "", ZSB_SESSION: "fixture", ZSB_PORT: String(server.address().port) },
        });
        let output = "";
        child.stdout.on("data", (chunk) => { output += chunk; });
        const exit = await new Promise((resolve, reject) => {
          child.on("error", reject);
          child.on("close", resolve);
        });
        assert.equal(exit, 0, `${command} ${text}: ${output}`);
        assert.equal(output.trim(), '{"ok":true}');
        const [auth, token, prefix, session, encoded] = wire.trim().split(":");
        assert.equal(auth, "AUTH");
        assert.equal(token, "relay-test-token");
        assert.equal(prefix, "ZSB");
        assert.equal(session, "fixture");
        assert.equal(Buffer.from(encoded, "base64").toString(), `${command}\x1f${text}\x1f`);
      } finally {
        server.close();
      }
    }
  }
});

test("every SSH command answers both help flags locally before session lookup or transport", async () => {
  const script = path.join(__dirname, "vps-multiprompt-browser.sh");
  const source = fs.readFileSync(path.join(__dirname, "..", "src", "bridge.zig"), "utf8");
  const dispatch = source.slice(source.indexOf("pub fn main("), source.indexOf("const usage_text ="));
  const commands = [...new Set([...dispatch.matchAll(/std\.mem\.eql\(u8, command, "([\w-]+)"\)/g)]
    .map(match => match[1]).filter(command => !command.startsWith("-")))];
  assert.ok(commands.includes("cdp") && commands.includes("profile-clone"));
  let connections = 0;
  const server = net.createServer(socket => {
    connections++;
    socket.on("data", () => socket.end('{"ok":true}\n'));
  });
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  const env = { ...process.env, MULTIPROMP_NOTIFY_RELAY_TOKEN: "relay-test-token", TMUX: "", ZSB_SESSION: "fixture", ZSB_PORT: String(server.address().port) };
  const run = args => new Promise((resolve, reject) => {
    const child = spawn("bash", [script, ...args], { env });
    let output = "";
    child.stdout.on("data", chunk => { output += chunk; });
    child.stderr.on("data", chunk => { output += chunk; });
    child.once("error", reject);
    const timer = setTimeout(() => child.kill("SIGKILL"), 5000);
    child.once("close", (status, signal) => {
      clearTimeout(timer);
      resolve({ status, signal, output });
    });
  });
  try {
    assert.equal((await run(["cdp", "Page.enable"])).status, 0);
    assert.equal(connections, 1, "positive control reaches transport");
    connections = 0;
    const invocations = [...commands, "selftest", "pane-info"].map(command => [command]);
    invocations.push(["tab", "close"], ["tabs", "--close"]);
    for (const args of invocations) {
      for (const flag of ["--help", "-h"]) {
        const result = await run([...args, flag]);
        assert.equal(result.signal, null);
        assert.equal(result.status, 0, `${args} ${flag}: ${result.output}`);
        assert.match(result.output, /^usage: zsb /);
        assert.ok(result.output.includes(args[0]), result.output);
        if (args[0] === "cdp") {
          assert.match(result.output, /cdp <method> \[params-json\]/);
          assert.match(result.output, /Examples:/);
          assert.match(result.output, /Page\.enable/);
          assert.match(result.output, /Runtime\.evaluate.*expression/);
        }
        assert.equal(connections, 0, `${args} ${flag} reached transport`);
        const local = spawnSync("bash", [script, ...args, flag], {
          env: { PATH: process.env.PATH }, encoding: "utf8", timeout: 5000,
        });
        assert.ifError(local.error);
        assert.equal(local.status, 0, local.stdout + local.stderr);
        assert.match(local.stdout, /^usage: zsb /);
      }
    }
  } finally {
    await new Promise(resolve => server.close(resolve));
  }
});

test("CLI help and per-read-command help list flags without a session or tunnel", () => {
  const script = path.join(__dirname, "vps-multiprompt-browser.sh");
  for (const args of [["help"], ["--help"]]) {
    const result = spawnSync("bash", [script, ...args], { encoding: "utf8", env: { PATH: process.env.PATH } });
    assert.equal(result.status, 0);
    for (const command of ["text", "snapshot", "links"]) assert.match(result.stdout, new RegExp(`${command}.*--limit N.*--tab ID`));
  }
  for (const command of ["text", "snapshot", "links"]) {
    const result = spawnSync("bash", [script, command, "--help"], { encoding: "utf8", env: { PATH: process.env.PATH } });
    assert.equal(result.status, 0);
    assert.match(result.stdout, /--limit N/);
    assert.match(result.stdout, /--full/);
    assert.match(result.stdout, /--tab ID/);
  }
});
