import os
import pathlib
import subprocess
import sys
import time

state = pathlib.Path(os.environ['MP_LIFETIME_STATE'])
if sys.argv[1:] == ['ssh', 'exit']:
    sys.exit(37)
if sys.argv[1:] == ['grandchild']:
    (state / 'grandchild.tmp').write_text(str(os.getpid()))
    (state / 'grandchild.tmp').replace(state / 'grandchild')
else:
    if sys.argv[1:] != ['ssh', 'tree']:
        sys.exit(2)
    subprocess.Popen([sys.executable, __file__, 'grandchild'])
    (state / 'child.tmp').write_text(str(os.getpid()))
    (state / 'child.tmp').replace(state / 'child')
while True:
    time.sleep(1)
