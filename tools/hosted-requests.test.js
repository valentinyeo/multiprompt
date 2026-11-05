const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

test('IGSH-1644 hosted Windows boundary uses production parked requests, provider responses and continuation events', () => {
  const program = String.raw`
import importlib.util, json, os, tempfile
from pathlib import Path
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    os.environ['HOME'] = directory
    os.environ['USERPROFILE'] = directory
    namespace = {'__name__': 'verified_reader'}
    exec(compile(Path('src/chat_history_reader.py').read_text(), 'reader', 'exec'), namespace)
    namespace['HOME'] = root
    namespace['serve_request'] = lambda *args: None
    sid = '11111111-2222-4333-8444-555555555555'
    (root / 'state.json').write_text(json.dumps({'sids': {'live-slash': sid}}))
    spec = importlib.util.spec_from_file_location('slash_host', 'tools/verify-chat-delivery/slash_host.py')
    boundary = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(boundary)
    records = []
    boundary.install(namespace, root, lambda name, **row: records.append((name, row)))
    namespace['serve_request'](json.dumps(dict(op='events_subscribe', provider='claude', sid=sid)), '', {}, None)
    cases = [
        ('allow', 'Bash', {'command': 'printf proof'}, {'op': 'approval_reply', 'decision': 'accept'}, 'allow'),
        ('cancel', 'Bash', {'command': 'printf unused'}, {'op': 'approval_reply', 'decision': 'cancel'}, 'deny'),
        ('question', 'AskUserQuestion', {'questions': [{'question': 'Which colour?', 'options': [{'label': 'Orange'}]}]}, {'op': 'question_reply', 'answers': {'0': 'Orange'}}, 'allow'),
        ('plan', 'ExitPlanMode', {'plan': '## Plan'}, {'op': 'plan_reply', 'action': 'implement'}, 'allow'),
        ('feedback', 'ExitPlanMode', {'plan': '## Plan'}, {'op': 'plan_reply', 'action': 'feedback', 'feedback': 'Cover empty folders'}, 'deny'),
    ]
    for request_id, tool, inputs, query, behavior in cases:
        fixture = dict(type='control_request', request_id=request_id, request=dict(subtype='can_use_tool', tool_name=tool, tool_use_id='tool-' + request_id, input=inputs))
        (root / 'hosted-request.json').write_text(json.dumps(fixture))
        page = namespace['message_events_page']('claude', sid, 0)
        kinds = [entry['event']['kind'] for entry in page['events']]
        expected = 'question.request' if tool == 'AskUserQuestion' else 'plan.proposed' if tool == 'ExitPlanMode' else 'approval.request'
        assert kinds[-1] == expected, kinds
        before = len(page['events'])
        assert len(namespace['message_events_page']('claude', sid, 0)['events']) == before
        request = dict(provider='claude', sid=sid, request_id=request_id, **query)
        assert namespace['host_reply'](request)['status'] == 'ok'
        continuation = [row for name, row in records if name == 'hosted-continuations.jsonl'][-1]
        assert continuation['request_id'] == request_id
        response = [row for name, row in records if name == 'hosted-replies.jsonl'][-1]['responses'][0]['response']
        assert response['request_id'] == request_id
        assert response['response']['behavior'] == behavior
        if tool == 'AskUserQuestion':
            assert response['response']['updatedInput']['answers'] == {'Which colour?': 'Orange'}
        after = namespace['message_events_page']('claude', sid, 0)['events']
        assert any(entry['event']['kind'] == 'text.done' and continuation['text'] == entry['event']['payload']['text'] for entry in after)
        assert namespace['host_reply'](request)['reason'] == 'unknown_request'
        assert len([row for name, row in records if name == 'hosted-continuations.jsonl']) == cases.index((request_id, tool, inputs, query, behavior)) + 1
    assert len([row for name, row in records if name == 'hosted-events.jsonl']) == 5
`;
  const result = spawnSync('python3', ['-'], { input: program, encoding: 'utf8', timeout: 30000 });
  assert.equal(result.status, 0, result.stderr || result.stdout);
});
