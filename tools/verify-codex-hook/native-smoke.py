"""Hosted-only native Codex hook smoke; all provider traffic is net-namespaced."""
import base64
import http.server
import importlib.util
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import threading
import time
import uuid


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
        scoped_keys = set(env) | {'TMUX', 'XDG_STATE_HOME', 'CODEX_STATE_HOME', 'CODEX_PROFILE', 'CODEX_CONFIG_PROFILE'}
        previous_env = {key: os.environ.get(key) for key in scoped_keys}
        for key in scoped_keys:
            os.environ.pop(key, None)
        os.environ.update(env)
        backend_process = None
        daemon_socket = None
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
            def start(name, resume=None, endpoint=None):
                arguments = [str(cli), '--yolo', '--dangerously-bypass-hook-trust', '--enable', 'hooks']
                if endpoint:
                    arguments.extend(['--remote', endpoint])
                if resume:
                    arguments.extend(['resume', resume])
                else:
                    arguments.append('initial synthetic prompt')
                tmux('new-session', '-d', '-s', name, '-c', str(work), 'exec ' + shlex.join(arguments))
            for mode in ('direct', 'daemon'):
                server.busy_release.clear()
                server.busy_started.clear()
                server.busy_timed_out.clear()
                endpoint = None
                if mode == 'daemon':
                    daemon_dir = Path('/tmp/codex-daemon-' + str(os.getuid()))
                    daemon_dir.mkdir(mode=0o700, exist_ok=True)
                    daemon_socket = daemon_dir / (uuid.uuid4().hex + uuid.uuid4().hex)
                    endpoint = 'unix://' + str(daemon_socket)
                    backend_process = subprocess.Popen([str(cli), '--dangerously-bypass-hook-trust', '--enable', 'hooks', 'app-server', '--listen', endpoint], cwd=work, env=env,
                                                       stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    wait_for(lambda: daemon_socket.is_socket() and backend_process.poll() is None, 'fixture daemon failed to listen')
                    backend_proc = Path('/proc') / str(backend_process.pid)
                    backend_start = (backend_proc / 'stat').read_text().rsplit(')', 1)[1].split()[19]
                    assert backend_proc.stat().st_uid == os.getuid() and os.path.samefile(backend_proc / 'exe', cli), 'fixture daemon identity mismatch'
                count = len(observations())
                start('smoke-a', endpoint=endpoint)
                first = wait_for(lambda: observations()[count:count + 1], 'first native SessionStart missing after initial prompt')[0]
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
                assert native, 'native TUI missing'
                native_start = reader.codex_process_start(native)
                assert native_start, 'native TUI start time unavailable'
                transcript = Path(first['transcript_path']).resolve()
                if mode == 'daemon':
                    wait_for(lambda: reader.open_codex_transcript(native, table) == set(), 'remote TUI owns rollout FDs')
                else:
                    wait_for(lambda: reader.open_codex_transcript(native, {native: table[native]}, config) == {(sid, transcript)},
                             'direct TUI does not own exact transcript')
                attachment = wait_for(lambda: reader.codex_queue_attachment('smoke-a', sid, transcript), 'verified attachment missing')
                assert attachment['attachment'] == mode
                if mode == 'direct':
                    assert Path(attachment['codex_binary']).resolve() == cli
                    assert Path(attachment['codex_home']).resolve() == config.resolve()
                    assert Path(attachment['native_user_home']).resolve() == home.resolve()
                else:
                    actual = attachment.get('daemon_endpoint')
                    backend_fds = reader.codex_socket_fds(backend_process.pid)
                    tui_fds = reader.codex_socket_fds(native)
                    connections = reader.codex_unix_connections()
                    path = actual[7:] if isinstance(actual, str) and actual.startswith('unix:///') else ''
                    canonical = re.fullmatch(r'/tmp/codex-daemon-' + str(os.getuid()) + r'/[0-9a-f]{64}', path)
                    links = {fd for fd in (backend_fds or set()) if connections and
                             connections.get(fd, (None, None))[1] == path and
                             connections[fd][0] in (tui_fds or set()) and
                             connections.get(connections[fd][0], (None, None))[0] == fd}
                    table_now = reader.process_table(pids=[backend_process.pid])
                    backend_sources = reader.open_codex_transcript(backend_process.pid, table_now)
                    try:
                        valid = (backend_process.poll() is None and backend_start and
                                 reader.codex_process_start(backend_process.pid) == backend_start and
                                 backend_proc.stat().st_uid == os.getuid() and
                                 os.path.samefile(backend_proc / 'exe', cli) and
                                 reader.codex_process_start(native) == native_start and
                                 canonical and Path(path).is_socket() and len(links) == 1 and
                                 backend_sources == {(sid, transcript)})
                    except OSError:
                        valid = False
                    if not valid:
                        metadata = {fd: connections.get(fd) for fd in sorted((backend_fds or set()) | (tui_fds or set()))[:32]} if connections else None
                        raise AssertionError('daemon peer mismatch: ' + json.dumps(dict(
                            expected=endpoint, actual=actual, backend_pid=backend_process.pid,
                            tui_pid=native, backend_fds=sorted(backend_fds or [])[:32],
                            tui_fds=sorted(tui_fds or [])[:32], connections=metadata,
                            backend_sources=sorted((str(item[0]), str(item[1])) for item in (backend_sources or set())))))
                def first_response():
                    wire = response('smoke-a')
                    return wire if '\thistory\tok\t' + sid + '\t' in wire else None
                wire = wait_for(first_response, 'pane-to-backend response not established')
                assert '\thistory\tok\t' + sid + '\t' in wire
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
                               message_id='native_smoke_' + mode + '_0001', text='hosted synthetic prompt')
                def host(op):
                    return reader.message_store_request(dict(request, op='message_' + op))
                wrong = dict(request, sid=str(uuid.uuid4()), message_id='native_smoke_' + mode + '_wrong_sid',
                             text='wrong session synthetic prompt')
                reader.message_store_request(dict(wrong, op='message_submit'))
                rejected = reader.message_store_request(dict(wrong, op='message_dispatch'))
                assert rejected['message']['state'] != 'accepted', 'wrong session was accepted'
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
                busy = dict(request, message_id='native_smoke_' + mode + '_busy_0001', text='controlled synthetic busy prompt')
                queued = dict(request, message_id='native_smoke_' + mode + '_busy_0002', text='controlled synthetic queued prompt')
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
                assert int(tmux('display-message', '-p', '-t', 'smoke-a:0.0', '#{pane_pid}')) == pane
                assert reader.codex_process_start(native) == native_start, 'original TUI changed'
                assert reader.codex_queue_attachment('smoke-a', sid, transcript) == attachment, 'attachment identity changed'
                if mode == 'daemon':
                    assert backend_process.poll() is None and reader.codex_process_start(backend_process.pid) == backend_start, 'daemon worker changed'
                else:
                    assert reader.open_codex_transcript(native, {native: reader.process_table()[native]}, config) == {(sid, transcript)}, 'direct worker changed transcript'
                if mode == 'direct':
                    tmux('kill-session', '-t', 'smoke-a')
                    continue
            rows = transcript_rows()
            queued_index = next(i for i, row in enumerate(rows)
                                if row.get('role') == 'user' and row.get('text') == queued['text'])
            earlier_reply = next(row['text'] for row in rows[queued_index + 1:]
                                 if row.get('role') == 'assistant' and row.get('text') in replies() - initial_replies - {server.busy_reply})
            start('smoke-b', resume=sid, endpoint=endpoint)
            backend = backend_process.pid
            value = reader.process_table()[backend]
            assert backend_process.poll() is None and reader.codex_process_start(backend) == backend_start
            pane_b = int(tmux('display-message', '-p', '-t', 'smoke-b:0.0', '#{pane_pid}'))
            def second_ready():
                table_b = reader.process_table(pids=[pane_b])
                native_b = reader.agent_pid_for_panes([pane_b], table_b, 'codex')
                if not native_b or native_b == native:
                    return None
                started = reader.codex_process_start(native_b)
                backend_fds = reader.codex_socket_fds(backend)
                tui_fds = reader.codex_socket_fds(native_b)
                connections = reader.codex_unix_connections()
                if not started or backend_fds is None or tui_fds is None or connections is None:
                    return None
                links = {fd for fd in backend_fds if connections.get(fd, (None, None))[1] == path
                         and connections[fd][0] in tui_fds
                         and connections.get(connections[fd][0], (None, None))[0] == fd}
                display = tmux('capture-pane', '-p', '-t', 'smoke-b:0.0', '-S', '-100')
                if (len(links) == 1 and earlier_reply in display and
                        reader.open_codex_transcript(native_b, table_b) == set() and
                        reader.open_codex_transcript(backend, {backend: value}) == {(sid, transcript)} and
                        backend_process.poll() is None and reader.codex_process_start(backend) == backend_start and
                        reader.codex_process_start(native_b) == started and reader.codex_process_start(native) == native_start):
                    return native_b
                return None
            native_b = wait_for(second_ready, 'second remote TUI did not attach to the exact thread')
            sources = reader.open_codex_transcript(backend, {backend: value})
            assert sources is not None and len(sources) == 1, 'two-client one-writer precondition not observed'
            assert '\thistory\tmissing\t' in response('smoke-a')
            assert '\thistory\tmissing\t' in response('smoke-b')
            ambiguous = dict(request, message_id='native_smoke_daemon_ambiguous_0001',
                             text='ambiguous synthetic prompt must not be sent')
            before_ambiguous = replies()
            reader.message_store_request(dict(ambiguous, op='message_submit'))
            refused = reader.message_store_request(dict(ambiguous, op='message_dispatch'))
            assert refused['message']['state'] == 'failed', 'ambiguous dispatch was not refused'
            assert replies() == before_ambiguous, 'ambiguous dispatch reached provider'
            tmux('kill-session', '-t', 'smoke-b')
            wait_for(lambda: '\thistory\tok\t' + sid + '\t' in response('smoke-a'), 'single-client binding did not recover')
            threading.Event().wait(35)
            assert replies() == before_ambiguous, 'ambiguous dispatch reached provider after recovery'
            assert not any(row.get('role') == 'user' and row.get('text') == ambiguous['text']
                           for row in transcript_rows()), 'ambiguous dispatch reached native transcript'
            count = len(observations())
            tmux('send-keys', '-t', 'smoke-a:0.0', '/new', 'Enter')
            tmux('send-keys', '-t', 'smoke-a:0.0', 'new synthetic session prompt', 'Enter')
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
            new_sid = switched['session_id']
            wait_for(lambda: '\thistory\tok\t' + new_sid + '\t' in response('smoke-a'),
                     'initialized new session not bound to its exact SID')
            assert reader.codex_process_start(native) == native_start, 'TUI changed during selection'
            print('native fixture daemon: isolation and observed selection controls verified')
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
            if backend_process is not None:
                backend_process.terminate()
                try:
                    backend_process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    backend_process.kill()
                    backend_process.wait()
            if daemon_socket is not None:
                daemon_socket.unlink(missing_ok=True)
            server.shutdown()
            for key, value in previous_env.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value


if __name__ == '__main__':
    main()
