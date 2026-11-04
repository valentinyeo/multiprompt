import json
from pathlib import Path


def install(namespace, root, record):
    root = Path(root)
    config = json.loads((root / 'state.json').read_text(encoding='utf-8-sig'))
    sid = config['sids']['live-slash']
    previous_owned = namespace['host_owned']
    previous_request = namespace['host_request']
    previous_control = namespace['host_control_request']
    state_file = root / 'slash-mode.json'

    def owned(provider, requested_sid):
        return provider == 'claude' and requested_sid == sid or previous_owned(provider, requested_sid)

    def control(session, request):
        if not session.get('slash_boundary'):
            return previous_control(session, request)
        record('slash-control.jsonl', sid=sid, request=request)
        return True

    def request(provider, requested_sid, query, *args, **kwargs):
        if provider != 'claude' or requested_sid != sid:
            return previous_request(provider, requested_sid, query, *args, **kwargs)
        saved = json.loads(state_file.read_text()) if state_file.exists() else {'mode': 'manual'}
        session = dict(state=saved, slash_boundary=True)
        reply = namespace['host_handle_request'](provider, sid, 'live-slash', session, query)
        if query.get('op') == 'set_permission_mode' and reply.get('status') == 'ok':
            state_file.write_text(json.dumps(session['state']), encoding='utf-8')
        record('slash-replies.jsonl', sid=sid, op=query.get('op'), reply=reply)
        return reply

    namespace['host_owned'] = owned
    namespace['host_request'] = request
    namespace['host_control_request'] = control
