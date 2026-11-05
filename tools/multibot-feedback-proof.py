#!/usr/bin/env python3
import base64
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
WISH = 'Attach screenshots to agent feedback'
WHY = 'Agents cannot show app problems with wishes.'
stage = 'setup'
failed_command = None


def diagnose(error):
    data = dict(stage=stage, exception_type=type(error).__name__, command=failed_command,
                executable_found=shutil.which('hypertask') is not None, exit_code=None,
                stdout_bytes=None, stderr_bytes=None, json_valid=None, keys=[])
    try:
        result = subprocess.run(['hypertask', '--json', 'status'], capture_output=True, timeout=30)
        data.update(exit_code=result.returncode, stdout_bytes=len(result.stdout), stderr_bytes=len(result.stderr))
        try:
            status = json.loads(result.stdout)
            data['json_valid'] = True
            if isinstance(status, dict):
                allowed = ('authenticated', 'hasToken', 'identity', 'agentId', 'apiUrl', 'configPath', 'success', 'expiresAt')
                data['keys'] = [key for key in allowed if key in status]
                for key in ('authenticated', 'hasToken'):
                    data[key] = status.get(key) if isinstance(status.get(key), bool) else None
                data['identity_is_agent'] = status.get('identity') == 'agent'
                agent_id = status.get('agentId')
                data['agent_id_type'] = ('string' if isinstance(agent_id, str) else
                                         'integer' if type(agent_id) is int else 'other')
        except (ValueError, UnicodeError) as status_error:
            data['json_valid'] = False
            data['status_exception_type'] = type(status_error).__name__
    except (OSError, subprocess.SubprocessError) as status_error:
        data['status_exception_type'] = type(status_error).__name__
        if isinstance(status_error, subprocess.TimeoutExpired):
            data.update(stdout_bytes=len(status_error.stdout or b''), stderr_bytes=len(status_error.stderr or b''))
    destination = ROOT / 'evidence/feedback-diagnostic.json'
    destination.parent.mkdir(exist_ok=True)
    destination.write_text(json.dumps(data, indent=2) + '\n')


def safe_diagnose(error):
    try:
        diagnose(error)
    except Exception:
        pass


def main():
    global stage
    if not os.environ.get('HT_TOKEN', '').strip():
        raise RuntimeError('agent token unavailable')
    match = re.search(r'pub const APP_VERSION = build_config\.app_version orelse "([0-9]+\.[0-9]+\.[0-9]+)"', (ROOT / 'src/main.zig').read_text())
    if not match:
        raise RuntimeError('app version unavailable')
    version = match.group(1)
    with tempfile.TemporaryDirectory() as temporary:
        home = Path(temporary)
        os.environ.update(HOME=str(home), XDG_STATE_HOME=str(home / 'state'), MULTIBOT_PROVIDER='codex', MULTIBOT_APP_VERSION=version)
        os.environ.pop('MULTIBOT_FEEDBACK_LOG', None)
        source = (ROOT / 'src/chat_history_reader.py').read_text()
        feedback = (ROOT / 'src/multibot_feedback.py').read_bytes()
        prefix = 'MULTIBOT_APP_VERSION = ' + repr(version) + '\nFEEDBACK_SOURCE = ' + repr(base64.b64encode(feedback).decode()) + '\n'
        bootstrap = "import base64,sys;s=base64.b64decode(sys.stdin.buffer.readline());exec(compile(s,'<bundle>','exec'))"
        payload = base64.b64encode((prefix + source).encode()) + b'\n' + b'{"id":1,"op":"engine_info"}\n'
        installed = subprocess.run([sys.executable, '-c', bootstrap, '--serve'], input=payload, capture_output=True, timeout=60)
        tool = home / '.multiprompt-runtime/multibot-feedback'
        if installed.returncode or not tool.exists() or tool.read_bytes() != feedback:
            raise RuntimeError('reader bundle installation failed')
        spec = importlib.util.spec_from_file_location('feedback', tool)
        if spec is None:
            from importlib.machinery import SourceFileLoader
            spec = importlib.util.spec_from_loader('feedback', SourceFileLoader('feedback', str(tool)))
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        original_cli = module.cli

        def observed_cli(*args):
            global failed_command
            try:
                return original_cli(*args)
            except module.BoardError as error:
                verbs = ('status', 'labels', 'task', 'comment')
                subcommands = ('list', 'create', 'add')
                failed_command = [args[0] if args and args[0] in verbs else 'other',
                                  args[1] if len(args) > 1 and args[1] in subcommands else None]
                safe_diagnose(error)
                raise

        module.cli = observed_cli
        stage = 'identity'
        agent = module.identity()
        stage = 'labels'
        module.board_labels()
        title = module.normalized(module.PREFIX + module.normalized(WISH))

        def matching():
            return [(status, task) for status in ('Normal', 'Archive', 'Deleted') for task in module.tasks(status) if module.normalized(task['title']) == title]

        stage = 'search'
        before = matching()
        if len(before) > 1 or any(status == 'Deleted' for status, _ in before):
            raise RuntimeError('existing wish conflict')
        before_votes = len(module.votes(before[0][1])) if before else 0
        already_voted = bool(before and agent in module.votes(before[0][1]))
        outputs = []
        stage = 'submission'
        for _ in range(2):
            result = subprocess.run([sys.executable, str(tool), WISH, '--why', WHY], capture_output=True, text=True, timeout=180)
            output = result.stdout.strip()
            if result.returncode or not re.fullmatch(r'Feedback (submitted|voted): https://app\.hypertask\.ai/detail/project-2060/\d+', output):
                error = RuntimeError('submission not confirmed')
                safe_diagnose(error)
                raise error
            outputs.append(output)
        stage = 'search'
        after = matching()
        if len(after) != 1 or after[0][0] == 'Deleted':
            raise RuntimeError('wish duplicate or missing')
        task = after[0][1]
        votes = module.votes(task)
        if agent not in votes or len(votes) != before_votes + (0 if already_voted else 1):
            raise RuntimeError('vote count did not converge')
        url = module.ticket_url(task)
        if not all(output.endswith(url) for output in outputs):
            raise RuntimeError('ticket links differ')
        stage = 'ranking'
        ranking = subprocess.run([sys.executable, str(tool), '--weekly'], capture_output=True, text=True, timeout=180)
        if ranking.returncode:
            error = RuntimeError('weekly ranking unavailable')
            safe_diagnose(error)
            raise error
        lines = [line for line in ranking.stdout.splitlines() if line.endswith('\t' + url)]
        rows = (home / 'state/multibot/feedback.jsonl').read_text().splitlines()
        if len(rows) != 2:
            raise RuntimeError('local rows missing')
        evidence = dict(revision=os.environ.get('GITHUB_SHA', ''), source_version=version, ticket_url=url,
                        command_outputs=outputs, vote_count_before=before_votes, vote_count_after=len(votes),
                        saved_row_count=len(rows), weekly_ranking=lines,
                        second_agent='hosted stand-in tests only')
        destination = ROOT / 'evidence/feedback-proof.json'
        destination.parent.mkdir(exist_ok=True)
        destination.write_text(json.dumps(evidence, indent=2) + '\n')
        print('FEEDBACK_PROOF_OK')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        if not (ROOT / 'evidence/feedback-diagnostic.json').exists():
            safe_diagnose(error)
        print('FEEDBACK_PROOF_FAILED', file=sys.stderr)
        sys.exit(1)
