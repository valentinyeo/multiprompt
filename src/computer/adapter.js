import RFB from './vendor/novnc/core/rfb.js';
import { initLogging } from './vendor/novnc/core/util/logging.js';

initLogging('none');
const token = location.pathname.split('/')[1];
const bridge = window.chrome.webview;
const pane = document.querySelector('#pane');
const screen = document.querySelector('#screen');
const still = document.querySelector('#still');
const overlay = document.querySelector('#overlay');
const message = document.querySelector('#message');
const label = document.querySelector('#label');
const control = document.querySelector('#control');
const wide = document.querySelector('#wide');
const retry = document.querySelector('#retry');
let generation = '0';
let target = '';
let rfb = null;
let lease = null;
let state = 'sleeping';
let controlling = false;
let words = null;
let host = '';
let painted = false;
const pictures = new Map();
const maxPixels = 4 * 1024 * 1024;

function emit(event, owner = generation) {
    bridge.postMessage(`${token}|${owner}|${event}`);
}

function render() {
    if (!words) return;
    pane.classList.toggle('control', controlling);
    pane.classList.toggle('live', state === 'live');
    overlay.hidden = state === 'live';
    message.textContent = words[state];
    label.textContent = controlling ? words.in_control : `${host || words.computer} · ${words[state]}`;
    control.textContent = controlling ? words.give_back : words.take_control;
    control.disabled = state !== 'live';
    wide.textContent = '⤢';
    wide.title = words.full_width;
    wide.setAttribute('aria-label', words.full_width);
    retry.textContent = words.retry;
    retry.hidden = state !== 'lost';
}

function revoke() {
    if (rfb) {
        rfb.releaseInput();
        rfb.viewOnly = true;
        rfb.focusOnClick = false;
        rfb.blur();
    }
    controlling = false;
    render();
}

function savePicture() {
    if (!rfb || !target || !painted) return;
    const canvas = screen.querySelector('canvas');
    if (!canvas || !canvas.width || !canvas.height) return;
    const scale = Math.min(1, Math.sqrt(maxPixels / (canvas.width * canvas.height)));
    const copy = document.createElement('canvas');
    copy.width = Math.max(1, Math.floor(canvas.width * scale));
    copy.height = Math.max(1, Math.floor(canvas.height * scale));
    copy.getContext('2d').drawImage(canvas, 0, 0, copy.width, copy.height);
    pictures.delete(target);
    pictures.set(target, copy);
    while (pictures.size > 2) pictures.delete(pictures.keys().next().value);
}

function showPicture() {
    const picture = pictures.get(target);
    still.hidden = !picture;
    still.width = picture ? picture.width : 1;
    still.height = picture ? picture.height : 1;
    const ctx = still.getContext('2d');
    ctx.clearRect(0, 0, still.width, still.height);
    if (picture) ctx.drawImage(picture, 0, 0);
}

function stop() {
    revoke();
    savePicture();
    const previous = rfb;
    rfb = null;
    lease = null;
    if (previous) previous.disconnect();
    screen.replaceChildren();
    painted = false;
    showPicture();
}

bridge.addEventListener('message', event => {
    const data = event.data;
    if (!data || data.token !== token || typeof data.generation !== 'string') return;
    if (data.command === 'transfer' && data.previous === generation && target && rfb && lease) {
        revoke();
        generation = data.generation;
        lease = Object.freeze({ rfb, generation, desktop: target });
        render();
        return;
    }
    if (data.command === 'select') {
        stop();
        generation = data.generation;
        target = data.target;
        host = data.host;
        words = data.words;
        state = data.state;
        showPicture();
        render();
        return;
    }
    if (data.generation !== generation) return;
    if (data.command === 'forget') {
        stop();
        pictures.clear();
        target = '';
        still.width = still.height = 1;
        still.hidden = true;
        render();
    } else if (data.command === 'suspend') {
        stop();
        state = 'sleeping';
        render();
        emit('stopped');
    } else if (data.command === 'state') {
        state = data.state;
        if (state !== 'live') revoke();
        render();
    } else if (data.command === 'control') {
        if (data.enabled && state === 'live' && rfb) {
            controlling = true;
            rfb.releaseInput();
            rfb.viewOnly = false;
            rfb.focusOnClick = true;
            rfb.focus();
        } else {
            revoke();
        }
        render();
    } else if (data.command === 'connect') {
        stop();
        const desktop = target;
        const password = data.password;
        data.password = '';
        const next = new RFB(screen, `ws://127.0.0.1:${data.port}/`, { credentials: { password }, shared: true });
        rfb = next;
        lease = Object.freeze({ rfb: next, generation, desktop });
        next.viewOnly = true;
        next.focusOnClick = false;
        next.scaleViewport = true;
        next.resizeSession = false;
        next.clipViewport = false;
        next.addEventListener('credentialsrequired', () => {
            const owner = lease;
            if (owner && owner.rfb === next) { revoke(); next.disconnect(); emit('lost', owner.generation); }
        });
        next.addEventListener('securityfailure', () => {
            const owner = lease;
            if (owner && owner.rfb === next) { revoke(); emit('lost', owner.generation); }
        });
        next.addEventListener('beforedisconnect', () => {
            const owner = lease;
            if (!owner || owner.rfb !== next || owner.desktop !== target || owner.generation !== generation) return;
            revoke();
            savePicture();
            showPicture();
        });
        next.addEventListener('disconnect', () => {
            const owner = lease;
            if (!owner || owner.rfb !== next || owner.desktop !== target) return;
            revoke();
            emit('lost', owner.generation);
        });
        next.addEventListener('paintedframe', () => {
            const owner = lease;
            if (!owner || owner.rfb !== next) return;
            requestAnimationFrame(() => requestAnimationFrame(() => {
                if (!owner || owner !== lease || owner.rfb !== rfb || owner.desktop !== target || document.hidden) return;
                painted = true;
                still.hidden = true;
                if (state !== 'live') emit('painted', owner.generation);
            }));
        });
        next.addEventListener('clipboard', () => {});
    }
});

control.addEventListener('click', event => {
    if (event.isTrusted && state === 'live') emit(controlling ? 'give' : 'take');
});
wide.addEventListener('click', event => { if (event.isTrusted) emit('wide'); });
retry.addEventListener('click', event => { if (event.isTrusted && state === 'lost') emit('retry'); });
window.addEventListener('blur', () => { revoke(); emit('give'); });
document.addEventListener('visibilitychange', () => { if (document.hidden) { revoke(); emit('give'); } });
for (const name of ['copy', 'cut', 'paste', 'drop', 'dragover', 'contextmenu']) {
    document.addEventListener(name, event => event.preventDefault(), true);
}
emit('ready', '0');
