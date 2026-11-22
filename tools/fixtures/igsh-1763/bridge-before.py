import json,os,signal,subprocess,sys,threading
hax=sys.argv[1:]
resume=None
if '--hax-resume' in hax:
    i=hax.index('--hax-resume');resume=hax[i+1];del hax[i:i+2]
child=None
out=threading.Lock()
def emit(o):
    with out:
        sys.stdout.write(json.dumps(o,separators=(',',':'))+'\n');sys.stdout.flush()
def run(token,text):
    global child,resume
    outcome,code='error',None
    try:
        p=subprocess.Popen(hax+['--json']+(['--resume='+resume] if resume else []),stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,start_new_session=True)
    except OSError:
        emit(dict(type='bridge_end',id=token,outcome='spawn_failed',session=resume));return
    child=p
    emit(dict(type='bridge_start',id=token))
    try:
        p.stdin.write(text.encode('utf-8'));p.stdin.close()
    except OSError:
        pass
    for line in p.stdout:
        try:
            record=json.loads(line)
        except ValueError:
            continue
        if not isinstance(record,dict):
            continue
        if record.get('type')=='session' and isinstance(record.get('id'),str):
            resume=record['id']
        if record.get('type')=='result':
            outcome=record.get('outcome') or 'complete'
            resume=record.get('session_id') or resume
        emit(dict(type='hax',id=token,record=record))
    code=p.wait();child=None
    emit(dict(type='bridge_end',id=token,outcome=outcome,exit=code,session=resume))
worker=None
for line in sys.stdin:
    try:
        message=json.loads(line)
    except ValueError:
        continue
    if not isinstance(message,dict):
        continue
    if message.get('type')=='prompt' and isinstance(message.get('id'),str) and isinstance(message.get('message'),str):
        if worker is not None and worker.is_alive():
            emit(dict(type='bridge_busy',id=message['id']));continue
        worker=threading.Thread(target=run,args=(message['id'],message['message']),daemon=True);worker.start()
    elif message.get('type')=='abort' and child is not None:
        try:
            os.killpg(child.pid,signal.SIGINT)
        except OSError:
            pass
if worker is not None:
    worker.join()
