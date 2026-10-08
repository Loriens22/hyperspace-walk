"""Mobile emulation test with real CDP touch events.
python test/mobile.py URL OUT --device "Pixel 7" [--landscape] --wait N --ev 'tapb:jump@t;tap:x,y@t;joy:dx,dy,dur@t;look:dx,dy,dur@t;joylook:dx,dy,ldx,dur@t;holdb:ana,dur@t;shot@t;key:KeyW@t'
Button names / joystick come from the game's '[touch] layout' console line (canvas units -> CSS px)."""
import re, time, argparse
from playwright.sync_api import sync_playwright
ap = argparse.ArgumentParser(); ap.add_argument('url'); ap.add_argument('out')
ap.add_argument('--device', default='Pixel 7'); ap.add_argument('--landscape', action='store_true')
ap.add_argument('--wait', type=float, default=40); ap.add_argument('--ev', default='')
a = ap.parse_args()
ev = [(float(e.rsplit('@', 1)[1]), e.rsplit('@', 1)[0]) for e in filter(None, a.ev.split(';'))]
ev.append((a.wait, 'shot')); ev.sort(key=lambda e: e[0])
logs = []
with sync_playwright() as p:
    dev = dict(p.devices[a.device])
    if a.landscape:
        vw, vh = dev['viewport']['width'], dev['viewport']['height']
        dev['viewport'] = {'width': max(vw, vh), 'height': min(vw, vh)}
        if 'screen' in dev: dev['screen'] = {'width': max(vw, vh), 'height': min(vw, vh)}
    dev.pop('default_browser_type', None)
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', headless=True,
        args=['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'])
    ctx = b.new_context(**dev)
    pg = ctx.new_page()
    cdp = ctx.new_cdp_session(pg)
    pg.on('console', lambda m: logs.append((time.time(), m.type, m.text)))
    pg.on('pageerror', lambda e: logs.append((time.time(), 'pageerror', str(e))))
    W, H = dev['viewport']['width'], dev['viewport']['height']
    print('viewport', W, H, 'dpr', dev.get('device_scale_factor'))
    def layout():
        pos, k = {}, 1.0
        for pref in ('[touch] menus', '[touch] layout'):
            for _, _, t in reversed(logs):
                if t.startswith(pref):
                    m = re.search(r'vp=\(([\d.]+), ([\d.]+)\)', t); k = W / float(m.group(1))
                    pos.update({n: (float(x) * k, float(y) * k) for n, x, y in re.findall(r'(\w+)=\(([-\d.]+), ([-\d.]+)\)', t) if n != 'vp'})
                    break
        return pos, k
    def touch(kind, pts):
        cdp.send('Input.dispatchTouchEvent', {'type': kind, 'touchPoints': [{'x': x, 'y': y, 'id': i} for i, (x, y) in pts.items()]})
    def drag(paths, dur):
        # paths: {id: (x0,y0,x1,y1)}; all fingers move together
        start = {i: (q[0], q[1]) for i, q in paths.items()}
        touch('touchStart', start); n = max(4, int(dur / 0.1))
        for s in range(1, n + 1):
            f = s / n
            touch('touchMove', {i: (q[0] + (q[2] - q[0]) * min(1, f * 3) if i == 1 else q[0] + (q[2] - q[0]) * f, q[1] + (q[3] - q[1]) * min(1, f * 3) if i == 1 else q[1] + (q[3] - q[1]) * f) for i, q in paths.items()})
            pg.wait_for_timeout(1000 * (dur / n))
        touch('touchEnd', {})
    t0 = time.time(); pg.goto(a.url, wait_until='load', timeout=120000)
    for t, body in ev:
        dt = t - (time.time() - t0)
        if dt > 0: pg.wait_for_timeout(1000 * (dt))
        kind, _, arg = body.partition(':')
        print('%5.1f %s' % (time.time() - t0, body), flush=True)
        try:
            pos, k = layout()
            if kind == 'tap':
                x, y = map(float, arg.split(',')); touch('touchStart', {0: (x, y)}); pg.wait_for_timeout(1000 * (0.25)); touch('touchEnd', {})
            elif kind == 'tapb':
                x, y = pos[arg]; touch('touchStart', {0: (x, y)}); pg.wait_for_timeout(1000 * (0.35)); touch('touchEnd', {})
            elif kind == 'holdb':
                n, d = arg.split(','); x, y = pos[n]; touch('touchStart', {0: (x, y)}); pg.wait_for_timeout(1000 * (float(d))); touch('touchEnd', {})
            elif kind == 'joy':
                dx, dy, d = map(float, arg.split(',')); jx, jy = pos['joy']
                drag({1: (jx, jy, jx + dx * k, jy + dy * k)}, d)
            elif kind == 'look':
                dx, dy, d = map(float, arg.split(','))
                drag({2: (W * 0.62, H * 0.45, W * 0.62 + dx, H * 0.45 + dy)}, d)
            elif kind == 'joylook':
                dx, dy, ldx, d = map(float, arg.split(',')); jx, jy = pos['joy']
                drag({1: (jx, jy, jx + dx * k, jy + dy * k), 2: (W * 0.62, H * 0.45, W * 0.62 + ldx, H * 0.45)}, d)
            elif kind == 'key': pg.keyboard.press(arg)
            elif kind == 'shot':
                fn = '%s_%03d.png' % (a.out, int(t)); pg.screenshot(path=fn); print('SHOT', fn, flush=True)
        except Exception as ex:
            print('EXC', kind, ex)
    try: b.close()
    except Exception: pass
for ts, typ, txt in logs:
    if typ in ('error', 'warning', 'pageerror') or 'ERROR' in txt or 'SCRIPT' in txt or txt.startswith('['):
        print('%6.1f CONSOLE %s %s' % (ts - t0, typ, txt[:400]))
print('console lines:', len(logs))
