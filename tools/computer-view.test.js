const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

function read(relative) {
  const file = path.join(__dirname, '..', relative);
  return fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
}

function viewer() {
  const sent = [], operations = [], frames = [], instances = [];
  const elements = new Map();
  function element(name = '') {
    const listeners = new Map();
    return {
      hidden: false, width: 1920, height: 1080, textContent: '', disabled: false, attached: false,
      canvas: { width: 1920, height: 1080, image: name },
      classList: { toggle() {} }, setAttribute() {},
      addEventListener(event, fn) { listeners.set(event, fn); },
      fire(event, detail = {}) { listeners.get(event)?.(detail); },
      replaceChildren() { this.attached = false; operations.push('remove'); },
      removeChild() { this.replaceChildren(); },
      querySelector() { return this.attached ? this.canvas : null; },
      getContext() { return { drawImage(source, ...args) { operations.push(['draw', source, ...args]); }, clearRect() {} }; },
    };
  }
  for (const id of ['pane', 'screen', 'still', 'overlay', 'message', 'label', 'control', 'wide', 'retry']) elements.set(`#${id}`, element(id));
  class RFB {
    constructor(screen, url, options) { screen.attached = true; this.screen = screen; this.listeners = new Map(); this.url = url; this.options = options; this.focused = 0; instances.push(this); }
    addEventListener(event, fn) { this.listeners.set(event, fn); }
    emit(event) { this.listeners.get(event)?.(); }
    releaseInput() { operations.push('release'); }
    disconnect() { this.emit('beforedisconnect'); this.screen.removeChild(); operations.push('disconnect'); }
    blur() { operations.push('blur'); }
    focus() { this.focused++; }
    set viewOnly(value) { operations.push(value ? 'view-only' : 'control'); this.only = value; }
    get viewOnly() { return this.only; }
  }
  let receive;
  const windowEvents = new Map(), documentEvents = new Map();
  const document = {
    hidden: false,
    querySelector(id) { return elements.get(id); },
    createElement() { return element('copy'); },
    addEventListener(event, fn) { documentEvents.set(event, fn); },
  };
  const context = {
    RFB, initLogging() {}, document,
    location: { pathname: '/capability/index.html' },
    window: { chrome: { webview: { postMessage(message) { sent.push(message); }, addEventListener(name, fn) { receive = fn; } } }, addEventListener(event, fn) { windowEvents.set(event, fn); } },
    requestAnimationFrame(fn) { frames.push(fn); },
  };
  const source = read('src/computer/adapter.js').replace(/^import .*;\n/gm, '');
  assert.ok(source.length > 0, 'the Computer page script ships with the app');
  vm.runInNewContext(source, context, { filename: 'computer-adapter.js' });
  const words = { computer: 'Computer', connecting: 'Connecting', live: 'Live', sleeping: 'Sleeping', reconnecting: 'Reconnecting', lost: 'Lost', take_control: 'Take control', give_back: 'Give back', in_control: 'You are in control', retry: 'Retry', full_width: 'Full width' };
  const send = (command, generation = '1', extra = {}) => receive({ data: { token: 'capability', command, generation, ...extra } });
  function select(target = 'desktop-a', generation = '1') { send('select', generation, { target, host: 'example-host', state: 'connecting', words }); }
  function connect(generation = '1') { send('connect', generation, { port: 12345, password: 'example' }); return instances.at(-1); }
  return { sent, operations, frames, instances, elements, send, select, connect, document, windowEvents, receive,
    flush() { while (frames.length) frames.shift()(); } };
}

test('Computer starts view-only and requires presented pixels, not connect', () => {
  const app = viewer();
  app.select();
  const rfb = app.connect();
  assert.equal(rfb.viewOnly, true);
  assert.equal(rfb.focusOnClick, false);
  assert.equal(rfb.focused, 0);
  assert.equal(rfb.resizeSession, false);
  assert.equal(app.elements.get('#overlay').hidden, false);
  rfb.emit('connect');
  app.flush();
  assert.ok(!app.sent.some(message => message.endsWith('|painted')));
  rfb.emit('paintedframe');
  assert.ok(!app.sent.some(message => message.endsWith('|painted')));
  app.flush();
  assert.ok(app.sent.includes('capability|1|painted'));
  app.send('state', '1', { state: 'live' });
  assert.equal(app.elements.get('#overlay').hidden, true);
});

test('Only a trusted explicit action requests control; granting it focuses', () => {
  const app = viewer(); app.select(); const rfb = app.connect();
  app.send('state', '1', { state: 'live' });
  app.elements.get('#control').fire('click', { isTrusted: false });
  assert.ok(!app.sent.some(message => message.endsWith('|take')));
  app.elements.get('#control').fire('click', { isTrusted: true });
  assert.ok(app.sent.includes('capability|1|take'));
  assert.equal(rfb.viewOnly, true);
  app.send('control', '1', { enabled: true });
  assert.equal(rfb.viewOnly, false);
  assert.equal(rfb.focused, 1);
  app.operations.length = 0;
  app.windowEvents.get('blur')();
  assert.equal(rfb.viewOnly, true);
  assert.deepEqual(app.operations.slice(0, 2), ['release', 'view-only']);
});

test('Suspending captures before disconnect, releases input first, and acknowledges', () => {
  const app = viewer(); app.select(); const rfb = app.connect();
  rfb.emit('paintedframe'); app.flush();
  app.send('state', '1', { state: 'live' });
  app.send('control', '1', { enabled: true });
  app.operations.length = 0;
  app.send('suspend');
  const release = app.operations.indexOf('release');
  const capture = app.operations.findIndex(op => Array.isArray(op) && op[0] === 'draw');
  const disconnect = app.operations.indexOf('disconnect');
  assert.ok(release >= 0 && release < capture && capture < disconnect);
  assert.equal(app.elements.get('#still').hidden, false);
  assert.ok(app.sent.includes('capability|1|stopped'));
  app.select('desktop-b', '2');
  assert.equal(app.elements.get('#still').hidden, true);
  app.select('desktop-a', '3');
  assert.equal(app.elements.get('#still').hidden, false);
});

test('Old connection callbacks, frame callbacks, and host commands cannot cross targets', () => {
  const app = viewer(); app.select(); const old = app.connect();
  old.emit('paintedframe');
  app.select('desktop-b', '2'); const current = app.connect('2');
  app.sent.length = 0;
  old.emit('disconnect'); old.emit('securityfailure'); old.emit('paintedframe'); app.flush();
  assert.deepEqual(app.sent, []);
  app.send('control', '1', { enabled: true });
  assert.equal(current.viewOnly, true);
  app.receive({ data: { token: 'wrong', command: 'control', generation: '2', enabled: true } });
  assert.equal(current.viewOnly, true);
  current.emit('paintedframe'); app.flush();
  assert.deepEqual(app.sent, ['capability|2|painted']);
});

test('Validated same-desktop transfer keeps one connection and revokes control', () => {
  const app = viewer(); app.select(); const rfb = app.connect();
  app.send('state', '1', { state: 'live' }); app.send('control', '1', { enabled: true });
  app.send('transfer', '2', { previous: '1' });
  assert.equal(app.instances.length, 1);
  assert.equal(rfb.viewOnly, true);
  assert.ok(!app.operations.includes('disconnect'));
  app.sent.length = 0; rfb.emit('disconnect');
  assert.deepEqual(app.sent, ['capability|2|lost']);
});

test('Reconnect never inherits control or focus', () => {
  const app = viewer(); app.select(); app.connect();
  app.send('state', '1', { state: 'live' }); app.send('control', '1', { enabled: true });
  app.send('suspend'); app.select('desktop-a', '2'); const next = app.connect('2');
  assert.equal(next.viewOnly, true);
  assert.equal(next.focused, 0);
  assert.equal(next.focusOnClick, false);
});

test('Sleeping retains at most two target pictures and account clearing forgets both', () => {
  const app = viewer();
  for (const [target, generation] of [['desktop-a', '1'], ['desktop-b', '2'], ['desktop-c', '3']]) {
    app.select(target, generation);
    app.connect(generation).emit('paintedframe'); app.flush();
    app.send('suspend', generation);
    assert.equal(app.elements.get('#still').hidden, false);
  }
  app.select('desktop-a', '4');
  assert.equal(app.elements.get('#still').hidden, true);
  app.select('desktop-b', '5');
  assert.equal(app.elements.get('#still').hidden, false);
  app.send('forget', '5');
  assert.equal(app.elements.get('#still').hidden, true);
  assert.equal(app.elements.get('#still').width, 1);
  assert.equal(app.elements.get('#still').height, 1);
  for (const [target, generation] of [['desktop-b', '6'], ['desktop-c', '7']]) {
    app.select(target, generation);
    assert.equal(app.elements.get('#still').hidden, true);
  }
});

test('A 4K resize replaces the old still with proportionally downsampled current pixels', () => {
  const app = viewer(); app.select(); app.connect().emit('paintedframe'); app.flush();
  app.send('suspend');
  app.select('desktop-a', '2'); const next = app.connect('2');
  const current = { width: 3840, height: 2160, image: 'resized-current-frame' };
  app.elements.get('#screen').canvas = current;
  next.emit('paintedframe'); app.flush(); app.operations.length = 0;
  app.send('suspend', '2');
  const capture = app.operations.find(op => Array.isArray(op) && op[0] === 'draw');
  assert.equal(capture[1], current);
  const width = capture[4], height = capture[5];
  assert.ok(width * height <= 4 * 1024 * 1024);
  assert.ok(Math.abs(width / height - 3840 / 2160) < 0.002);
  assert.equal(app.elements.get('#still').hidden, false);
  assert.equal(app.elements.get('#still').width, width);
  assert.equal(app.elements.get('#still').height, height);
  app.select('desktop-a', '3');
  assert.equal(app.elements.get('#still').width, width);
});

test('Pinned Display increments its presentation counter only after a damaged draw', () => {
  const draws = [];
  const context2d = { drawImage(...args) { draws.push(args); }, fillRect() {} };
  const canvas = { width: 16, height: 16, style: {}, getContext() { return context2d; } };
  const source = read('src/computer/vendor/novnc/core/display.js')
    .replace(/^import .*;\n/gm, '').replace('export default class Display', 'globalThis.Display = class Display');
  assert.ok(source.length > 0, 'the vendored display module ships with the app');
  const context = { Log: { Debug() {} }, navigator: { userAgent: 'unit fixture' }, document: { createElement() { return canvas; } } };
  vm.runInNewContext(source, context);
  const display = new context.Display(canvas);
  assert.equal(display.paintSerial, 0);
  display.flip();
  assert.equal(display.paintSerial, draws.length);
  const previous = display.paintSerial;
  display.flip();
  assert.equal(display.paintSerial, previous);
  display.fillRect(0, 0, 4, 4, [0, 0, 0]);
  assert.equal(display.paintSerial, previous);
  display.flip();
  assert.equal(display.paintSerial, previous + 1);
  assert.equal(display.paintSerial, draws.length);
});

function pinnedRFB() {
  const context = { EventTargetMixin: class {}, Log: { Debug() {} }, clearTimeout, CustomEvent: class { constructor(type) { this.type = type; } } };
  const encodings = read('src/computer/vendor/novnc/core/encodings.js')
    .replace('export const encodings', 'globalThis.encodings').replace('export function encodingName', 'function encodingName');
  assert.ok(encodings.length > 0, 'the vendored encodings module ships with the app');
  vm.runInNewContext(encodings, context);
  const source = read('src/computer/vendor/novnc/core/rfb.js')
    .replace(/^import .*;\n/gm, '').replace('export default class RFB', 'globalThis.RFB = class RFB');
  assert.ok(source.length > 0, 'the vendored RFB module ships with the app');
  vm.runInNewContext(source, context);
  return context;
}

test('Actual noVNC teardown captures the current target before removing its canvas', () => {
  const { RFB } = pinnedRFB();
  const app = viewer(); app.select(); const rfb = app.connect();
  rfb.emit('paintedframe'); app.flush(); app.operations.length = 0;
  const current = app.elements.get('#screen').canvas;
  Object.assign(rfb, {
    _cursor: { detach() {} }, _canvas: { removeEventListener() {} }, _eventHandlers: {},
    _resizeObserver: { disconnect() {} }, _keyboard: { ungrab() {} }, _gestures: { detach() {} },
    _sock: { close() {} }, _target: app.elements.get('#screen'), _screen: {},
    dispatchEvent(event) { this.emit(event.type); },
  });
  RFB.prototype._disconnect.call(rfb);
  assert.equal(app.elements.get('#screen').querySelector('canvas'), null);
  rfb.emit('disconnect');
  const capture = app.operations.findIndex(op => Array.isArray(op) && op[0] === 'draw' && op[1] === current);
  assert.ok(capture >= 0 && capture < app.operations.indexOf('remove'));
  assert.equal(app.elements.get('#still').hidden, false);
  assert.ok(app.sent.includes('capability|1|lost'));
  app.select('desktop-b', '2');
  assert.equal(app.elements.get('#still').hidden, true);
  rfb.emit('beforedisconnect');
  app.select('desktop-a', '3');
  assert.equal(app.elements.get('#still').hidden, false);
});

test('Completed RFB cursor, resize, and copy-only updates never report first pixels', async () => {
  const { RFB, encodings } = pinnedRFB();
  for (const encoding of [encodings.pseudoEncodingVMwareCursor, encodings.pseudoEncodingDesktopSize, encodings.encodingCopyRect]) {
    const events = [];
    const rfb = Object.create(RFB.prototype);
    Object.assign(rfb, {
      _FBU: { rects: 1, encoding, width: 10, height: 10 },
      _rfbConnectionState: 'connected', _handleRect() { return true; },
      _display: { paintSerial: 0, flip() { this.paintSerial++; }, flush() { return Promise.resolve(); } },
      dispatchEvent(event) { events.push(event.type); },
    });
    assert.equal(rfb._framebufferUpdate(), true);
    await Promise.resolve();
    assert.deepEqual(events, []);
  }
});

test('A real TightPNG pixel update waits for the display flush before reporting a frame', async () => {
  const { RFB, encodings } = pinnedRFB();
  let finish;
  const events = [];
  const rfb = Object.create(RFB.prototype);
  Object.assign(rfb, {
    _FBU: { rects: 1, encoding: encodings.encodingTightPNG, width: 10, height: 10 },
    _rfbConnectionState: 'connected', _handleRect() { return true; },
    _display: { paintSerial: 0, flip() {}, flush() { return new Promise(resolve => { finish = resolve; }); } },
    dispatchEvent(event) { events.push(event.type); },
  });
  assert.equal(rfb._framebufferUpdate(), true);
  await Promise.resolve();
  assert.deepEqual(events, []);
  rfb._display.paintSerial++;
  finish();
  await Promise.resolve();
  assert.deepEqual(events, ['paintedframe']);
});

test('RFB rejects unauthenticated security even when the server prefers it', () => {
  const { RFB } = pinnedRFB();
  for (const types of [[1, 2], [1]]) {
    const chosen = [];
    const rfb = Object.create(RFB.prototype);
    Object.assign(rfb, {
      _rfbVersion: 3.8,
      _sock: { rQshift8() { return types.length; }, rQwait() { return false; }, rQshiftBytes() { return types; }, sQpush8(type) { chosen.push(type); }, flush() {} },
      _fail() { return false; },
    });
    assert.equal(rfb._negotiateSecurity(), types.includes(2));
    assert.deepEqual(chosen, types.includes(2) ? [2] : []);
  }
});

test('RFB releases tracked keyboard state and zeroes the remote pointer mask before flushing', () => {
  const { RFB } = pinnedRFB();
  const sent = [];
  const rfb = Object.create(RFB.prototype);
  Object.assign(rfb, {
    _keyboard: { ungrab() { sent.push('key-ups'); } }, _viewOnly: false, _rfbConnectionState: 'connected',
    _mousePos: { x: 12, y: 34 }, _mouseButtonMask: 5,
    _flushMouseMoveTimer() { sent.push('move'); },
    _sendMouse(x, y, mask) { sent.push([x, y, mask]); },
    _sock: { flush() { sent.push('flush'); } },
  });
  rfb.releaseInput();
  assert.deepEqual(sent, ['key-ups', 'move', [12, 34, 0], 'flush']);
  assert.equal(rfb._mouseButtonMask, 0);
  sent.length = 0; rfb._viewOnly = true; rfb._mouseButtonMask = 3;
  rfb.releaseInput();
  assert.deepEqual(sent, ['key-ups']);
  assert.equal(rfb._mouseButtonMask, 0);
});
