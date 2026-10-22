import argparse
import os
from pathlib import Path
import shutil


def size(path):
    if path.is_symlink():
        return 0
    if path.is_file():
        return path.stat().st_size
    return sum(size(child) for child in path.iterdir()) if path.is_dir() else 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cap-mib', type=int, required=True)
    args = parser.parse_args()
    if args.cap_mib <= 0:
        parser.error('--cap-mib must be positive')
    local = Path('.zig-cache')
    global_cache = Path(os.environ['ZIG_GLOBAL_CACHE_DIR'])
    cap = args.cap_mib * 1024 * 1024
    total = size(local) + size(global_cache)
    print(f'Zig caches before: {total / 1024 / 1024:.1f} MiB; cap: {args.cap_mib} MiB', flush=True)
    objects = local / 'o'
    entries = sorted(objects.iterdir(), key=lambda entry: entry.stat().st_mtime) if objects.is_dir() else []
    for entry in entries:
        if total <= cap:
            break
        removed = size(entry)
        print(f'Removing {entry}: {removed / 1024 / 1024:.1f} MiB', flush=True)
        if entry.is_dir() and not entry.is_symlink():
            shutil.rmtree(entry)
        else:
            entry.unlink()
        total -= removed
    total = size(local) + size(global_cache)
    print(f'Zig caches after: {total / 1024 / 1024:.1f} MiB', flush=True)
    if total > cap:
        raise SystemExit('Non-object Zig caches exceed cap; refusing an oversized save')


if __name__ == '__main__':
    main()
