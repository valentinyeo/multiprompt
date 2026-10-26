import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const [portFile, outDir, secret] = process.argv.slice(2);
if (!portFile || !outDir || !secret) {
  console.error('usage: screenshot-upload-receiver.mjs <port-file> <out-dir> <secret>');
  process.exit(2);
}

const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
fs.mkdirSync(outDir, { recursive: true });
let uploads = 0;

const server = http.createServer((request, response) => {
  const chunks = [];
  request.on('data', chunk => chunks.push(chunk));
  request.on('end', () => {
    const body = Buffer.concat(chunks);
    if (request.method !== 'POST' || request.url !== '/api/upload-screenshot') {
      response.writeHead(404).end('not found');
      return;
    }
    if (request.headers.authorization !== `Bearer ${secret}`) {
      response.writeHead(401).end('bad secret');
      return;
    }
    if (body.indexOf(PNG_SIGNATURE) < 0) {
      response.writeHead(400).end('not a PNG');
      return;
    }
    uploads += 1;
    fs.appendFileSync(path.join(outDir, 'uploads.jsonl'), `${JSON.stringify({ n: uploads, bytes: body.length })}\n`);
    response.writeHead(200, { 'content-type': 'application/json' });
    response.end(JSON.stringify({ success: true, url: `https://example.invalid/shot-${uploads}.png` }));
  });
});

server.listen(0, '127.0.0.1', () => {
  fs.writeFileSync(`${portFile}.tmp`, String(server.address().port));
  fs.renameSync(`${portFile}.tmp`, portFile);
});
