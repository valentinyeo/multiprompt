import base64
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import threading
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
OUTER = {'__name__': 'picture_test_bundle'}
exec(compile((ROOT / 'src/chat_history_reader.py').read_text(), '<bundle>', 'exec'), OUTER)
READER = {'__name__': 'picture_test_reader'}
exec(compile(OUTER['READER_SOURCE'], '<reader>', 'exec'), READER)
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=')


class PictureTest(unittest.TestCase):
    def setUp(self):
        self.assertTrue(callable(READER.get('generate_bot_picture')), 'the server helper must generate bot pictures')
        self.requests = []
        self.status = 200
        self.body = {'data': [{'b64_json': base64.b64encode(PNG).decode()}]}
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                owner.requests.append((self.path, self.headers.get('Authorization'), json.loads(self.rfile.read(int(self.headers['Content-Length'])))))
                self.send_response(owner.status)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps(owner.body).encode())

            def log_message(self, *_):
                pass

        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.close_server)
        self.endpoint = f'http://127.0.0.1:{self.server.server_port}/v1/images/generations'
        self.env = patch.dict(os.environ, {'OPENAI_API_KEY': 'test-picture-token'}, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)

    def close_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def generate(self, prompt='orange fox with glasses'):
        return READER['generate_bot_picture'](prompt, endpoint=self.endpoint)

    def test_one_small_low_quality_png_from_description(self):
        self.assertEqual(base64.b64decode(self.generate()['png']), PNG)
        self.assertEqual(len(self.requests), 1)
        path, authorization, body = self.requests[0]
        self.assertEqual(path, '/v1/images/generations')
        self.assertEqual(authorization, 'Bearer test-picture-token')
        self.assertEqual(body, {'model': 'gpt-image-1-mini', 'prompt': 'orange fox with glasses', 'n': 1, 'size': '1024x1024', 'quality': 'low', 'output_format': 'png'})

    def test_missing_key_is_plain_failure_without_a_request(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(self.generate(), {'error': 'picture service not set up'})
        self.assertEqual(self.requests, [])

    def test_invalid_descriptions_never_call_the_endpoint(self):
        for prompt in ['', '  ', None, 42, 'x' * 2001]:
            self.assertEqual(self.generate(prompt), {'error': 'Describe the picture in 2000 characters or fewer'})
        self.assertEqual(self.requests, [])

    def test_provider_failure_is_sanitized_and_never_retried(self):
        self.status = 429
        self.body = {'error': {'message': 'private provider detail test-picture-token'}}
        self.assertEqual(self.generate(), {'error': 'Picture service is busy. Try again'})
        self.assertEqual(len(self.requests), 1)

    def test_rejected_prompt_has_a_real_failure(self):
        self.status = 400
        self.assertEqual(self.generate(), {'error': 'Could not make that picture. Try another description'})
        self.assertEqual(len(self.requests), 1)

    def test_bad_images_and_multiple_results_are_not_previews(self):
        for body in [{}, {'data': []}, {'data': [{'b64_json': 'bad'}]}, {'data': [{'b64_json': base64.b64encode(b'not an image').decode()}]}, {'data': [{}, {}]}]:
            self.body = body
            self.assertEqual(self.generate(), {'error': 'Picture service returned an invalid picture'})

    def test_transport_timeout_is_plain_and_does_not_retry(self):
        with patch('urllib.request.urlopen', side_effect=TimeoutError('private detail')) as opened:
            self.assertEqual(self.generate(), {'error': 'Picture service took too long. Try again'})
        self.assertEqual(opened.call_count, 1)
        self.assertLessEqual(opened.call_args.kwargs['timeout'], 20)

    def test_serve_request_returns_the_picture_without_history_or_keys(self):
        replies = []
        generate = READER['generate_bot_picture']
        with patch.dict(READER, ensure_runtime_tools=lambda: None, host_switch_follow=lambda _: None, serve_print=replies.append, generate_bot_picture=lambda prompt: generate(prompt, endpoint=self.endpoint)):
            READER['serve_request'](json.dumps({'id': 7, 'op': 'bot_picture', 'description': 'orange fox with glasses'}), None, {}, threading.Lock())
        self.assertEqual(replies, [{'id': 7, 'result': {'png': base64.b64encode(PNG).decode()}}])
        self.assertNotIn('test-picture-token', json.dumps(replies))
        self.assertEqual(len(self.requests), 1)


if __name__ == '__main__':
    unittest.main()
