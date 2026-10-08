"""Sequential, console-driven browser test (robust under slow software GL).
python test/flow.py URL OUT [--mobile "Pixel 7" --landscape] --steps 'click:x,y;clickb:name;key:KeyK;wait:regex[,timeout];sleep:s;shot:name;tapb:name;holdk:Key,s;holdb:name,s'
clickb/tapb use the latest '[touch] menus' / '[touch] layout' line (canvas units scaled to CSS px)."""
import sys, time, re, argparse
from playwright.sync_api import sync_playwright
ap = argparse.ArgumentParser(); ap.add_argument('url'); ap.add_argument('out')
ap.add_argument('--steps', default=''); ap.add_argument('--mobile', default=''); ap.add_argument('--landscape', action='store_true')
a = ap.parse_args()
logs = []
def coords(name):
    for pref in ('[touch] menus', '[touch] layout'):
        for _, typ, txt in reversed(logs):
            if txt.startswith(pref):
                m = re.search(r'\b%s=\(([-\d.]+), ([-\d.]+)\)' % re.escape(name), txt)
                vp = re.search(r'vp=\(([-\d.]+), ([-\d.]+)\)', txt)
                if m:
                    return float(m.group(1)), float(m.group(2)), float(vp.group(1)), float(vp.group(2))
                break
    raise RuntimeError('no coords for ' + name)
with sync_playwright() as p:
    b = p.chromium.launch(executable_path='/usr/bin/google-chrome', headless=True,
        args=['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'])
    if a.mobile:
        d = dict(p.devices[a.mobile])
        if a.landscape:
            vw = d['viewport']; d['viewport'] = {'width': vw['height'], 'height': vw['width']}
            if 'screen' in d: d['screen'] = {'width': d['screen']['height'], 'height': d['screen']['width']}
        ctx = b.new_context(**d)
    else:
        ctx = b.new_context(viewport={'width': 1280, 'height': 720})
    pg = ctx.new_page()
    cdp = ctx.new_cdp_session(pg) if a.mobile else None
    VW, VH = pg.viewport_size['width'], pg.viewport_size['height']
    pg.on('console', lambda m: logs.append((time.time(), m.type, m.text)))
    pg.on('pageerror', lambda e: logs.append((time.time(), 'pageerror', str(e))))
    t0 = time.time(); pg.goto(a.url, wait_until='load', timeout=120000)
    def touch(typ, pts):
        cdp.send('Input.dispatchTouchEvent', {'type': typ, 'touchPoints': [{'x': x, 'y': y, 'id': 1} for x, y in pts]})
    def css(name):
        x, y, cw, ch = coords(name); return x * VW / cw, y * VH / ch
    ok = True
    mark_i = 0
    for st in filter(None, a.steps.split(';')):
        kind, _, arg = st.partition(':')
        print('%6.1f %s' % (time.time() - t0, st), flush=True)
        try:
            if kind == 'wait':
                rx, _, to = arg.partition(','); to = float(to or 90); n0 = 0
                rxc = re.compile(rx); end = time.time() + to; hit = False
                while time.time() < end:
                    if any(rxc.search(t) for _, _, t in logs[mark_i:]): hit = True; break
                    pg.wait_for_timeout(250)
                print('   ->', 'OK' if hit else 'TIMEOUT', flush=True); ok = ok and hit
            elif kind == 'mark':  # later waits only look at newer console lines
                mark_i = len(logs)
            elif kind == 'sleep': pg.wait_for_timeout(float(arg) * 1000)
            elif kind == 'click':
                x, y = map(float, arg.split(',')); pg.mouse.click(x, y)
            elif kind == 'clickb':
                x, y = css(arg); pg.mouse.click(x, y)
            elif kind == 'tapb':
                x, y = css(arg); touch('touchStart', [(x, y)]); pg.wait_for_timeout(120); touch('touchEnd', [])
            elif kind == 'holdb':
                n, s = arg.split(','); x, y = css(n); touch('touchStart', [(x, y)]); pg.wait_for_timeout(float(s) * 1000); touch('touchEnd', [])
            elif kind == 'key': pg.keyboard.press(arg)
            elif kind == 'holdk':
                k, s = arg.split(','); pg.keyboard.down(k); pg.wait_for_timeout(float(s) * 1000); pg.keyboard.up(k)
            elif kind == 'shot':
                fn = '%s_%s.png' % (a.out, arg); pg.screenshot(path=fn); print('SHOT', fn, flush=True)
        except Exception as ex:
            print('EXC', ex); ok = False
    pg.wait_for_timeout(500)
    errs = [(ts, typ, txt) for ts, typ, txt in logs if typ in ('error', 'pageerror') or 'SCRIPT ERROR' in txt or 'ERROR:' in txt]
    try: b.close()
    except Exception: pass
for ts, typ, txt in errs: print('ERR %s %s' % (typ, txt[:300]))
print('RESULT', 'PASS' if ok and not errs else 'FAIL', 'errors=%d' % len(errs))
