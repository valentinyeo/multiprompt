import base64
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
CHAT = json.loads((ROOT / 'tools/fixtures/SOFT-2443/chat.json').read_text())


def token(agent_id):
    payload = base64.urlsafe_b64encode(json.dumps(dict(agentId=agent_id)).encode()).decode().rstrip('=')
    return 'fixture.' + payload + '.unsigned'


def sessions_module():
    source = Path(os.environ.get('MP_AGENT_SESSIONS_SOURCE', ROOT / 'src/mp_sessions.py'))
    spec = importlib.util.spec_from_file_location('agent_sessions', source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class AgentTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.sessions = sessions_module()
        self.send = self.sessions.load_send()
        self.root = self.home / '.local/state/multiprompt/agent-host'
        self.root.mkdir(parents=True)
        self.path = self.root / (self.send.host_config_key(CHAT['provider'], CHAT['sid']) + '.config.json')
        self.credentials = self.home / '.config/hypertask-agents/credentials/sessions'
        self.credentials.mkdir(parents=True)
        self.token_file = self.credentials / (CHAT['tmux'] + '-agent-token')
        self.token_file.write_text(token(CHAT['agent_id']))
        self.token_file.chmod(0o600)
        self.config = dict(enabled=True, provider=CHAT['provider'], sid=CHAT['sid'], tmux=CHAT['tmux'],
                           spawn_display=CHAT['name'], hypertask_agent_id=CHAT['agent_id'],
                           hypertask_token_file=str(self.token_file), hypertask_agent_name=CHAT['name'])
        self.send.write_json(self.path, self.config)
        self.requests = []
        self.agents = {CHAT['agent_id']: dict(id=CHAT['agent_id'], display_name=CHAT['name'], archived=False)}
        self.reject = 0
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_PATCH(self):
                self.respond()

            def do_POST(self):
                self.respond()

            def respond(self):
                body = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))) or '{}')
                owner.requests.append((self.command, self.path, self.headers.get('Authorization'), body))
                if owner.reject:
                    self.send_response(owner.reject)
                    self.end_headers()
                    self.wfile.write(b'{"success":false,"error":"Agents cannot manage agents"}')
                    return
                if self.path == '/api/mcp/admin/agents':
                    agent_id = 'created-' + str(len(owner.agents))
                    agent = dict(id=agent_id, display_name=body['display_name'], archived=False)
                    owner.agents[agent_id] = agent
                    reply = dict(success=True, agent=agent, token=token(agent_id))
                else:
                    agent_id = self.path.split('/')[4]
                    agent = owner.agents[agent_id]
                    if self.path.endswith('/archive'):
                        agent['archived'] = True
                    else:
                        agent['display_name'] = body['display_name']
                    reply = dict(success=True, agent=agent)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps(reply).encode())

        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.thread.join)
        self.addCleanup(self.server.shutdown)
        self.environment = patch.dict(os.environ, dict(HOME=str(self.home), HYPERTASKS_API_URL='http://127.0.0.1:' + str(self.server.server_port) + '/api',
                                                       HYPERTASK_MANAGEMENT_KEY='', HT_TOKEN='parent-token-must-not-be-used',
                                                       HYPERTASKS_JWT_TOKEN='parent-token-must-not-be-used'))
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.addCleanup(patch.stopall)
        patch.object(self.send, 'host_root', return_value=self.root).start()
        patch.object(self.send, 'published_names', return_value={CHAT['tmux']: CHAT['name']}).start()
        self.listing = dict(ok=True, workspaces=[dict(name='Work', tabs=[dict(id=7, tmux=CHAT['tmux'], title=CHAT['name'])], groups=[])])
        patch.object(self.send, 'zsb', side_effect=lambda *args: self.listing if args[0] == 'workspace-list' else dict(ok=True)).start()
        patch.object(self.sessions, 'load_send', return_value=self.send).start()

    def sync(self, name=None, archive=False):
        return self.sessions.sync_agent(self.send, self.path, name=name, archive=archive)

    def test_rename_reaches_hypertask_with_chat_token(self):
        args = self.sessions.parse(['rename', CHAT['name'], CHAT['renamed']])
        self.assertEqual(self.sessions.cmd_rename(args), 0)
        self.assertEqual(self.agents[CHAT['agent_id']]['display_name'], CHAT['renamed'])
        self.assertEqual(self.requests[-1], ('PATCH', '/api/mcp/agents/agent-one', 'Bearer ' + token('agent-one'), dict(display_name=CHAT['renamed'])))
        self.assertEqual(self.send.read_json(self.path)['hypertask_agent_id'], CHAT['agent_id'])

    def test_denied_self_rename_never_uses_owner_credentials_and_retries(self):
        self.reject = 403
        with self.assertRaisesRegex(ValueError, '403'):
            self.sync(CHAT['renamed'])
        self.assertEqual(self.send.read_json(self.path)['hypertask_agent_name'], CHAT['name'])
        self.reject = 0
        self.sync(CHAT['renamed'])
        self.assertEqual(self.agents[CHAT['agent_id']]['display_name'], CHAT['renamed'])
        self.assertTrue(all(row[2] == 'Bearer ' + token('agent-one') for row in self.requests))

    def test_repeated_sync_does_not_rename_or_create_twice(self):
        self.sync(CHAT['renamed'])
        self.sync(CHAT['renamed'])
        self.assertEqual(len(self.requests), 1)

    def test_new_chats_get_distinct_agents_even_with_the_same_name(self):
        with patch.dict(os.environ, HYPERTASK_MANAGEMENT_KEY='htmk_fixture'):
            ids = []
            for index in range(2):
                path = self.root / ('new-' + str(index) + '.config.json')
                self.send.write_json(path, dict(enabled=True, tmux='new-' + str(index), spawn_display='Same name'))
                self.sessions.sync_agent(self.send, path)
                config = self.send.read_json(path)
                ids.append(config['hypertask_agent_id'])
                self.assertEqual(Path(config['hypertask_token_file']).stat().st_mode & 0o777, 0o600)
                self.sessions.sync_agent(self.send, path)
            self.assertNotEqual(ids[0], ids[1])
        self.assertEqual(len([row for row in self.requests if row[1] == '/api/mcp/admin/agents']), 2)

    def test_existing_token_is_linked_by_session_not_display_name(self):
        self.send.write_json(self.path, dict(enabled=True, tmux=CHAT['tmux'], spawn_display='Completely different'))
        self.sync('New display')
        self.assertEqual(self.send.read_json(self.path)['hypertask_agent_id'], 'agent-one')
        self.assertEqual(self.agents['agent-one']['display_name'], 'New display')

    def test_duplicate_agent_binding_is_refused_before_network(self):
        self.send.write_json(self.root / 'other.config.json', dict(self.config, tmux='other-chat'))
        with self.assertRaisesRegex(ValueError, 'another chat'):
            self.sync('New display')
        self.assertEqual(self.requests, [])

    def test_close_archives_once_but_stop_is_not_a_close(self):
        self.sync(archive=True)
        self.sync(archive=True)
        self.assertTrue(self.agents['agent-one']['archived'])
        self.assertEqual([row[1] for row in self.requests], ['/api/mcp/agents/agent-one/archive'])

    def test_mismatched_token_cannot_rename_another_agent(self):
        self.token_file.write_text(token('other-agent'))
        with self.assertRaisesRegex(ValueError, 'token'):
            self.sync('New display')
        self.assertEqual(self.requests, [])

    def test_missing_management_key_never_uses_parent_or_saved_login(self):
        self.token_file.unlink()
        self.send.write_json(self.path, dict(enabled=True, tmux=CHAT['tmux'], spawn_display=CHAT['name']))
        with self.assertRaisesRegex(ValueError, 'management key'):
            self.sync()
        self.assertEqual(self.requests, [])


if __name__ == '__main__':
    unittest.main()
