const SLOT_COUNT = 3;
const MAX_FRAME = 16 * 1024 * 1024;
const MAX_DESKTOPS = 8;

export const relaySlot = value => {
  if (typeof value === 'string') return /^[0-2]$/.test(value) ? Number(value) : null;
  return Number.isInteger(value) && value >= 0 && value < SLOT_COUNT ? value : null;
};

export const frameTooLarge = data => {
  if (typeof data === 'string') return data.length > MAX_FRAME;
  if (data instanceof ArrayBuffer) return data.byteLength > MAX_FRAME;
  if (ArrayBuffer.isView(data)) return data.byteLength > MAX_FRAME;
  return false;
};

const reply = (value, status = 200) => new Response(JSON.stringify(value), {
  status,
  headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer' }
});

const shut = (socket, code, reason) => { try { socket.close(code, reason); } catch {} };
const forward = (socket, data) => { try { socket.send(data); } catch {} };

export class RelayRoom {
  constructor(state) {
    this.state = state;
    this.slots = Array.from({ length: SLOT_COUNT }, () => ({ server: null, desktops: new Set() }));
  }

  presence() {
    return this.slots.map((entry, slot) => ({ slot, server: Boolean(entry.server), desktops: entry.desktops.size }));
  }

  detach(entry, socket) {
    if (entry.server === socket) entry.server = null;
    entry.desktops.delete(socket);
  }

  guard(entry, socket, deliver) {
    socket.addEventListener('close', () => this.detach(entry, socket));
    socket.addEventListener('error', () => this.detach(entry, socket));
    socket.addEventListener('message', event => {
      if (frameTooLarge(event.data)) return shut(socket, 1009, 'frame_too_large');
      deliver(event.data);
    });
  }

  attach(role, slot, socket) {
    const entry = this.slots[slot];
    if (role === 'server') {
      if (entry.server) { shut(entry.server, 4000, 'replaced'); entry.server = null; }
      entry.server = socket;
      this.guard(entry, socket, data => { for (const desktop of entry.desktops) forward(desktop, data); });
      return;
    }
    entry.desktops.add(socket);
    this.guard(entry, socket, data => { if (entry.server) forward(entry.server, data); });
  }

  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === '/presence') return reply({ slots: this.presence() });
    const role = url.searchParams.get('role');
    const slot = relaySlot(url.searchParams.get('slot'));
    if ((role !== 'server' && role !== 'desktop') || slot === null) return reply({ error: 'invalid_relay_slot' }, 400);
    if ((request.headers.get('Upgrade') || '').toLowerCase() !== 'websocket') return reply({ error: 'upgrade_required' }, 426);
    if (role === 'desktop' && this.slots[slot].desktops.size >= MAX_DESKTOPS) return reply({ error: 'relay_busy' }, 429);
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();
    this.attach(role, slot, server);
    return new Response(null, { status: 101, webSocket: client });
  }
}
