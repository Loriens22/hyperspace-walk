"""Headless browser smoke test for the web build.
usage: python3 test/webcheck.py URL OUTPREFIX [--mobile] [--wait 40] [--clicks x,y@t;x,y@t] [--keys KEY@t;...]
Saves screenshots OUTPREFIX_<t>.png and prints console errors/warnings."""
import sys, time, argparse
from playwright.sync_api import sync_playwright

ap = argparse.ArgumentParser()
ap.add_argument('url'); ap.add_argument('out')
ap.add_argument('--mobile', action='store_true'); ap.add_argument('--wait', type=float, default=40)
ap.add_argument('--clicks', default=''); ap.add_argument('--keys', default=''); ap.add_argument('--shots', default='')
a = ap.parse_args()
events = []
for c in filter(None, a.clicks.split(';')):
    xy, t = c.split('@'); x, y = map(float, xy.split(',')); events.append((float(t), 'click', (x, y)))
for k in filter(None, a.keys.split(';')):
    key, t = k.split('@'); events.append((float(t), 'key', key))
for s in filter(None, a.shots.split(',')): events.append((float(s), 'shot', None))
events.append((a.wait, 'shot', None)); events.sort(key=lambda e: e[0])
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', headless=True,
                          args=['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'])
    if a.mobile:
        ctx = b.new_context(viewport={'width': 844, 'height': 390}, device_scale_factor=2, is_mobile=True, has_touch=True,
                            user_agent='Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Mobile Safari/537.36')
    else:
        ctx = b.new_context(viewport={'width': 1280, 'height': 720})
    pg = ctx.new_page()
    logs = []
    pg.on('console', lambda m: logs.append((m.type, m.text)))
    pg.on('pageerror', lambda e: logs.append(('pageerror', str(e))))
    t0 = time.time(); pg.goto(a.url, wait_until='load', timeout=120000)
    for t, kind, arg in events:
        dt = t - (time.time() - t0)
        if dt > 0: time.sleep(dt)
        if kind == 'click':
            if a.mobile: pg.touchscreen.tap(*arg)
            else: pg.mouse.click(*arg)
        elif kind == 'key': pg.keyboard.press(arg)
        elif kind == 'shot':
            fn = '%s_%03d.png' % (a.out, int(t)); pg.screenshot(path=fn); print('SHOT', fn)
    b.close()
for typ, txt in logs:
    if typ in ('error', 'warning', 'pageerror') or 'ERROR' in txt or 'SCRIPT' in txt: print('CONSOLE', typ, txt[:300])
print('console lines:', len(logs))
