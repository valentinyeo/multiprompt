const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { randomUUID } = require("node:crypto");
const { spawnSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(process.env.ZSB_IFRAME_BRIDGE_JS || path.join(root, "extension/bridge.js"), "utf8");
const native = fs.readFileSync(process.env.ZSB_IFRAME_NATIVE || path.join(root, "src/bridge.zig"), "utf8");

function declaration(name) {
  const start = source.search(new RegExp(`^(?:async )?function ${name}\\(`, "m"));
  if (start < 0) return "";
  const rest = source.slice(start);
  const end = rest.slice(1).search(/\n(?:async )?function /);
  return end < 0 ? rest : rest.slice(0, end + 1);
}

function harness({ redirected = false, inaccessible = false, attachError, inputError } = {}) {
  const calls = [];
  const scripts = [];
  const scrolls = [];
  const domEvents = [];
  const tab = { id: 7, url: "https://outer.test/", windowId: 2 };
  const frames = new Map();
  const contexts = new Map();
  const listeners = new Map();
  const timers = new Map();
  let timerId = 0;
  const frameRows = [
    { frameId: 0, parentFrameId: -1, url: tab.url },
    { frameId: 12, parentFrameId: 0, url: "https://middle.test/" },
    { frameId: 43, parentFrameId: 12, url: "https://embed.test/app" },
    { frameId: 44, parentFrameId: 12, url: "https://embed.test/app" },
  ];
  for (const row of frameRows) {
    const handlers = new Set();
    listeners.set(row.frameId, handlers);
    const window = {
      addEventListener: (name, fn) => { if (name === "message") handlers.add(fn); },
      removeEventListener: (name, fn) => { if (name === "message") handlers.delete(fn); },
    };
    const state = { row, window, iframes: [], buttonLeft: 10 };
    frames.set(row.frameId, state);
    class DomEvent {
      constructor(type, options) { this.type = type; Object.assign(this, options); }
    }
    state.button = {
      isConnected: true,
      scrollIntoView: (options) => scrolls.push({ frameId: row.frameId, kind: "button", options }),
      getBoundingClientRect: () => ({ left: state.buttonLeft, top: 20, width: 80, height: 20 }),
      getAttribute: () => null,
      textContent: "Settings",
      focus: () => domEvents.push({ type: "focus" }),
      dispatchEvent: (event) => { domEvents.push(event); return true; },
      click: () => domEvents.push({ type: "bare-click" }),
    };
    const context = vm.createContext({
      window, innerWidth: 1000, innerHeight: 1000,
      location: { href: row.url }, URL,
      setTimeout: (fn) => { timers.set(++timerId, fn); return timerId; },
      clearTimeout: (id) => timers.delete(id),
      MouseEvent: DomEvent, PointerEvent: DomEvent,
      document: {
        querySelector: () => row.frameId === 43 ? state.button : null,
        querySelectorAll: () => state.iframes,
      },
    });
    contexts.set(row.frameId, context);
  }
  for (const row of frameRows.filter((row) => row.frameId !== 0)) {
    const child = frames.get(row.frameId);
    const parent = frames.get(row.parentFrameId);
    child.window.parent = { postMessage: (data) => {
      for (const listener of listeners.get(row.parentFrameId)) listener({ data, source: child.window });
    } };
    const rect = row.frameId === 12 ? { left: 100, top: 150 } :
      row.frameId === 43 ? { left: 20, top: 30 } : { left: 600, top: 700 };
    const element = {
      src: redirected && row.frameId === 43 ? "https://embed.test/login" : row.url,
      contentWindow: child.window, isConnected: true,
      clientLeft: row.frameId === 12 ? 3 : 2,
      clientTop: row.frameId === 12 ? 5 : 4,
      getAttribute: () => element.src,
      getBoundingClientRect: () => ({ ...rect, width: 800, height: 600 }),
      scrollIntoView: (options) => {
        scrolls.push({ frameId: row.frameId, kind: "iframe", options });
        frames.get(43).buttonLeft = 30;
      },
    };
    parent.iframes.unshift(element);
  }
  const chrome = {
    tabs: { get: async () => tab },
    webNavigation: { getAllFrames: async () => frameRows },
    scripting: { executeScript: async (options) => {
      scripts.push(options);
      const id = options.target.frameIds?.[0] ?? 0;
      if (inaccessible && id === 12) throw new Error("Cannot access frame");
      const context = contexts.get(id);
      if (!context) throw new Error(`No frame with id ${id}`);
      context.__args = options.args || [];
      return [{ frameId: id, result: await vm.runInContext(`(${options.func.toString()})(...__args)`, context) }];
    } },
    debugger: { sendCommand: async (debuggee, method, params) => {
      calls.push({ debuggee, method, ...params });
      if (inputError && params.type === "mousePressed") throw new Error(inputError);
      return {};
    } },
  };
  const context = vm.createContext({
    chrome, crypto: { randomUUID },
    getTargetTab: async () => tab,
    compactTab: (value) => ({ id: value.id, url: value.url }),
    stringOr: (value, fallback) => typeof value === "string" ? value : fallback,
    cursorOptionsFrom: () => ({}), installCursorApi() {},
    withCdpSession: async (tabId, fn) => {
      if (attachError) throw new Error(attachError);
      return fn({ tabId });
    },
  });
  const names = ["clickAction", "framesAction", "evalAction", "runInDataTab", "runInTab", "runInFrame", "runInAllFrames", "errorText", "locateSelectorAcrossFrames", "frameViewportOffset", "locateSelectorForTrustedInput", "locateChildFrameRect", "signalParentFrame", "clickSelector", "dispatchTrustedClick", "evalInPage"];
  vm.runInContext(names.map(declaration).join("\n"), context);
  return { api: context, chrome, calls, scripts, scrolls, domEvents, frames, contexts, listeners, timers, tab };
}

for (const redirected of [false, true]) {
  test(`IGSH-305 trusted nested cross-origin click uses frame identity${redirected ? " after redirect" : " with duplicate URLs"}`, async () => {
    const h = harness({ redirected });
    const result = await h.api.clickAction({ selector: "[role=tab]" });
    assert.equal(result.trusted, true);
    assert.equal(result.frameId, 43);
    assert.deepEqual(h.calls.map(({ method, type, x, y, debuggee, buttons }) => ({ method, type, x, y, tabId: debuggee.tabId, buttons })), [
      { method: "Input.dispatchMouseEvent", type: "mouseMoved", x: 195, y: 219, tabId: 7, buttons: 0 },
      { method: "Input.dispatchMouseEvent", type: "mousePressed", x: 195, y: 219, tabId: 7, buttons: 1 },
      { method: "Input.dispatchMouseEvent", type: "mouseReleased", x: 195, y: 219, tabId: 7, buttons: 0 },
    ]);
    assert.equal(result.via, "cdp");
    assert.equal(h.domEvents.length, 0, "trusted input must not also synthesize DOM events");
    assert.ok(h.scrolls.some((scroll) => scroll.frameId === 43 && scroll.kind === "button"));
    assert.ok(h.scrolls.some((scroll) => scroll.frameId === 12 && scroll.kind === "iframe"));
    assert.ok(h.scrolls.every((scroll) => scroll.options.behavior === "instant"));
    assert.equal(h.timers.size, 0);
    assert.ok([...h.listeners.values()].every((set) => set.size === 0));
  });
}

for (const options of [{ inaccessible: true }, { attachError: "Another debugger is already attached" }]) {
  test(`IGSH-305 unavailable trusted input reports a complete frame DOM fallback (${Object.keys(options)[0]})`, async () => {
    const h = harness(options);
    const result = await h.api.clickAction({ selector: "[role=tab]" });
    assert.equal(result.trusted, false);
    assert.equal(result.via, "frame-dom-fallback");
    assert.ok(result.reason);
    assert.equal(result.frameId, 43);
    const events = h.domEvents.filter((event) => event.type !== "focus");
    assert.deepEqual(events.map((event) => event.type), ["pointerdown", "mousedown", "pointerup", "mouseup", "click"]);
    assert.deepEqual(events.map((event) => event.buttons), [1, 1, 0, 0, 0]);
    assert.ok(events.every((event) => event.bubbles && event.composed && event.cancelable));
    assert.ok(events.every((event) => event.clientX > 0 && event.clientY > 0));
    assert.equal(h.calls.length, 0);
  });
}

test("IGSH-305 partial trusted input and attach timeout never replay a synthetic click", async () => {
  for (const options of [{ inputError: "Target closed" }, { attachError: "CDP attach timed out" }]) {
    const h = harness(options);
    await assert.rejects(h.api.clickAction({ selector: "[role=tab]" }), /Target closed|timed out/);
    assert.equal(h.domEvents.length, 0);
  }
});

test("IGSH-305 frame handshake ignores unrelated sources and cleans up on timeout", async () => {
  const h = harness();
  const context = h.contexts.get(12);
  const run = (action) => {
    context.__args = ["nonce", action];
    return vm.runInContext(`(${declaration("locateChildFrameRect")})(...__args)`, context);
  };
  await run("listen");
  assert.equal(h.listeners.get(12).size, 1);
  assert.equal(h.timers.size, 1);
  for (const listener of h.listeners.get(12)) listener({ data: { zsbFrameToken: "nonce" }, source: {} });
  const pending = run("rect");
  for (const timer of [...h.timers.values()]) timer();
  assert.equal(await pending, null);
  assert.equal(h.timers.size, 0);
  assert.equal(h.listeners.get(12).size, 0);
});

test("IGSH-305 eval --frame targets only the requested MAIN world and awaits promises", async () => {
  const h = harness();
  for (const [frameId, context] of h.contexts) context.frameLabel = `frame-${frameId}`;
  assert.equal(await h.api.evalAction({ frameId: 43, code: "Promise.resolve(frameLabel)" }), "frame-43");
  assert.equal(await h.api.evalAction({ code: "frameLabel" }), "frame-0");
  assert.equal(h.scripts[0].world, "MAIN");
  assert.deepEqual(Array.from(h.scripts[0].target.frameIds), [43]);
  await assert.rejects(h.api.evalAction({ frameId: 999, code: "frameLabel" }), /No frame/);
  await assert.rejects(h.api.evalAction({ frameId: -1, code: "frameLabel" }), /invalid frameId/);
  assert.equal(h.calls.length, 0);
});

test("IGSH-305 frame eval never falls back to a top-frame CSP or data-page context", async () => {
  const h = harness();
  vm.runInContext('Function = () => { throw new EvalError("unsafe-eval blocked by CSP"); };', h.contexts.get(43));
  await assert.rejects(h.api.evalAction({ frameId: 43, code: "document.title" }), /frame 43.*Content Security Policy/);
  h.tab.url = "data:text/html,top";
  h.contexts.get(43).frameLabel = "child";
  h.contexts.get(44).frameLabel = "child";
  assert.equal(await h.api.evalAction({ frameId: 44, code: "frameLabel" }), "child");
  assert.equal(h.calls.length, 0);
});

test("IGSH-305 frames is a read-only frame list with parent IDs, not Target access", async () => {
  const h = harness();
  assert.equal(typeof h.api.framesAction, "function");
  const result = await h.api.framesAction({ tab: "7" });
  assert.deepEqual(Array.from(result.frames, ({ frameId, parentFrameId }) => [frameId, parentFrameId]), [[0, -1], [12, 0], [43, 12], [44, 12]]);
  assert.equal(result.frames[2].url, "https://embed.test/app");
  assert.equal(h.calls.length, 0);
  assert.equal(h.scripts.length, 0);
});

test("IGSH-305 SSH help exposes frames and frame eval without a session or transport", () => {
  const wrapper = process.env.ZSB_IFRAME_WRAPPER || path.join(root, "tools/vps-multiprompt-browser.sh");
  for (const flag of ["--help", "-h"]) {
    for (const command of ["frames", "eval", "script", "click"]) {
      const result = spawnSync("bash", [wrapper, command, flag], {
        encoding: "utf8", timeout: 5000, env: { ...process.env, TMUX: "", ZSB_SESSION: "" },
      });
      assert.equal(result.status, 0, result.stderr);
      assert.ok(result.stdout.startsWith(`usage: zsb ${command} `), result.stdout);
      if (command === "eval" || command === "script") assert.match(result.stdout, /--frame ID/);
      if (command === "frames") assert.match(result.stdout, /parentFrameId/);
      if (command === "click") assert.match(result.stdout, /frame-dom-fallback/);
    }
  }
});

test("IGSH-305 CLI exposes frame eval and read-only frames, and CI runs these regressions", () => {
  assert.match(native, /command, "frames"[\s\S]{0,450}sendBrowserRequest\(allocator, "frames"/);
  assert.match(native, /fn buildEvalFields\([\s\S]*?arg, "--frame"/);
  assert.match(native, /eval \[--frame <frameId>\] <js>/);
  assert.match(native, /click <selector>.*via=cdp.*frame-dom-fallback/);
  const workflow = fs.readFileSync(path.join(root, ".github/workflows/test.yml"), "utf8");
  assert.match(workflow, /node --test tools\/zsb-iframe\.test\.js/);
});
