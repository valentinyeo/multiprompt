import time

CHATS = (
    dict(tmux='ws-chat-one', sid='11111111-5555-4555-8555-000000000001',
         question='Which chat am I in, one?', reply='You are in chat one.'),
    dict(tmux='ws-chat-two', sid='11111111-5555-4555-8555-000000000002',
         question='Which chat am I in, two?', reply='You are in chat two.'),
)


def install(namespace, root, record):
    seeded = []
    for chat in CHATS:
        paths = namespace['host_paths']('claude', chat['sid'])
        if not paths['config'].is_file():
            session = {'turn': 'workspace-switch-seed', 'state': {'display_history': True}}
            namespace['host_history_append']('claude', chat['sid'], session,
                                             dict(role='user', id='ws-user-' + chat['tmux'], text=chat['question'],
                                                  timestamp=time.strftime('%Y-%m-%dT%H:%M:%S')))
            namespace['host_history_append']('claude', chat['sid'], session,
                                             dict(role='assistant', id='ws-reply-' + chat['tmux'], text=chat['reply'],
                                                  timestamp=time.strftime('%Y-%m-%dT%H:%M:%S')))
            if session.get('db') is not None:
                session['db'].close()
            cwd = str(root)
            namespace['host_write'](paths['config'], dict(enabled=True, provider='claude', sid=chat['sid'],
                                                          tmux=chat['tmux'], cwd=cwd))
            namespace['host_state_write']('claude', chat['sid'], dict(provider='claude', sid=chat['sid'],
                                                                      tmux=chat['tmux'], cwd=cwd, display_history=True))
        seeded.append(dict(tmux=chat['tmux'], sid=chat['sid'], question=chat['question'], reply=chat['reply']))
    record('workspace-switch.jsonl', stage='seeded', chats=seeded)

    def provider_start(provider, sid, source=None):
        record('workspace-switch.jsonl', stage='provider-start', provider=provider, sid=sid,
               boundary='provider CLI start replaced; production switch kept')
        return dict(status='started', pid=0)

    namespace['host_start'] = provider_start

    original_resume = namespace['host_resume']
    original_adopt = namespace['host_adopt']

    def resume(provider, sid, tmux=None, cwd=None, mode=None):
        if provider == 'claude' and sid in {chat['sid'] for chat in CHATS}:
            record('workspace-switch.jsonl', stage='resume', provider=provider, sid=sid, tmux=tmux,
                   boundary='seeded chat is already attached')
            return dict(status='already', reason='host_running')
        return original_resume(provider, sid, tmux, cwd, mode)

    def adopt(provider, sid, tmux, cwd=None, mode=None):
        if provider == 'claude' and sid in {chat['sid'] for chat in CHATS}:
            record('workspace-switch.jsonl', stage='adopt', provider=provider, sid=sid, tmux=tmux,
                   boundary='seeded chat is already attached')
            return dict(status='already', reason='host_running')
        return original_adopt(provider, sid, tmux, cwd, mode)

    namespace['host_resume'] = resume
    namespace['host_adopt'] = adopt

    original_reply = namespace['host_reply']

    def reply(query):
        answer = original_reply(query)
        if query.get('op') == 'switch_ai':
            record('workspace-switch.jsonl', stage='switch-reply', provider=query.get('provider'),
                   sid=query.get('sid'), to=query.get('to'), status=answer.get('status'),
                   reason=answer.get('reason'), switched_sid=answer.get('sid'))
        return answer

    namespace['host_reply'] = reply
    record('workspace-switch.jsonl', stage='ready',
           boundary='two saved Claude chats with history; only the provider CLI start is replaced')
