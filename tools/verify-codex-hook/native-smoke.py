"""Hosted-only native Codex hook smoke; all provider traffic is net-namespaced."""
import base64
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
        body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.end_headers()
        with self.server.response_lock:
            number = len(self.server.responses) + 1
            reply = 'synthetic provider reply ' + str(number)
            self.server.responses.append(reply)
            hold = self.server.busy_armed and b'controlled synthetic busy prompt' in body
            if hold:
                self.server.busy_armed = False
                self.server.busy_reply = reply
        response_id = 'resp_fixture_' + str(number)
        message_id = 'msg_fixture_' + str(number)
        message = {'id': message_id, 'type': 'message', 'role': 'assistant', 'status': 'completed',
                   'content': [{'type': 'output_text', 'text': reply, 'annotations': []}]}
        events = [
            {'type': 'response.created', 'response': {'id': response_id, 'object': 'response', 'status': 'in_progress', 'output': []}},
            {'type': 'response.output_item.added', 'output_index': 0, 'item': dict(message, status='in_progress', content=[])},
            {'type': 'response.output_text.delta', 'item_id': message_id, 'output_index': 0, 'content_index': 0, 'delta': reply},
            {'type': 'response.output_text.done', 'item_id': message_id, 'output_index': 0, 'content_index': 0, 'text': reply},
            {'type': 'response.output_item.done', 'output_index': 0, 'item': message},
            {'type': 'response.completed', 'response': {'id': response_id, 'object': 'response', 'status': 'completed', 'output': [message], 'usage': {'input_tokens': 0, 'output_tokens': 0, 'total_tokens': 0}}},
        ]
        for event in events:
            self.wfile.write(('event: ' + event['type'] + '\ndata: ' + json.dumps(event) + '\n\n').encode())
            if hold and event['type'] == 'response.created':
                self.wfile.flush()
                self.server.busy_started.set()
                if not self.server.busy_release.wait(60):
                    self.server.busy_timed_out.set()
                    return
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
    server.response_lock = threading.Lock()
    server.responses = []
    server.busy_armed = False
    server.busy_reply = None
    server.busy_started = threading.Event()
    server.busy_release = threading.Event()
    server.busy_timed_out = threading.Event()
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
        scratch_path = str(cli.parent) + os.pathsep + os.environ.get('PATH', '/usr/bin:/bin')
        env = dict(PATH=scratch_path, HOME=str(home), CODEX_HOME=str(config),
                   OPENAI_API_KEY='fixture-only', MULTIPROMP_NOTIFY_RELAY_TOKEN='fixture-only', TERM='xterm-256color',
                   HTTP_PROXY='http://127.0.0.1:9', HTTPS_PROXY='http://127.0.0.1:9',
                   ALL_PROXY='http://127.0.0.1:9', NO_PROXY='127.0.0.1,localhost',
                   OTEL_SDK_DISABLED='true', MP_SMOKE_HOOK_DIAGNOSTIC=str(home / 'hook-observations.jsonl'))
        socket = 'mp-codex-smoke-' + str(os.getpid())
        def tmux(*args):
            return subprocess.run(['tmux', '-L', socket, *args], env=env, check=True,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True).stdout.strip()
        previous_path = os.environ.get('PATH')
        previous_tmux = os.environ.get('TMUX')
        os.environ['PATH'] = scratch_path
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
                else:
                    arguments.append('initial synthetic prompt')
                tmux('new-session', '-d', '-s', name, '-c', str(work), 'exec ' + shlex.join(arguments))
            start('smoke-a')
            first = wait_for(lambda: observations()[:1], 'first native SessionStart missing after initial prompt')[0]
            sid = first.get('session_id')
            assert sid and first.get('transcript_path'), 'first hook lacks session identity'
            print(json.dumps({'hook_event': first.get('hook_event_name'), 'hook_ancestors': first['ancestors']}), flush=True)
            spec = importlib.util.spec_from_file_location('reader', repo / 'src/chat_history_reader.py')
            reader = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(reader)
            reader.HOME = home
            reader.CONNECTOR_SOURCES = {name: base64.b64encode((repo / 'src/chat_connectors' / (name + '.py')).read_bytes()).decode()
                                        for name in ('claude', 'codex')}
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
            transcript = Path(first['transcript_path'])
            def transcript_rows():
                if not transcript.exists():
                    return []
                rows = []
                with transcript.open('rb') as source:
                    while True:
                        offset = source.tell()
                        line = source.readline()
                        if not line or not line.endswith(b'\n'):
                            break
                        event = reader.load_line(line)
                        rows.extend(reader.conversation_rows(event, 'codex', offset))
                return rows
            def replies():
                with server.response_lock:
                    return set(server.responses)
            def initial_reply():
                issued = replies()
                return any(row.get('role') == 'assistant' and row.get('text') in issued
                           for row in transcript_rows())
            wait_for(initial_reply, 'initial fake-provider reply missing from exact native transcript')
            initial_replies = replies()
            request = dict(message_protocol=1, provider='codex', sid=sid, tmux='smoke-a',
                           message_id='native_smoke_fixture_0001', text='hosted synthetic prompt')
            def host(op):
                return reader.message_store_request(dict(request, op='message_' + op))
            host('submit')
            dispatched = host('dispatch')
            assert dispatched['message']['state'] == 'accepted', (
                'Codex 0.166.0 native queue acceptance unavailable: ' + str(dispatched.get('handoff')))
            host('submit')
            host('dispatch')
            def delivered():
                rows = transcript_rows()
                users = [index for index, row in enumerate(rows)
                         if row.get('role') == 'user' and row.get('text') == request['text']]
                if len(users) > 1:
                    raise AssertionError('native transcript contains duplicate semantic user submissions')
                later_replies = replies() - initial_replies
                return bool(users and any(row.get('role') == 'assistant' and row.get('text') in later_replies
                                          for row in rows[users[0] + 1:]))
            wait_for(delivered, 'host send or distinct later reply missing from exact native transcript')
            reader.message_poll('smoke-a', 'codex', sid)
            native_items = host('snapshot')['items']
            assert any(item.get('native_message', {}).get('text') == request['text'] for item in native_items)
            assert any(item.get('native_message', {}).get('text') in replies() - initial_replies for item in native_items)
            assert host('status')['message']['state'] == 'accepted'
            busy = dict(request, message_id='native_smoke_busy_0001', text='controlled synthetic busy prompt')
            queued = dict(request, message_id='native_smoke_busy_0002', text='controlled synthetic queued prompt')
            def busy_host(op, message):
                return reader.message_store_request(dict(message, op='message_' + op))
            with server.response_lock:
                server.busy_armed = True
            try:
                busy_host('submit', busy)
                first_ack = busy_host('dispatch', busy)
                assert first_ack['message']['state'] == 'accepted', 'busy turn was not accepted'
                assert server.busy_started.wait(35), 'busy provider response did not start'
                busy_host('submit', queued)
                started_at = time.monotonic()
                second_ack = busy_host('dispatch', queued)
                elapsed = time.monotonic() - started_at
                assert not server.busy_release.is_set() and not server.busy_timed_out.is_set(), 'busy response released before acceptance'
                assert elapsed < 15, 'busy acceptance exceeded sent deadline'
                assert second_ack['message']['state'] == 'accepted', 'busy native queue did not accept second turn'
                replay = busy_host('submit', queued)
                assert replay['message']['attempt'] == second_ack['message']['attempt']
                assert replay['message']['state'] == 'accepted'
                busy_host('dispatch', queued)
                assert not server.busy_timed_out.is_set(), 'busy provider hold expired before replay'
            finally:
                server.busy_release.set()
            def busy_delivered():
                rows = transcript_rows()
                first_user = [i for i, row in enumerate(rows) if row.get('role') == 'user' and row.get('text') == busy['text']]
                second_user = [i for i, row in enumerate(rows) if row.get('role') == 'user' and row.get('text') == queued['text']]
                if len(first_user) > 1 or len(second_user) > 1:
                    raise AssertionError('busy or queued turn submitted more than once')
                if not first_user or not second_user or first_user[0] >= second_user[0]:
                    return False
                held_reply = server.busy_reply
                between = rows[first_user[0] + 1:second_user[0]]
                after = rows[second_user[0] + 1:]
                later_replies = replies() - initial_replies - {held_reply}
                return (any(row.get('role') == 'assistant' and row.get('text') == held_reply for row in between)
                        and any(row.get('role') == 'assistant' and row.get('text') in later_replies for row in after))
            wait_for(busy_delivered, 'busy turns or distinct replies missing from exact native transcript')
            reader.message_poll('smoke-a', 'codex', sid)
            busy_items = host('snapshot')['items']
            assert all(any(item.get('native_message', {}).get('text') == message['text'] for item in busy_items)
                       for message in (busy, queued))
            assert busy_host('status', queued)['message']['state'] == 'accepted'
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
            server.busy_release.set()
            subprocess.run(['tmux', '-L', socket, 'kill-server'], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            server.shutdown()
            if previous_path is None:
                os.environ.pop('PATH', None)
            else:
                os.environ['PATH'] = previous_path
            if previous_tmux is None:
                os.environ.pop('TMUX', None)
            else:
                os.environ['TMUX'] = previous_tmux


if __name__ == '__main__':
    main()
