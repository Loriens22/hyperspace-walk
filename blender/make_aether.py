"""Aether: small floating crystalline-blue robot companion (faceted translucent body, glowing core,
eye, three fins, two orbit rings, thruster). Exports game/assets/aether.glb, renders shots/render_aether.png"""
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

reset()
crystal = mat('crystal', (0.08, 0.35, 1.0), 0.0, 0.04, emit=(0.03, 0.2, 0.9), strength=0.35, alpha=0.38)
core = mat('core', (0.4, 0.85, 1.0), 0.0, 0.2, emit=(0.25, 0.75, 1.0), strength=7)
eye = mat('eye', (0.8, 1.0, 1.0), 0.0, 0.2, emit=(0.6, 1.0, 1.0), strength=5)
ringm = mat('ring', (0.05, 0.3, 1.0), 0.6, 0.2, emit=(0.05, 0.35, 1.0), strength=2.2)
finm = mat('fin', (0.2, 0.5, 1.0), 0.3, 0.15, emit=(0.05, 0.3, 1.0), strength=0.5, alpha=0.65)
metal = mat('metal', (0.75, 0.82, 0.9), 1.0, 0.25)

bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(0, 0, 0))
b = bpy.context.active_object; b.name = 'Body'; b.scale = (0.12, 0.12, 0.17)
active(b); bpy.ops.object.transform_apply(scale=True); assign(b, crystal)
bev = bevel(b, 0.006, 1)
inner = sphere('Core', (0, 0, 0), 0.05, core)
e = sphere('Eye', (0, -0.112, 0.025), 1.0, eye, scale=(0.045, 0.012, 0.018))
cap = cyl('Cap', (0, 0, 0.165), 0.035, 0.02, metal, verts=16)
r1 = torus('Ring1', (0, 0, 0), 0.2, 0.0075, ringm, rot=(math.radians(14), 0, 0), maj=64, mi=8)
r2 = torus('Ring2', (0, 0, 0), 0.165, 0.006, ringm, rot=(math.radians(-62), math.radians(20), 0), maj=64, mi=8)
fins = []
for k in range(3):
    a = math.radians(90 + 120 * k)
    f = cube('fin', (0, 0, 0), (0.012, 0.08, 0.15), finm, bev=0.005)
    f.location = (math.cos(a) * 0.135, math.sin(a) * 0.135, -0.03)
    f.rotation_euler = (math.radians(-18), 0, a + math.radians(90))
    f.rotation_euler = (0, math.radians(22), a)
    fins.append(f)
fn = join(fins, 'Fins')
th = cyl('Thruster', (0, 0, -0.19), 0.025, 0.03, core, verts=16)
objs = [b, inner, e, cap, r1, r2, fn, th]
for o in objs: apply_all(o)
smooth(inner); smooth(r1); smooth(r2); smooth(e)
export_glb(os.path.join(ASSETS, 'aether.glb'), objs)
if '--render' in sys.argv:
    for o in objs: o.location.z += 0.55
    bpy.ops.object.light_add(type='POINT', location=(0, 0, 0.55)); pl = bpy.context.active_object
    pl.data.energy = 4; pl.data.color = (0.4, 0.8, 1.0); pl.data.shadow_soft_size = 0.05
    studio(target=(0, 0, 0.55), dist=1.05, height=0.75, lens=70)
    bpy.context.scene.cycles.samples = 96
    bpy.context.scene.view_settings.look = 'AgX - Base Contrast'
    for l in bpy.data.lights:
        if l.type == 'AREA': l.energy *= 0.25
    render(os.path.join(SHOTS, 'render_aether.png'))
