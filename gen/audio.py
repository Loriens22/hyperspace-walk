"""Procedural ambient music + SFX (numpy synth) -> game/audio/*.ogg
pad_3d: warm low drone (our slice). pad_4d: higher shimmering fifths (deep in w). Crossfaded by |w| in game."""
import numpy as np, subprocess, os
SR = 44100
rng = np.random.default_rng(4)
def save(name, x, sr=SR):
    x = np.asarray(x, dtype=np.float32)
    if x.ndim == 1: x = np.stack([x, x], 1)
    x = x / (np.abs(x).max() + 1e-9) * 0.85
    raw = f'/tmp/{name}.f32'
    x.astype('<f4').tofile(raw)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'f32le', '-ar', str(sr), '-ac', '2', '-i', raw,
                    '-c:a', 'libvorbis', '-q:a', '4', f'game/audio/{name}.ogg'], check=True)
    os.remove(raw); print('wrote', name, x.shape[0] / sr, 's')
def t_(d): return np.arange(int(d * SR)) / SR
def lp(x, a):  # one-pole lowpass
    y = np.empty_like(x); s = 0.0
    for i in range(len(x)): s += a * (x[i] - s); y[i] = s
    return y
def mtof(m): return 440 * 2 ** ((m - 69) / 12)
def loopify(x, fade):
    n = int(fade * SR); body = x[:-n].copy(); tail = x[-n:]
    r = np.linspace(0, 1, n)[:, None] if x.ndim == 2 else np.linspace(0, 1, n)
    body[:n] = body[:n] * r + tail * (1 - r); return body
def pad(notes, dur, bright, detune=0.15, lfo=0.05):
    t = t_(dur); L = np.zeros_like(t); R = np.zeros_like(t)
    for k, m in enumerate(notes):
        f = mtof(m)
        for d in (-detune, 0, detune):
            ff = f * 2 ** (d / 12)
            ph = rng.uniform(0, 6.28)
            amp = 0.5 + 0.5 * np.sin(2 * np.pi * (lfo * (1 + 0.3 * k)) * t + ph)
            sig = np.sin(2 * np.pi * ff * t + ph) + bright * 0.5 * np.sin(4 * np.pi * ff * t + ph * 2) + bright * 0.25 * np.sin(6 * np.pi * ff * t)
            pan = 0.5 + 0.4 * np.sin(ph + k)
            L += sig * amp * (1 - pan); R += sig * amp * pan
    return np.stack([L, R], 1)
DUR = 48
# 3D layer: D minor 9 low, slow
p3 = pad([38, 45, 50, 53, 57, 64], DUR + 6, 0.25, lfo=0.03)
noise = lp(rng.normal(0, 1, len(p3)), 0.002)
p3[:, 0] += noise * 0.6; p3[:, 1] += np.roll(noise, 999) * 0.6
save('pad_3d', loopify(p3, 6))
# 4D layer: open fifths/fourths high, shimmer
p4 = pad([62, 69, 74, 76, 81, 86, 88], DUR + 6, 0.6, detune=0.25, lfo=0.09)
t = t_(DUR + 6)
for k in range(40):  # crystalline sparkles
    st = rng.uniform(0, DUR); f = mtof(rng.choice([86, 88, 93, 95, 98, 100]))
    env = np.where(t > st, np.exp(-(t - st) * 1.4), 0) * (t > st)
    s = np.sin(2 * np.pi * f * t) * env * 0.35; pan = rng.uniform(0.2, 0.8)
    p4[:, 0] += s * (1 - pan); p4[:, 1] += s * pan
save('pad_4d', loopify(p4, 6))
# crystalline tone near polytopes (loop 8 s)
t = t_(10); x = np.zeros_like(t)
for f, a in [(mtof(81), 1), (mtof(88), .6), (mtof(93), .4), (mtof(100), .25)]:
    x += a * np.sin(2 * np.pi * f * t) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.25 * t * (1 + f / 4000)))
save('crystal', loopify(np.stack([x, x], 1), 2))
def chime(notes, step=0.11, decay=2.0, dur=2.5):
    t = t_(dur); x = np.zeros_like(t)
    for i, m in enumerate(notes):
        st = i * step; f = mtof(m); e = np.where(t >= st, np.exp(-(t - st) * decay), 0)
        x += e * (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * 2.01 * f * t) + 0.15 * np.sin(2 * np.pi * 3.98 * f * t))
    return x
save('unlock', chime([74, 78, 81, 86, 90], 0.09, 2.2, 2.8))
save('success', chime([69, 73, 76, 81, 85, 88], 0.07, 2.5, 2.5))
save('ui', chime([88], 0, 18, 0.25))
save('line', chime([81, 86], 0.05, 9, 0.5) * 0.6)
t = t_(0.6); sw = np.sin(2 * np.pi * (300 + 900 * t / 0.6) * t) * np.exp(-((t - 0.3) / 0.15) ** 2)
nz = lp(rng.normal(0, 1, len(t)), 0.08) * np.exp(-((t - 0.3) / 0.18) ** 2)
save('wstep', sw * 0.5 + nz)
t = t_(1.6); door = lp(rng.normal(0, 1, len(t)), 0.03) * np.exp(-t * 2.5) + np.sin(2 * np.pi * (80 - 30 * t) * t) * np.exp(-t * 2) * 0.8
save('door', door)
t = t_(0.18); step = lp(rng.normal(0, 1, len(t)), 0.15) * np.exp(-t * 40) + np.sin(2 * np.pi * 90 * t) * np.exp(-t * 50) * 0.6
save('step', step)
t = t_(0.9); fall = np.sin(2 * np.pi * (600 - 500 * t) * t) * np.exp(-t * 3)
save('fall', fall)
