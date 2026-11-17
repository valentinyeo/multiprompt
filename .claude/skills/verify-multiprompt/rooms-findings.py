from datetime import datetime
import json
from pathlib import Path
import sys

ACTIONS = ('create-room', 'add-agents', 'send-message', 'replies-in-order', 'switch-rooms', 'leave-or-close', 'to-one-and-everyone', 'leave-and-undo', 'delete-confirmation')


def read(root, name, default=None):
    file = root / name
    return json.loads(file.read_text(encoding='utf-8-sig')) if file.exists() else default


def findings(root):
    result = read(root, 'result.json', {})
    start = read(root, 'recording-start.json', {})
    steps = read(root, 'rooms-steps.json', [])
    lines = ['# Rooms regression', '', 'Video offsets use recorder-launch UTC. Review the video to refine startup latency before citing a visual defect.', '', '| Video | Action | Result | Evidence |', '| --- | --- | --- | --- |']
    for action in ACTIONS:
        matches = [step for step in steps if step['name'] == action]
        if len(matches) > 1:
            raise ValueError('Duplicate Rooms step ' + action)
        step = matches[0] if matches else None
        offset = 'not reached'
        if step and start.get('startedAt'):
            elapsed = max(0, int((datetime.fromisoformat(step['startedAt'].replace('Z', '+00:00')) - datetime.fromisoformat(start['startedAt'].replace('Z', '+00:00'))).total_seconds()))
            offset = f'{elapsed // 60:02d}:{elapsed % 60:02d}'
        status = step['status'] if step else 'not run'
        detail = step.get('detail') or 'Inspect the action screenshot and video; persisted checks alone do not prove visible behavior.' if step else 'Journey ended before this action. Not a reproduced product defect.'
        detail = detail.replace('|', '\\|').replace('\n', ' ')
        lines.append(f'| {offset} | {action} | {status} | {detail} |')
    if result.get('error'):
        lines.extend(['', 'Journey error: ' + result['error']])
    lines.extend(['', 'Design gap: leaving the view is distinct from leaving membership. The current service has no leave-membership or delete-room operation.', '', 'Read build.json for the executable revision. These exercised steps do not certify the remaining design A actions.'])
    (root / 'rooms-findings.md').write_text('\n'.join(lines) + '\n')
    if result.get('status') == 'passed' and [step['name'] for step in steps] != list(ACTIONS):
        raise ValueError('Completed audit must contain all six Rooms actions in order')


if __name__ == '__main__':
    findings(Path(sys.argv[1]))
