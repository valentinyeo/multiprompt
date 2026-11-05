#!/usr/bin/env python3
import base64
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
WISH = 'Attach screenshots to agent feedback'
WHY = 'Agents cannot show app problems with wishes.'


def main():
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
        agent = module.identity()
        module.board_labels()
        title = module.normalized(module.PREFIX + module.normalized(WISH))

        def matching():
            return [(status, task) for status in ('Normal', 'Archive', 'Deleted') for task in module.tasks(status) if module.normalized(task['title']) == title]

        before = matching()
        if len(before) > 1 or any(status == 'Deleted' for status, _ in before):
            raise RuntimeError('existing wish conflict')
        before_votes = len(module.votes(before[0][1])) if before else 0
        already_voted = bool(before and agent in module.votes(before[0][1]))
        outputs = []
        for _ in range(2):
            result = subprocess.run([sys.executable, str(tool), WISH, '--why', WHY], capture_output=True, text=True, timeout=180)
            output = result.stdout.strip()
            if result.returncode or not re.fullmatch(r'Feedback (submitted|voted): https://app\.hypertask\.ai/detail/project-2060/\d+', output):
                raise RuntimeError('submission not confirmed')
            outputs.append(output)
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
        ranking = subprocess.run([sys.executable, str(tool), '--weekly'], capture_output=True, text=True, timeout=180)
        if ranking.returncode:
            raise RuntimeError('weekly ranking unavailable')
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
        print('FEEDBACK_PROOF_FAILED: ' + str(error), file=sys.stderr)
        sys.exit(1)
