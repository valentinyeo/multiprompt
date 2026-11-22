const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');

if (process.platform !== 'win32' || process.env.GITHUB_ACTIONS !== 'true' || process.env.RUNNER_OS !== 'Windows' || process.env.MULTIPROMPT_NO_LOGIN !== '1') process.exit(1);
const dir = process.argv[2];
let count = 0;
let redirects = 0;
let redirectTargets = 0;
fs.writeFileSync(path.join(dir, 'redirect-targets.txt'), '0');
fs.writeFileSync(path.join(dir, 'redirect-authorization.txt'), 'false');
const server = http.createServer((req, res) => {
  if (req.url === '/redirect-target') {
    redirectTargets++;
    fs.writeFileSync(path.join(dir, 'redirect-targets.txt'), String(redirectTargets));
    if (req.headers.authorization) fs.writeFileSync(path.join(dir, 'redirect-authorization.txt'), 'true');
    res.writeHead(200).end();
    return;
  }
  let bytes = 0;
  req.on('data', chunk => { bytes += chunk.length; });
  req.on('end', () => {
    count++;
    const requestNumber = count;
    fs.writeFileSync(path.join(dir, 'requests.txt'), String(count));
    fs.writeFileSync(path.join(dir, 'length.txt'), String((req.headers.authorization || '').replace(/^Token /, '').length));
    if (req.method !== 'POST' || req.url !== '/v1/listen?model=nova-3' || !/^Token [!-~]{32,512}$/.test(req.headers.authorization || '') || req.headers['content-type'] !== 'audio/wav' || bytes !== 0) {
      fs.writeFileSync(path.join(dir, 'invalid.txt'), 'invalid request');
      res.writeHead(400).end();
      return;
    }
    const mode = fs.readFileSync(path.join(dir, 'mode.txt'), 'utf8').trim();
    if (mode === 'offline') { req.socket.destroy(); return; }
    if (mode === 'redirect') {
      redirects++;
      fs.writeFileSync(path.join(dir, 'redirects-sent.txt'), String(redirects));
      res.writeHead(302, { Location: '/redirect-target' }).end();
      return;
    }
    const [code, delay] = mode.split(':').map(Number);
    setTimeout(() => {
      if (!res.destroyed) res.writeHead(code).end(() => {
        if (delay) fs.writeFileSync(path.join(dir, 'delayed-completed.txt'), String(requestNumber));
      });
    }, delay || 0);
  });
});
server.listen(0, '127.0.0.1', () => fs.writeFileSync(path.join(dir, 'port.txt'), String(server.address().port)));
