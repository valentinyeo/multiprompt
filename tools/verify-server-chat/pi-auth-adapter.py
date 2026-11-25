import argparse
import base64
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import sys
import tempfile

JWT_CLAIM_PATH = 'https://api.openai.com/auth'


def decode_jwt_payload(token):
    if not isinstance(token, str):
        raise ValueError('access_token must be a string')
    parts = token.split('.')
    if len(parts) != 3 or any(not part for part in parts):
        raise ValueError('access_token is not a 3-part JWT')
    padded = parts[1] + '=' * (-len(parts[1]) % 4)
    try:
        raw = base64.urlsafe_b64decode(padded.encode('ascii'))
        payload = json.loads(raw.decode('utf-8'))
    except Exception as error:
        raise ValueError('access_token JWT payload could not be decoded') from error
    if not isinstance(payload, dict):
        raise ValueError('access_token JWT payload must be an object')
    return payload


def convert_codex_auth_to_pi(raw_text, now_ms=None):
    if not isinstance(raw_text, str) or not raw_text.strip():
        raise ValueError('CODEX_AUTH_JSON is empty')
    try:
        source = json.loads(raw_text)
    except ValueError as error:
        raise ValueError('CODEX_AUTH_JSON is not valid JSON') from error
    if not isinstance(source, dict):
        raise ValueError('CODEX_AUTH_JSON must be a JSON object')
    auth_mode = source.get('auth_mode')
    if auth_mode is not None and auth_mode != 'chatgpt':
        raise ValueError('CODEX_AUTH_JSON auth_mode is incompatible with Pi openai-codex OAuth')
    tokens = source.get('tokens')
    if not isinstance(tokens, dict):
        if source.get('OPENAI_API_KEY'):
            raise ValueError('CODEX_AUTH_JSON contains only an API key and no ChatGPT OAuth tokens')
        raise ValueError('CODEX_AUTH_JSON is missing OAuth tokens object')
    access = tokens.get('access_token')
    refresh = tokens.get('refresh_token')
    if not isinstance(access, str) or not access.strip():
        raise ValueError('CODEX_AUTH_JSON tokens.access_token is missing')
    if not isinstance(refresh, str) or not refresh.strip():
        raise ValueError('CODEX_AUTH_JSON tokens.refresh_token is missing')
    payload = decode_jwt_payload(access)
    auth_claim = payload.get(JWT_CLAIM_PATH)
    if not isinstance(auth_claim, dict):
        raise ValueError('access_token JWT is missing OpenAI auth claim')
    jwt_account_id = auth_claim.get('chatgpt_account_id')
    if not isinstance(jwt_account_id, str) or not jwt_account_id.strip():
        raise ValueError('access_token JWT is missing chatgpt_account_id')
    declared_account_id = tokens.get('account_id')
    if declared_account_id is not None:
        if not isinstance(declared_account_id, str) or not declared_account_id.strip():
            raise ValueError('CODEX_AUTH_JSON tokens.account_id is invalid')
        if declared_account_id != jwt_account_id:
            raise ValueError('CODEX_AUTH_JSON tokens.account_id does not match JWT chatgpt_account_id')
    exp = payload.get('exp')
    if type(exp) not in (int, float) or not math.isfinite(exp) or exp <= 0:
        raise ValueError('access_token JWT is missing a valid exp claim')
    expires_ms = int(exp * 1000)
    current_ms = int(datetime.now(timezone.utc).timestamp() * 1000) if now_ms is None else int(now_ms)
    pi_auth = {
        'openai-codex': {
            'type': 'oauth',
            'access': access,
            'refresh': refresh,
            'expires': expires_ms,
            'accountId': jwt_account_id,
        }
    }
    summary = {
        'ok': True,
        'provider': 'openai-codex',
        'type': 'oauth',
        'auth_mode': auth_mode or 'chatgpt',
        'has_access': True,
        'has_refresh': True,
        'has_account_id': True,
        'account_id_declared': declared_account_id is not None,
        'account_id_matches_jwt': True,
        'expires_ms': expires_ms,
        'expires_utc': datetime.fromtimestamp(expires_ms / 1000, timezone.utc).isoformat(),
        'access_expired_initially': current_ms >= expires_ms,
    }
    return pi_auth, source, summary


def write_restricted_json(path, payload):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    os.chmod(target.parent, 0o700)
    fd, tmp_name = tempfile.mkstemp(prefix='.auth-', suffix='.tmp', dir=str(target.parent))
    try:
        os.chmod(tmp_name, 0o600)
        with os.fdopen(fd, 'w', encoding='utf-8') as handle:
            json.dump(payload, handle, indent=2)
            handle.write('\n')
        os.replace(tmp_name, target)
        os.chmod(target, 0o600)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--pi-auth-out', required=True)
    parser.add_argument('--codex-auth-out')
    parser.add_argument('--source-file')
    args = parser.parse_args()
    if args.source_file:
        raw_text = Path(args.source_file).read_text(encoding='utf-8')
    else:
        raw_text = sys.stdin.read()
    pi_auth, codex_auth, summary = convert_codex_auth_to_pi(raw_text)
    write_restricted_json(args.pi_auth_out, pi_auth)
    summary['pi_auth_mode'] = oct(os.stat(args.pi_auth_out).st_mode & 0o777)
    if args.codex_auth_out:
        write_restricted_json(args.codex_auth_out, codex_auth)
        summary['codex_auth_written'] = True
        summary['codex_auth_mode'] = oct(os.stat(args.codex_auth_out).st_mode & 0o777)
    else:
        summary['codex_auth_written'] = False
    print(json.dumps(summary))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'ok': False, 'error': str(error)}), file=sys.stderr)
        sys.exit(1)
