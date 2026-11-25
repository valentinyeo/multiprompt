from pathlib import Path
import signal
import sys

marker = sys.argv[1]
if marker not in ('AWAY534', 'RESTART534'):
    raise ValueError(marker)
signal.alarm(15)
for path in sorted(Path.home().glob('*-' + marker + '.fifo')):
    with path.open('w') as release:
        release.write('reply\n')
    print(path.name, flush=True)
