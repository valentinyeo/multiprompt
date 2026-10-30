"""Hosted-only native Codex hook smoke; all provider traffic is net-namespaced."""
import http.server
import importlib.util
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import threading
import time


class LocalProvider(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'{"data":[]}')

    def do_POST(self):
        self.rfile.read(int(self.headers.get('Content-Length', '0')))
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.end_headers()
        events = [
            {'type': 'response.created', 'response': {'id': 'resp_fixture', 'object': 'response', 'status': 'in_progress', 'output': []}},
            {'type': 'response.completed', 'response': {'id': 'resp_fixture', 'object': 'response', 'status': 'completed', 'output': [], 'usage': {'input_tokens': 0, 'output_tokens': 0, 'total_tokens': 0}}},
        ]
        for event in events:
            self.wfile.write(('event: ' + event['type'] + '\ndata: ' + json.dumps(event) + '\n\n').encode())
        self.wfile.write(b'data: [DONE]\n\n')


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_OS') != 'Linux':
        raise SystemExit('GitHub-hosted Linux only')
    modules = Path(sys.argv[1]).absolute().parent.parent / '@openai'
    binaries = []
    for candidate in modules.rglob('codex'):
        if candidate.is_file():
            with candidate.open('rb') as source:
                if source.read(4) == b'\x7fELF':
                    binaries.append(candidate.resolve())
    if len(set(binaries)) != 1:
        raise AssertionError('expected one official native Codex binary')
    cli = binaries[0]
    repo = Path(__file__).resolve().parents[2]
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), LocalProvider)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    with tempfile.TemporaryDirectory(prefix='mp-codex-hook-') as temp:
        home = Path(temp)
        config = home / '.codex'
        config.mkdir()
        work = home / 'workspace'
        work.mkdir()
        subprocess.run(['git', 'init', '-q', str(work)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        (config / 'config.toml').write_text(
            'model = "fixture"\nmodel_provider = "fixture"\n'
            f'[projects."{work}"]\ntrust_level = "trusted"\n'
            '[model_providers.fixture]\nname = "fixture"\n'
            f'base_url = "http://127.0.0.1:{server.server_port}/v1"\n'
            'wire_api = "responses"\nenv_key = "OPENAI_API_KEY"\n')
        observer = repo / 'tools/verify-codex-hook/observe-hook.py'
        command = shlex.join([sys.executable, str(observer)])
        (config / 'hooks.json').write_text(json.dumps({'hooks': {'SessionStart': [{'hooks': [{'type': 'command', 'command': command, 'timeout': 5}]}]}}))
        env = dict(PATH=os.environ.get('PATH', '/usr/bin:/bin'), HOME=str(home), CODEX_HOME=str(config),
                   OPENAI_API_KEY='fixture-only', MULTIPROMP_NOTIFY_RELAY_TOKEN='fixture-only', TERM='xterm-256color',
                   HTTP_PROXY='http://127.0.0.1:9', HTTPS_PROXY='http://127.0.0.1:9',
                   ALL_PROXY='http://127.0.0.1:9', NO_PROXY='127.0.0.1,localhost',
                   OTEL_SDK_DISABLED='true', MP_SMOKE_HOOK_DIAGNOSTIC=str(home / 'hook-observations.jsonl'))
        socket = 'mp-codex-smoke-' + str(os.getpid())
        def tmux(*args):
            return subprocess.run(['tmux', '-L', socket, *args], env=env, check=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True).stdout.strip()
        try:
            diagnostic = home / 'hook-observations.jsonl'
            def observations():
                return [json.loads(line) for line in diagnostic.read_text().splitlines()] if diagnostic.exists() else []
            def wait_for(predicate, description, timeout=35):
                deadline = time.monotonic() + timeout
                while time.monotonic() < deadline:
                    value = predicate()
                    if value:
                        return value
                    time.sleep(0.1)
                raise AssertionError(description)
            def start(name, resume=None):
                arguments = [str(cli), '--yolo', '--dangerously-bypass-hook-trust', '--enable', 'hooks']
                if resume:
                    arguments.extend(['resume', resume])
                tmux('new-session', '-d', '-s', name, '-c', str(work), 'exec ' + shlex.join(arguments))
            start('smoke-a')
            first = wait_for(lambda: observations()[:1], 'first native SessionStart missing')[0]
            sid = first.get('session_id')
            assert sid and first.get('transcript_path'), 'first hook lacks session identity'
            print(json.dumps({'hook_event': first.get('hook_event_name'), 'hook_ancestors': first['ancestors']}), flush=True)
            tmux('send-keys', '-t', 'smoke-a:0.0', 'synthetic fixture', 'Enter')
            spec = importlib.util.spec_from_file_location('reader', repo / 'src/chat_history_reader.py')
            reader = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(reader)
            reader.HOME = home
            socket_path = tmux('display-message', '-p', '-t', 'smoke-a:0.0', '#{socket_path}')
            os.environ['TMUX'] = socket_path + ',0,0'
            def response(name):
                query = dict(id=7, codex=True, sid='', tmux=name, cwd=str(work), cached_sid='', inode=0, offset=0, follow=True)
                return reader.response(query)
            pane = int(tmux('display-message', '-p', '-t', 'smoke-a:0.0', '#{pane_pid}'))
            table = reader.process_table(pids=[pane])
            native = reader.agent_pid_for_panes([pane], table, 'codex')
            assert native and reader.open_codex_transcript(native, table) == set(), 'pane must have zero rollout FDs'
            def first_response():
                wire = response('smoke-a')
                return wire if '\thistory\tok\t' + sid + '\t' in wire else None
            wire = wait_for(first_response, 'pane-to-backend response not established')
            assert '\thistory\tok\t' + sid + '\t' in wire
            start('smoke-b', resume=sid)
            second = wait_for(lambda: observations()[1:2], 'second native SessionStart missing')[0]
            assert second.get('session_id') == sid, 'second client did not resume the first thread'
            backends = [(pid, value) for pid, value in reader.process_table().items()
                        if 'app-server' in value[1] and '--listen' in value[1]]
            assert len(backends) == 1, 'expected one default daemon backend'
            backend, value = backends[0]
            sources = reader.open_codex_transcript(backend, {backend: value})
            assert sources is not None and len(sources) == 1, 'two-client one-writer precondition not observed'
            assert '\thistory\tmissing\t' in response('smoke-a')
            assert '\thistory\tmissing\t' in response('smoke-b')
            tmux('kill-session', '-t', 'smoke-b')
            wait_for(lambda: '\thistory\tok\t' + sid + '\t' in response('smoke-a'), 'single-client binding did not recover')
            count = len(observations())
            tmux('send-keys', '-t', 'smoke-a:0.0', '/new', 'Enter')
            switched = wait_for(lambda: [row for row in observations()[count:] if row.get('session_id') and row['session_id'] != sid],
                                'independent new-session selection event not observed')[0]
            assert int(tmux('display-message', '-p', '-t', 'smoke-a:0.0', '#{pane_pid}')) == pane, 'TUI process changed'
            current_sources = reader.open_codex_transcript(backend, {backend: value})
            old_writer = current_sources is not None and any(item[0] == sid for item in current_sources)
            new_path = switched.get('transcript_path')
            new_exists = Path(new_path).exists() if isinstance(new_path, str) and new_path else None
            old_wire = response('smoke-a')
            print(json.dumps({'switch_event': switched.get('source'), 'new_transcript_exists': new_exists,
                              'old_writer_open': old_writer, 'old_thread_returned': '\thistory\tok\t' + sid + '\t' in old_wire}), flush=True)
            assert ('\thistory\tmissing\t' in old_wire or
                    '\thistory\tok\t' + switched['session_id'] + '\t' in old_wire), 'old or unrelated thread exposed after selection changed'
            print('native default daemon: isolation and selection controls verified')
        except Exception:
            try:
                pane_text = tmux('capture-pane', '-p', '-t', 'smoke-a:0.0', '-S', '-50')
                print('scratch native pane:', pane_text.replace('fixture-only', '[redacted]')[-2000:], flush=True)
            except subprocess.SubprocessError:
                print('scratch native pane unavailable', flush=True)
            raise
        finally:
            subprocess.run(['tmux', '-L', socket, 'kill-server'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            server.shutdown()


if __name__ == '__main__':
    main()
