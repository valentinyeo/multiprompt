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
    removed_entries = 0
    removed_bytes = 0
    for entry in entries:
        if total <= cap:
            break
        removed = size(entry)
        if entry.is_dir() and not entry.is_symlink():
            shutil.rmtree(entry)
        else:
            entry.unlink()
        total -= removed
        removed_entries += 1
        removed_bytes += removed
    print(f'Removed {removed_entries} entries: {removed_bytes / 1024 / 1024:.1f} MiB', flush=True)
    total = size(local) + size(global_cache)
    print(f'Zig caches after: {total / 1024 / 1024:.1f} MiB', flush=True)
    if total > cap:
        print(f'::warning::Zig caches still {total / 1024 / 1024:.1f} MiB after trimming, above the {args.cap_mib} MiB cap', flush=True)


if __name__ == '__main__':
    main()
