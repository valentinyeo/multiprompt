import hashlib
import importlib.util
import json
from pathlib import Path
import sys

root, evidence = map(Path, sys.argv[1:])
generator = Path(__file__).resolve().parents[2] / '.claude/skills/verify-multiprompt/seed-profile.py'
spec = importlib.util.spec_from_file_location('real_size_profile', generator)
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)
manifest = fixture.seed(root, root / 'profile')
state = json.loads((root / 'remote-state/state.json').read_text(encoding='utf-8-sig'))
targets = []
for index, name in enumerate(state['sessions']):
    sid = state['sids'][name]
    transcript = root / 'profile/.claude/projects' / f'C--verify-work{index}' / f'{sid}.jsonl'
    rows = list(fixture.source_rows(index, sid))
    transcript.write_text(''.join(json.dumps(row, separators=(',', ':')) + '\n' for row in rows), encoding='utf-8')
    targets.append(dict(index=index, sid=sid, messages=len(rows), sha256=hashlib.sha256(transcript.read_bytes()).hexdigest()))
manifest['positionTargets'] = targets
manifest['generatorRevision'] = '60b28893a6b3468c2cf63804c590d5e2978c878d'
(evidence / 'fixture-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
print(json.dumps(dict(sessions=manifest['sessions'], targets=targets)))
