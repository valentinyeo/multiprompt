import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';

import { OFFICIAL_BASE, archiveName, digest, download, sourceList } from './zig-download.mjs';

const version = '0.16.0';
const target = 'x86_64-linux';
const file = archiveName(version, target);
const archive = Buffer.alloc(256 * 1024, 'zig-archive-bytes');
const sha256 = crypto.createHash('sha256').update(archive).digest('hex');
const quiet = () => {};

function scratch(t) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'zig-download-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  return path.join(directory, file);
}

function serve(t, handler) {
  const sockets = new Set();
  const server = http.createServer(handler);
  server.on('connection', (socket) => {
    sockets.add(socket);
    socket.on('close', () => sockets.delete(socket));
  });
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      t.after(() => new Promise((done) => {
        for (const socket of sockets) socket.destroy();
        server.close(done);
      }));
      resolve(`http://127.0.0.1:${port}`);
    });
  });
}

async function closedPort(t) {
  const server = net.createServer();
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  await new Promise((resolve) => server.close(resolve));
  return `http://127.0.0.1:${port}`;
}

function healthy() {
  return (request, response) => {
    response.writeHead(200, { 'content-length': archive.length });
    response.end(archive);
  };
}

test('a source that answers installs the archive and the checksum holds', async (t) => {
  const dest = scratch(t);
  const good = await serve(t, healthy());
  const result = await download({ version, target, sha256, dest, sources: [good], log: quiet });
  assert.equal(result.source, good);
  assert.equal(digest(dest), sha256);
  assert.equal(fs.readFileSync(dest).length, archive.length);
});

test('a first source that is unreachable hands over to the fallback mirror', async (t) => {
  const dest = scratch(t);
  const dead = await closedPort(t);
  const good = await serve(t, healthy());
  const lines = [];
  const result = await download({ version, target, sha256, dest, sources: [dead, good], perSourceMs: 5000, log: (line) => lines.push(line) });
  assert.equal(result.source, good, lines.join('\n'));
  assert.equal(digest(dest), sha256);
  assert.match(lines.join('\n'), new RegExp(`did not deliver ${file.replace(/[.]/g, '\\.')}`));
  assert.ok(!fs.existsSync(`${dest}.part`));
});

test('a first source that stalls mid file hands over to the fallback mirror', async (t) => {
  const dest = scratch(t);
  const stalled = await serve(t, (request, response) => {
    response.writeHead(200, { 'content-length': archive.length });
    response.write(archive.subarray(0, 4096));
  });
  const good = await serve(t, healthy());
  const result = await download({ version, target, sha256, dest, sources: [stalled, good], stallMs: 300, perSourceMs: 10000, log: quiet });
  assert.equal(result.source, good);
  assert.equal(digest(dest), sha256);
});

test('a mirror whose bytes do not match the pinned checksum installs nothing', async (t) => {
  const dest = scratch(t);
  const corrupt = await serve(t, (request, response) => {
    response.writeHead(200, { 'content-length': archive.length });
    response.end(Buffer.alloc(archive.length, 'not-the-pinned-archive'));
  });
  await assert.rejects(
    download({ version, target, sha256, dest, sources: [corrupt], perSourceMs: 5000, log: quiet }),
    /checksum/,
  );
  assert.ok(!fs.existsSync(dest));
  assert.ok(!fs.existsSync(`${dest}.part`));
});

test('the source list starts at the official download and drops duplicates', () => {
  const mirrors = `https://mirror.one/zig\n# a comment line\nhttps://mirror.two/zig/\nhttps://mirror.one/zig\n`;
  const list = sourceList({ mirrorsText: mirrors, extra: ['https://extra.example/zig/'] });
  assert.equal(list[0], OFFICIAL_BASE);
  assert.equal(list.filter((source) => source === 'https://mirror.one/zig').length, 1);
  assert.ok(list.includes('https://mirror.two/zig'), list.join('\n'));
  assert.ok(list.includes('https://extra.example/zig'), list.join('\n'));
});
