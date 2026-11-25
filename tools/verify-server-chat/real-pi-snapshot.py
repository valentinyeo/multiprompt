import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3

FORBIDDEN_SECRET_ENV = {
    'CODEX_AUTH_JSON',
    'OPENAI_API_KEY',
    'CODEX_API_KEY',
    'ANTHROPIC_API_KEY',
    'CLAUDE_CODE_OAUTH_TOKEN',
    'GH_TOKEN',
    'GITHUB_TOKEN',
    'HYPERTASK_AGENT_TOKEN',
    'DEEPSEEK_API_KEY',
    'OPENCODE_API_KEY',
    'OPENROUTER_API_KEY',
    'AI_GATEWAY_API_KEY',
}


def read_json(path):
    try:
        return json.loads(Path(path).read_text(encoding='utf-8'))
    except Exception:
        return None


def read_jsonl(path):
    rows = []
    try:
        for line in Path(path).read_text(encoding='utf-8', errors='replace').splitlines():
            if not line.strip():
                continue
            try:
                rows.append(json.loads(line))
            except ValueError:
                continue
    except OSError:
        return []
    return rows


def extract_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict) and item.get('type') in ('text', 'input_text', 'output_text') and isinstance(item.get('text'), str):
                parts.append(item['text'])
        return '\n'.join(parts)
    return ''


def inspect_pi_sessions(home):
    root = home / '.pi/agent/sessions'
    sessions = []
    if not root.is_dir():
        return sessions
    for path in sorted(root.rglob('*.jsonl')):
        entries = read_jsonl(path)
        header = entries[0] if entries and isinstance(entries[0], dict) else {}
        model_changes = []
        messages = []
        skill_loads = []
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            kind = entry.get('type')
            if kind == 'model_change':
                model_changes.append({
                    'provider': entry.get('provider'),
                    'modelId': entry.get('modelId'),
                    'timestamp': entry.get('timestamp'),
                })
            elif kind == 'message':
                msg = entry.get('message') if isinstance(entry.get('message'), dict) else {}
                role = msg.get('role')
                text = extract_text(msg.get('content')).strip()
                if role == 'user' and '<skill name="valentin-mode"' in text:
                    match = re.search(r'<skill name="valentin-mode" location="([^"]+)">\nReferences are relative to [^\n]+\n\n([\s\S]*?)\n</skill>', text)
                    if match:
                        skill_loads.append({
                            'location': match.group(1),
                            'body_sha256': hashlib.sha256(match.group(2).strip().encode('utf-8')).hexdigest(),
                        })
                if role in ('user', 'assistant') and text:
                    record = {
                        'id': entry.get('id'),
                        'role': role,
                        'text': text,
                        'text_sha256': hashlib.sha256(text.encode('utf-8')).hexdigest(),
                        'timestamp': entry.get('timestamp'),
                    }
                    if role == 'assistant':
                        record['provider'] = msg.get('provider')
                        record['model'] = msg.get('model')
                        record['stopReason'] = msg.get('stopReason')
                        record['errorMessage'] = msg.get('errorMessage')
                    messages.append(record)
        sessions.append({
            'file': str(path.relative_to(root)),
            'session_id': header.get('id'),
            'cwd': header.get('cwd'),
            'model_changes': model_changes,
            'skill_loads': skill_loads,
            'messages': messages,
            'raw_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        })
    return sessions


def inspect_codex_sessions(home):
    root = home / '.codex/sessions'
    sessions = []
    if not root.is_dir():
        return sessions
    for path in sorted(root.rglob('*.jsonl')):
        entries = read_jsonl(path)
        session_id = None
        messages = []
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            kind = entry.get('type')
            payload = entry.get('payload') if isinstance(entry.get('payload'), dict) else {}
            if kind == 'session_meta':
                session_id = payload.get('id')
            elif kind == 'response_item' and payload.get('type') == 'message':
                role = payload.get('role')
                text = extract_text(payload.get('content')).strip()
                if role in ('user', 'assistant') and text:
                    messages.append({
                        'role': role,
                        'text': text,
                        'text_sha256': hashlib.sha256(text.encode('utf-8')).hexdigest(),
                        'timestamp': entry.get('timestamp'),
                    })
        sessions.append({
            'file': str(path.relative_to(root)),
            'session_id': session_id,
            'messages': messages,
            'raw_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        })
    return sessions


def inspect_hosts(home):
    root = home / '.local/state/multiprompt/agent-host'
    hosts = []
    if not root.is_dir():
        return hosts
    for config_path in sorted(root.glob('*.config.json')):
        key = config_path.name[:-len('.config.json')]
        config = read_json(config_path) or {}
        state = read_json(root / f'{key}.state.json') or {}
        history_path = root / f'{key}.history.jsonl'
        history_rows = []
        if history_path.is_file():
            for entry in read_jsonl(history_path):
                row = entry.get('row') if isinstance(entry, dict) else None
                if isinstance(row, dict) and row.get('role') in ('user', 'assistant') and isinstance(row.get('text'), str) and row['text'].strip():
                    history_rows.append({
                        'id': row.get('id'),
                        'role': row.get('role'),
                        'text': row['text'],
                        'text_sha256': hashlib.sha256(row['text'].encode('utf-8')).hexdigest(),
                    })
        log_events = []
        log_path = root / f'{key}.log'
        if log_path.is_file():
            for entry in read_jsonl(log_path):
                if isinstance(entry, dict) and entry.get('event') in (
                    'start', 'init', 'auto_switch_setting', 'auto_switch', 'auto_switch_skipped',
                    'pi_set_model', 'pi_set_model_reply', 'switched_ai', 'turn_done', 'host_error',
                    'fresh_start_failed', 'pi_prompt',
                ):
                    log_events.append(entry)
        child_env_leaks = []
        agent_pid = state.get('agent_pid')
        if isinstance(agent_pid, int) and agent_pid > 0:
            env_path = Path(f'/proc/{agent_pid}/environ')
            if env_path.is_file():
                try:
                    raw_env = env_path.read_bytes().split(b'\0')
                    names = [item.split(b'=', 1)[0].decode('ascii', 'ignore') for item in raw_env if b'=' in item]
                    child_env_leaks = sorted(name for name in names if name in FORBIDDEN_SECRET_ENV)
                except OSError:
                    pass
        hosts.append({
            'key': key,
            'provider': config.get('provider'),
            'sid': config.get('sid'),
            'enabled': config.get('enabled'),
            'tmux': config.get('tmux'),
            'cwd': config.get('cwd'),
            'model_provider': config.get('model_provider'),
            'model': config.get('model'),
            'has_custom_command': 'command' in config,
            'auto_switch': config.get('auto_switch'),
            'switched_from': config.get('switched_from'),
            'switched_to': config.get('switched_to'),
            'native_session': state.get('native_session'),
            'display_history': bool(state.get('display_history')),
            'fresh_start': state.get('fresh_start'),
            'agent_pid': agent_pid,
            'child_env_leaks': child_env_leaks,
            'history_rows': history_rows,
            'log_events': log_events,
        })
    return hosts


def main():
    home = Path.home()
    tables = {}
    db_path = home / '.local/state/multiprompt/shared-messages/store.sqlite3'
    if db_path.is_file():
        with sqlite3.connect(f'file:{db_path}?mode=ro', uri=True) as db:
            db.row_factory = sqlite3.Row
            tables = {name: [dict(row) for row in db.execute('SELECT * FROM ' + name)] for name in ('message_chats', 'message_resets', 'shared_messages')}
    switched = read_json(home / '.local/state/multiprompt/agent-host/switched.json') or {}
    print(json.dumps({
        'tables': tables,
        'switched': switched,
        'hosts': inspect_hosts(home),
        'pi_sessions': inspect_pi_sessions(home),
        'codex_sessions': inspect_codex_sessions(home),
    }))


if __name__ == '__main__':
    main()
