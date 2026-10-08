"""Headless check: python test/web2.py URL OUT --wait N --ev 'click:x,y@t;hold:KeyW,2@t;key:KeyE@t;shot@t;move:dx,dy@t'"""
import sys, time, argparse
from playwright.sync_api import sync_playwright
ap = argparse.ArgumentParser(); ap.add_argument('url'); ap.add_argument('out')
ap.add_argument('--wait', type=float, default=30); ap.add_argument('--ev', default='')
ap.add_argument('--w', type=int, default=1280); ap.add_argument('--h', type=int, default=720)
a = ap.parse_args()
ev = []
for e in filter(None, a.ev.split(';')):
    body, t = e.rsplit('@', 1); ev.append((float(t), body))
ev.append((a.wait, 'shot')); ev.sort(key=lambda e: e[0])
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', headless=True,
        args=['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'])
    pg = b.new_context(viewport={'width': a.w, 'height': a.h}).new_page()
    logs = []
    pg.on('console', lambda m: logs.append((time.time(), m.type, m.text)))
    pg.on('pageerror', lambda e: logs.append((time.time(), 'pageerror', str(e))))
    t0 = time.time(); pg.goto(a.url, wait_until='load', timeout=120000)
    try:
     for t, body in ev:
        dt = t - (time.time() - t0)
        if dt > 0: time.sleep(dt)
        kind, _, arg = body.partition(':')
        print('%5.1f %s' % (time.time()-t0, body), flush=True)
        if kind == 'click':
            x, y = map(float, arg.split(',')); pg.mouse.click(x, y)
        elif kind == 'key': pg.keyboard.press(arg)
        elif kind == 'down': pg.keyboard.down(arg)
        elif kind == 'up': pg.keyboard.up(arg)
        elif kind == 'hold':
            k, d = arg.split(','); pg.keyboard.down(k); time.sleep(float(d)); pg.keyboard.up(k)
        elif kind == 'move':
            dx, dy = map(float, arg.split(',')); pg.mouse.move(640 + dx, 360 + dy, steps=8)
        elif kind == 'shot':
            fn = '%s_%03d.png' % (a.out, int(t)); pg.screenshot(path=fn); print('SHOT', fn, flush=True)
    except Exception as ex:
        print('EXC', ex)
    try: b.close()
    except Exception: pass
for ts, typ, txt in logs:
    if typ in ('error', 'warning', 'pageerror') or 'ERROR' in txt or 'SCRIPT' in txt or txt.startswith('['):
        print('%6.1f CONSOLE %s %s' % (ts - t0, typ, txt[:300]))
print('console lines:', len(logs))
