"""Explorer character: stylised space-suit humanoid, separate limb objects with pivots at shoulders/hips
so Godot can animate a procedural walk cycle. Exports game/assets/explorer.glb, renders shots/render_explorer.png"""
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
suit = mat('suit', (0.86, 0.88, 0.9), 0.05, 0.42, coat=0.4)
dark = mat('joint', (0.05, 0.055, 0.07), 0.7, 0.35)
accent = mat('accent', (0.1, 0.9, 1.0), 0.0, 0.3, emit=(0.15, 0.9, 1.0), strength=6)
orange = mat('orange', (1.0, 0.45, 0.1), 0.1, 0.4, emit=(1.0, 0.4, 0.1), strength=1.5)
visor = mat('visor', (0.01, 0.02, 0.05), 1.0, 0.06, emit=(0.05, 0.25, 0.6), strength=0.6)

parts = []
parts.append(cube('torso', (0, 0, 1.2), (0.40, 0.24, 0.50), suit, bev=0.08, seg=4))
ab = cyl('abdomen', (0, 0, 0.95), 0.15, 0.2, dark); ab.scale = (1.0, 0.7, 1.0); parts.append(ab)
parts.append(cube('pelvis', (0, 0, 0.84), (0.34, 0.22, 0.16), suit, bev=0.05))
parts.append(cube('belt', (0, 0, 0.90), (0.36, 0.236, 0.035), accent, bev=0.012))
parts.append(cube('chestlight', (0, -0.122, 1.31), (0.13, 0.02, 0.05), accent, bev=0.008))
for x in (-0.14, 0.14):
    parts.append(cube('stripe', (x, -0.121, 1.18), (0.025, 0.02, 0.22), orange, bev=0.006))
parts.append(torus('collar', (0, 0, 1.465), 0.12, 0.035, dark))
parts.append(cube('pack', (0, 0.19, 1.22), (0.34, 0.16, 0.42), dark, bev=0.04))
for x in (-0.08, 0.08):
    parts.append(cube('packlight', (x, 0.272, 1.24), (0.03, 0.012, 0.30), accent, bev=0.005))
for x in (-0.25, 0.25):
    parts.append(sphere('shoulder', (x, 0, 1.40), 0.09, suit, scale=(1, 1, 0.8)))
body = join(parts, 'Body')

head = [sphere('helmet', (0, 0, 1.64), 0.16, suit, scale=(1, 1, 1.05)),
        sphere('visor', (0, -0.055, 1.645), 0.135, visor, scale=(1, 0.85, 0.72))]
for x in (-0.158, 0.158):
    head.append(cyl('hl', (x, 0, 1.64), 0.03, 0.03, accent, rot=(0, math.radians(90), 0)))
head.append(cube('antenna', (0.1, 0.06, 1.82), (0.01, 0.01, 0.12), dark))
head.append(sphere('antip', (0.1, 0.06, 1.885), 0.014, accent))
hd = join(head, 'Head'); set_origin(hd, (0, 0, 1.48))

def arm(side):
    s = 1 if side == 'L' else -1
    p = [capsule('ua', (0.27 * s, 0, 1.38), (0.30 * s, 0, 1.10), 0.06, suit),
         sphere('elbow', (0.30 * s, 0, 1.08), 0.062, dark),
         capsule('fa', (0.30 * s, 0, 1.08), (0.31 * s, -0.02, 0.84), 0.056, suit),
         torus('cuff', (0.31 * s, -0.018, 0.86), 0.058, 0.012, accent),
         sphere('glove', (0.31 * s, -0.022, 0.78), 0.058, dark, scale=(0.9, 1.1, 1.2))]
    a = join(p, 'Arm' + side); set_origin(a, (0.27 * s, 0, 1.38)); return a

def leg(side):
    s = 1 if side == 'L' else -1
    p = [capsule('th', (0.10 * s, 0, 0.82), (0.11 * s, 0, 0.48), 0.078, suit),
         sphere('knee', (0.11 * s, -0.05, 0.47), 0.06, dark, scale=(1, 0.8, 1)),
         capsule('sh', (0.11 * s, 0, 0.46), (0.11 * s, 0, 0.14), 0.066, suit),
         cube('boot', (0.11 * s, -0.03, 0.065), (0.13, 0.24, 0.13), dark, bev=0.03),
         cube('sole', (0.11 * s, -0.03, 0.006), (0.135, 0.245, 0.012), accent, bev=0.004)]
    l = join(p, 'Leg' + side); set_origin(l, (0.10 * s, 0, 0.82)); return l

limbs = [arm('L'), arm('R'), leg('L'), leg('R')]
for o in [body, hd] + limbs: smooth(o)
export_glb(os.path.join(ASSETS, 'explorer.glb'), [body, hd] + limbs)
if '--render' in sys.argv:
    limbs[0].rotation_euler.x = math.radians(-20); limbs[1].rotation_euler.x = math.radians(25)
    limbs[2].rotation_euler.x = math.radians(18); limbs[3].rotation_euler.x = math.radians(-15)
    for o in [body, hd] + limbs: o.rotation_euler.z += math.radians(25) if o in (body, hd) else 0
    studio(target=(0, 0, 0.95), dist=3.4, height=1.5, lens=55)
    render(os.path.join(SHOTS, 'render_explorer.png'))
