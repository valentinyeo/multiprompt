import base64
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import sys
import threading
from unittest.mock import patch

if '-V' in sys.argv:
    print('OpenSSH_9.0 picture verification boundary', file=sys.stderr)
    raise SystemExit(0)
if '-c' not in sys.argv:
    raise SystemExit(0)

root = Path(os.environ['MP_PICTURE_FIXTURE'])
release = threading.Event()
base64.b64decode(sys.stdin.buffer.readline())
bundle = base64.b64decode(sys.stdin.buffer.readline()).decode()
outer = {'__name__': 'picture_fixture_bundle'}
exec(compile(bundle, '<app-picture-bundle>', 'exec'), outer)
reader = {'__name__': 'picture_fixture_reader'}
exec(compile(outer['READER_SOURCE'], '<app-picture-reader>', 'exec'), reader)


def emit(value):
    print(json.dumps(value, separators=(',', ':')), flush=True)


class Endpoint(BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        release.clear()
        with (root / 'calls.jsonl').open('a') as log:
            log.write(json.dumps(body) + '\n')
        if not release.wait(timeout=10):
            self.send_error(504)
            return
        request_count = len((root / 'calls.jsonl').read_text().splitlines())
        png = (root / ('first.png' if request_count % 2 else 'second.png')).read_bytes()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({'data': [{'b64_json': base64.b64encode(png).decode()}]}).encode())

    def do_GET(self):
        release.set()
        self.send_response(200)
        self.end_headers()

    def log_message(self, *_):
        pass


server = ThreadingHTTPServer(('127.0.0.1', 0), Endpoint)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
generate = reader['generate_bot_picture']
endpoint = f'http://127.0.0.1:{server.server_port}/v1/images/generations'
(root / 'endpoint').write_text(endpoint)
reader['generate_bot_picture'] = lambda prompt: generate(prompt, endpoint=endpoint)
reader['ensure_runtime_tools'] = lambda: None
emit({'ready': True})
try:
    for line in sys.stdin:
        packet = json.loads(line)
        if packet.get('close'):
            continue
        query = packet.get('data', '')
        if not query:
            continue
        cid = packet['channel']
        if json.loads(query).get('op') != 'bot_picture':
            emit({'channel': cid, 'closed': True})
            continue
        reader['serve_print'] = lambda value: emit({'channel': cid, 'data': json.dumps(value)})
        mode = (root / 'mode').read_text().strip()
        with patch.dict(os.environ, {'OPENAI_API_KEY': '' if mode == 'missing-key' else 'fixture-not-a-real-key'}):
            reader['serve_request'](query, None, {}, threading.Lock())
finally:
    server.shutdown()
    server.server_close()
    thread.join(timeout=2)
