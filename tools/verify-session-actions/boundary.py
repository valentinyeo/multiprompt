import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import re
import importlib.util
import sys

if os.environ.get('GITHUB_ACTIONS') != 'true' or os.name != 'nt':
    raise RuntimeError('Hosted Windows only')
root = Path(os.environ['MP_VERIFY_STATE'])
command = ' '.join(sys.argv[2:])
if sys.argv[1] == 'ssh' and 'tmux kill-session' in command:
    match = re.search(r"tmux kill-session -t '([A-Za-z0-9_-]+)' 2>/dev/null; (?:python3 [A-Za-z0-9_~./-]+ host stop (claude|codex|pi) '([0-9a-f-]{36})' >/dev/null 2>&1; )?true", command)
    if match is None:
        raise RuntimeError('Unexpected session-end command')
    state = json.loads((root / 'state.json').read_text(encoding='utf-8-sig'))
    target = match[1]
    with (root / 'end-requests.jsonl').open('a', encoding='utf-8') as requests:
        requests.write(json.dumps(dict(session=target, provider=match[2], sid=match[3])) + '\n')
    if target not in state['end_events'] or (match[3] or '') != state['session_ids'][target] or match[2] != state.get('providers', {}).get(target, 'claude'):
        raise RuntimeError('Session-end target or agent identity mismatch')
    kernel = ctypes.WinDLL('kernel32', use_last_error=True)
    kernel.OpenEventW.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.LPCWSTR)
    kernel.OpenEventW.restype = wintypes.HANDLE
    kernel.SetEvent.argtypes = (wintypes.HANDLE,)
    kernel.CloseHandle.argtypes = (wintypes.HANDLE,)
    handle = kernel.OpenEventW(2, False, state['end_events'][target])
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        if not kernel.SetEvent(handle):
            raise ctypes.WinError(ctypes.get_last_error())
    finally:
        kernel.CloseHandle(handle)
    state['sessions'] = [name for name in state['sessions'] if name != target]
    temporary = root / ('state-' + target + '.tmp')
    temporary.write_text(json.dumps(state), encoding='utf-8')
    os.replace(temporary, root / 'state.json')
    (root / ('ended-' + target + '.json')).write_text(json.dumps(dict(session=target, provider=match[2], sid=match[3], host_stop=bool(match[3]))), encoding='utf-8')
    sys.exit(0)
spec = importlib.util.spec_from_file_location('chat_delivery_boundary', Path(__file__).resolve().parents[1] / 'verify-chat-delivery' / 'boundary.py')
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
base.session_names = lambda: list(base.state()['sessions'])
if base.MODE == 'ssh' and 'host start ' in command:
    if 'host enable ' in command:
        raise RuntimeError('Resume must not re-enable or reset existing provider config')
    started = re.search(r'host start (codex|pi) ([0-9a-f-]{36}) --tmux ([A-Za-z0-9_-]+)', command)
    if started is None:
        raise RuntimeError('Unexpected provider resume command')
    provider, sid, target = started.groups()
    state = base.state()
    original = next((name for name, identity in state['session_ids'].items() if identity == sid and name.startswith('verify-provider-')), None)
    if original is None or state['providers'][original] != provider or re.fullmatch(re.escape(original) + r'-r\d+', target) is None:
        raise RuntimeError('Archived resume changed the original assistant or identity')
    state['sessions'].append(target)
    state['sids'][target] = sid
    state['session_ids'][target] = sid
    state['panes'][target] = state['panes'][original]
    state['providers'][target] = provider
    state['end_events'][target] = state['end_events'][original]
    temporary = root / 'provider-resume-state.tmp'
    temporary.write_text(json.dumps(state), encoding='utf-8')
    os.replace(temporary, root / 'state.json')
    base.record('provider-resumed.jsonl', provider=provider, sid=sid, session=target, command=command, boundary='synthetic host transport; no provider binary or paid service')
    base.attach_fake(target)
    sys.exit(0)
if base.MODE == 'ssh' and 'tmux new-session -d -s ' in command and 'claude --resume ' in command:
    target_match = re.search(r'tmux new-session -d -s ([^ ]+)', command)
    sid_match = re.search(r'claude --resume .*?([0-9a-f]{8}-[0-9a-f-]{27})', command)
    if target_match is None or sid_match is None:
        raise RuntimeError('Unexpected archived resume command')
    target = target_match[1].strip("'\"\\")
    state = base.state()
    original = next((name for name, sid in state['session_ids'].items() if sid == sid_match[1]), None)
    if original is None or re.fullmatch(re.escape(original) + r'-r\d+', target) is None or not (root / ('ended-' + original + '.json')).exists():
        raise RuntimeError('Archived resume identity does not match an ended fixture')
    state['sessions'].append(target)
    state['sids'][target] = sid_match[1]
    state['panes'][target] = state['panes'][original]
    temporary = root / 'resume-state.tmp'
    temporary.write_text(json.dumps(state), encoding='utf-8')
    os.replace(temporary, root / 'state.json')
    base.record('resumed.jsonl', session=target, original=original, sid=sid_match[1], boundary='synthetic resume transport; original transcript unchanged')
    base.attach_fake(target)
    sys.exit(0)
sys.exit(base.tmux(base.ARGS, sys.stdin.buffer, sys.stdout) if base.MODE == 'tmux' else base.shell() if base.MODE == 'shell' else base.ssh())
