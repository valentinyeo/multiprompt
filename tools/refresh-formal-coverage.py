import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def refresh(root, path, sync_commit):
    record = json.loads(path.read_text())
    record['files'] = {file: hashlib.sha256((root / file).read_bytes()).hexdigest()
                       for file in record['files']}
    record['sync_commit'] = sync_commit
    path.write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Refresh formal coverage after reviewing the source/model mapping.')
    parser.add_argument('--sync-commit', required=True)
    parser.add_argument('records', type=Path, nargs='+')
    args = parser.parse_args()
    commit = subprocess.check_output(['git', 'rev-parse', '--verify', args.sync_commit + '^{commit}'], cwd=ROOT, text=True).strip()
    for path in args.records:
        refresh(ROOT, path, commit)
        print(path)
