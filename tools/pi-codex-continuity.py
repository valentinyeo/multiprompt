import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import time
import uuid


def wait_for(name, check, seconds=240):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        value = check()
        if value:
            return value
        time.sleep(0.2)
    raise RuntimeError(name)


def credentials(home, proof):
    raw = os.environ.pop('CODEX_AUTH_JSON', '')
    if not raw:
        raise RuntimeError('existing_codex_plan_secret_missing')
    saved = json.loads(raw)
    tokens = saved.get('tokens') or {}
    access = tokens.get('access_token')
    if not isinstance(access, str) or len(access.split('.')) != 3:
        raise RuntimeError('existing_codex_plan_oauth_required')
    payload = access.split('.')[1]
    claims = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
    expires = claims.get('exp')
    account = tokens.get('account_id') or (claims.get('https://api.openai.com/auth') or {}).get('chatgpt_account_id')
    proof['credential_preflight'] = dict(account_id_present=isinstance(account, str) and bool(account),
                                        expiry_present=type(expires) in (int, float),
                                        access_token_current=type(expires) in (int, float) and expires > time.time())
    if not proof['credential_preflight']['account_id_present']:
        raise RuntimeError('existing_codex_plan_account_identity_missing')
    if not proof['credential_preflight']['expiry_present']:
        raise RuntimeError('existing_codex_plan_access_expiry_missing')
    if not proof['credential_preflight']['access_token_current']:
        raise RuntimeError('existing_codex_plan_access_token_expired')
    codex = home / '.codex'
    pi = home / '.pi/agent'
    for directory in (codex, pi):
        directory.mkdir(parents=True, mode=0o700)
    auth = codex / 'auth.json'
    auth.write_text(json.dumps(dict(saved, auth_mode='chatgpt', OPENAI_API_KEY=None,
                                    tokens=dict(tokens, account_id=account, refresh_token=''))))
    auth.chmod(0o600)
    (codex / 'config.toml').write_text('model = "gpt-6.1-sol"\nmodel_reasoning_effort = "low"\n')
    auth = pi / 'auth.json'
    auth.write_text(json.dumps({'openai-codex': dict(type='oauth', access=access, refresh='',
                                                   expires=expires * 1000, accountId=account)}))
    auth.chmod(0o600)
    os.environ.update(CODEX_HOME=str(codex), PI_CODING_AGENT_DIR=str(pi))


def records(home):
    paths = list((home / '.codex/sessions').rglob('*.jsonl'))
    paths += list((home / '.pi/agent/sessions').rglob('*.jsonl'))
    paths += list((home / '.local/state/multiprompt/agent-host').glob('*.history.jsonl'))
    return {path: path.read_bytes() for path in paths}


def skill_read(home, sid):
    for path in (home / '.pi/agent/sessions').rglob('*.jsonl'):
        rows = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
        if not any(row.get('type') == 'session' and row.get('id') == sid for row in rows):
            continue
        for row in rows:
            message = row.get('message') or {}
            content = message.get('content')
            for part in content if isinstance(content, list) else []:
                if part.get('type') != 'toolCall' or part.get('name') != 'read':
                    continue
                args = part.get('arguments') or {}
                name = args.get('path') or args.get('file_path') or ''
                if isinstance(name, str) and name.endswith('/valentin-mode/SKILL.md'):
                    return True
    return False


def pi_model_seen(home, sid):
    for path in (home / '.pi/agent/sessions').rglob('*.jsonl'):
        rows = [json.loads(line) for line in path.read_text().splitlines() if line.strip()]
        if not any(row.get('type') == 'session' and row.get('id') == sid for row in rows):
            continue
        for row in rows:
            message = row.get('message') or {}
            if (message.get('role') == 'assistant' and message.get('provider') == 'openai-codex'
                    and message.get('model') == 'gpt-6.1-sol' and message.get('stopReason') != 'error'):
                return True
    return False


def run(args, proof):
    root = Path(__file__).resolve().parents[1]
    skill = args.skills.resolve()
    if not (skill / 'SKILL.md').is_file():
        raise RuntimeError('real_valentin_mode_skill_missing')
    with tempfile.TemporaryDirectory(prefix='pi-codex-proof-', dir=os.environ['RUNNER_TEMP']) as directory:
        home = Path(directory)
        credentials(home, proof)
        os.environ['HOME'] = str(home)
        (home / '.pi/agent/skills').mkdir()
        (home / '.pi/agent/skills/valentin-mode').symlink_to(skill, target_is_directory=True)
        (home / '.agents/skills').mkdir(parents=True)
        (home / '.agents/skills/valentin-mode').symlink_to(skill, target_is_directory=True)
        work = home / 'work'
        work.mkdir()
        catalog = subprocess.run(['pi', '--offline', '--list-models', 'gpt-6.1-sol'],
                                 capture_output=True, text=True, check=True, timeout=30).stdout
        if not any('openai-codex' in line and 'gpt-6.1-sol' in line for line in catalog.splitlines()):
            raise RuntimeError('requested_pi_codex_model_missing')
        proof['catalog'] = [line for line in catalog.splitlines() if 'openai-codex' in line]
        sources = {name: base64.b64encode((root / f'src/chat_connectors/{name}.py').read_bytes()).decode()
                   for name in ('claude', 'codex')}
        reader = runpy.run_path(str(root / 'src/chat_history_reader.py'), init_globals=dict(CONNECTOR_SOURCES=sources))
        tmux = 'live-proof-' + uuid.uuid4().hex[:12]
        sid = str(uuid.uuid4())
        provider = 'pi'
        owned = [(provider, sid)]
        preserved = {}
        prior_rows = []
        marker = 'continuity-' + uuid.uuid4().hex
        subprocess.run(['tmux', 'new-session', '-d', '-s', tmux, '-c', str(work)], check=True, timeout=10)

        def snapshot():
            current = records(home)
            for path, before in preserved.items():
                if path not in current or not current[path].startswith(before):
                    raise RuntimeError('an_original_transcript_record_changed')
            preserved.update(current)
            rows = reader['host_switch_rows'](provider, sid, tmux)
            cursor = 0
            for old in prior_rows:
                found = next((i for i in range(cursor, len(rows))
                              if rows[i].get('role') == old.get('role') and rows[i].get('text') == old.get('text')), None)
                if found is None:
                    raise RuntimeError('original_history_missing_or_reordered')
                cursor = found + 1
            prior_rows[:] = [row for row in rows if row.get('role') in ('user', 'assistant') and row.get('text')]
            proof['preserved_transcript_files'] = len(preserved)
            proof['history_rows'] = len(prior_rows)

        def events_after(sequence):
            events = []
            while True:
                page = reader['message_events_page'](provider, sid, sequence)
                if not page['events']:
                    return events
                events.extend(page['events'])
                sequence = page['next_after']

        def turn(text, expected):
            wait_for('provider_did_not_settle', lambda: not reader['host_turn_busy'](provider, sid)
                     and not reader['host_fresh_pending'](provider, sid), 360)
            before = events_after(0)
            sequence = max((row['seq'] for row in before), default=0)
            reply = reader['host_send'](provider, sid, text, tmux)
            if reply.get('status') not in ('sent', 'queued', 'ok', 'accepted'):
                raise RuntimeError('real_send_refused')
            ident = reply['id']

            def completed():
                events = events_after(sequence)
                started = next((row['seq'] for row in events if row['event'].get('kind') == 'turn.started'
                                and row['event'].get('payload', {}).get('message_id') == ident), None)
                if started is None:
                    return None
                ended = [row['event'] for row in events if row['seq'] > started and row['event'].get('kind') == 'turn.ended']
                if not ended:
                    return None
                if ended[-1].get('payload', {}).get('status') != 'completed':
                    raise RuntimeError('real_model_turn_failed')
                text = '\n'.join(row['event'].get('payload', {}).get('text', '') for row in events
                                 if row['seq'] > started and row['event'].get('kind') == 'text.done')
                if text.strip() != expected:
                    raise RuntimeError('real_model_did_not_return_only_the_marker')
                return text.strip()

            answer = wait_for('real_model_reply_missing', completed)
            proof['turns'].append(dict(provider=provider, sid=sid, model='gpt-6.1-sol', prompt=text, reply=answer))
            snapshot()

        try:
            result = reader['host_cli'](['enable', provider, sid, '--tmux', tmux, '--cwd', str(work)])
            if result.get('status') != 'enabled':
                raise RuntimeError('real_host_enable_failed')
            paths = reader['host_paths'](provider, sid)
            config = reader['host_read'](paths['config'])
            identity = dict(face='proof-face', login='proof-agent', tmux=tmux, cwd=str(work))
            config.update(identity, model_provider='openai-codex', model='gpt-6.1-sol', auto_switch=dict(on=False))
            reader['host_write'](paths['config'], config)
            if reader['host_start'](provider, sid).get('status') not in ('started', 'already'):
                raise RuntimeError('real_pi_host_start_failed')
            turn('Remember this continuity marker, ' + marker + '. Reply with only the marker. Do not use tools.', marker)
            turn('/valentin-mode For this disposable proof, read the real valentin-mode SKILL.md, but do not execute its '
                 'startup actions. Do not write boards, files, keys or accounts. Reply with only the remembered continuity marker.', marker)
            if not skill_read(home, sid) or not pi_model_seen(home, sid):
                raise RuntimeError('real_skill_read_or_pi_codex_identity_unproven')
            proof['valentin_mode_read'] = True
            for target in ('codex', 'pi'):
                snapshot()
                reply = reader['host_reply'](dict(op='switch_ai', provider=provider, sid=sid, to=target))
                if reply.get('status') != 'switched':
                    raise RuntimeError('real_switch_failed')
                provider, sid = reply['provider'], reply['sid']
                owned.append((provider, sid))
                current = reader['host_config'](provider, sid) or {}
                if any(current.get(key) != value for key, value in identity.items()):
                    raise RuntimeError('real_switch_changed_chat_identity')
                if reader['host_auto_switch_settings'](current)['on']:
                    raise RuntimeError('automatic_provider_substitution_enabled')
                if provider == 'pi':
                    selected = reader['host_reply'](dict(op='set_model', provider=provider, sid=sid,
                                                        provider_name='openai-codex', model='gpt-6.1-sol'))
                    if selected.get('status') != 'ok':
                        raise RuntimeError('real_pi_model_selection_failed')
                    wait_for('real_pi_model_acknowledgement_missing', lambda: any(
                        event.get('event') == 'pi_set_model_reply' and (event.get('detail') or {}).get('success') is True
                        for event in reader['host_log_tail'](provider, sid)))
                turn('Reply with only the original continuity marker. Do not use tools.', marker)
                if provider == 'pi':
                    if not pi_model_seen(home, sid):
                        raise RuntimeError('real_pi_codex_model_reply_unproven')
                    turn('/valentin-mode Read the real valentin-mode SKILL.md without executing startup actions. '
                         'Do not write boards, files, keys or accounts. Reply with only the original continuity marker.', marker)
                    if not skill_read(home, sid):
                        raise RuntimeError('switched_back_real_skill_read_unproven')
                else:
                    native = reader['host_session_state'](provider, sid).get('native_session')
                    path = reader['conversation_path'](provider, native, str(work))
                    if path is None or not any(row.get('type') == 'turn_context' and
                            row.get('payload', {}).get('model') == 'gpt-6.1-sol'
                            for row in (json.loads(line) for line in path.read_text().splitlines() if line.strip())):
                        raise RuntimeError('real_codex_model_identity_unproven')
                proof['switches'].append(dict(provider=provider, sid=sid, same_chat=True, original_records_preserved=True))
            turn('Reply with only the original continuity marker once more. Do not use tools.', marker)
            proof['status'] = 'passed'
        finally:
            for agent, native in reversed(owned):
                reader['host_stop'](agent, native)
            subprocess.run(['tmux', 'kill-session', '-t', '=' + tmux], capture_output=True, timeout=10)
            proof['owned_hosts_stopped'] = all(not reader['host_alive'](agent, native) for agent, native in owned)
            if not proof['owned_hosts_stopped']:
                raise RuntimeError('owned_host_cleanup_failed')
            proof['transcript_hashes'] = {str(path.relative_to(home)): hashlib.sha256(data).hexdigest()
                                          for path, data in preserved.items()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--skills', required=True, type=Path)
    parser.add_argument('--evidence', required=True, type=Path)
    args = parser.parse_args()
    if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_OS') != 'Linux':
        raise SystemExit('Use a public GitHub-hosted Linux runner')
    args.evidence.mkdir(parents=True, exist_ok=True)
    proof = dict(status='failed', revision=os.environ.get('GITHUB_SHA'), turns=[], switches=[],
                 boundary='Real production reader/host, tmux, Pi and Codex plan replies; no Windows UI or AgY claim.')
    try:
        run(args, proof)
    except Exception as error:
        proof['status'] = 'failed'
        proof['error_type'] = type(error).__name__
        proof['error'] = str(error) if isinstance(error, RuntimeError) else 'runner_setup_or_provider_failure'
    finally:
        (args.evidence / 'summary.json').write_text(json.dumps(proof, indent=2) + '\n')
    print(json.dumps({key: proof.get(key) for key in ('status', 'revision', 'error', 'owned_hosts_stopped')}))
    return 0 if proof['status'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
