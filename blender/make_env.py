"""Environment kit: hex floor platform, pillar, lesson-station terminal with holo emitter, gate arch.
Each exported as its own .glb into game/assets/ (origin at the floor contact point / top surface)."""
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import *

def panel_mats():
    return (mat('panel', (0.06, 0.07, 0.09), 0.85, 0.32), mat('panel_light', (0.18, 0.2, 0.24), 0.8, 0.28),
            mat('trim', (0.1, 0.85, 1.0), 0.0, 0.3, emit=(0.1, 0.85, 1.0), strength=5),
            mat('trim_mag', (1.0, 0.3, 0.9), 0.0, 0.3, emit=(1.0, 0.3, 0.85), strength=4))

def hex_platform():
    reset(); panel, plight, trim, mag = panel_mats()
    # hex slab, top at z=0
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=4.0, depth=0.6, location=(0, 0, -0.3))
    s = bpy.context.active_object; s.name = 'Slab'; assign(s, panel)
    s.data.materials.append(plight)
    bm = bmesh.new(); bm.from_mesh(s.data)
    top = [f for f in bm.faces if f.normal.z > 0.9][0]
    r = bmesh.ops.inset_region(bm, faces=[top], thickness=0.35, depth=0.0)
    r2 = bmesh.ops.inset_region(bm, faces=[top], thickness=0.06, depth=-0.03)
    top.material_index = 1
    bmesh.ops.inset_individual(bm, faces=[top], thickness=1.2, depth=0.0)
    bm.to_mesh(s.data); bm.free()
    bevel(s, 0.03, 2, angle=35)
    # glowing rim ring segments
    parts = [s]
    for k in range(6):
        a0 = math.radians(60 * k); a1 = math.radians(60 * (k + 1))
        p0 = Vector((math.cos(a0), math.sin(a0), 0)) * 3.83; p1 = Vector((math.cos(a1), math.sin(a1), 0)) * 3.83
        mid = (p0 + p1) / 2; L = (p1 - p0).length
        c = cube('rim', (mid.x, mid.y, 0.005), (L * 0.86, 0.06, 0.02), trim)
        c.rotation_euler.z = math.atan2(p1.y - p0.y, p1.x - p0.x)
        parts.append(c)
        c2 = cube('side', (mid.x * 1.035, mid.y * 1.035, -0.32), (L * 0.6, 0.03, 0.04), mag)
        c2.rotation_euler.z = c.rotation_euler.z; parts.append(c2)
    # underside emitter cone
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=2.6, radius2=0.5, depth=1.4, location=(0, 0, -1.3), rotation=(math.pi, 0, 0))
    cone = bpy.context.active_object; assign(cone, panel); parts.append(cone)
    parts.append(cyl('core', (0, 0, -2.05), 0.35, 0.2, trim, verts=6))
    o = join(parts, 'Platform'); set_origin(o, (0, 0, 0))
    export_glb(os.path.join(ASSETS, 'platform.glb'), [o])

def pillar():
    reset(); panel, plight, trim, mag = panel_mats()
    p = [cyl('base', (0, 0, 0.2), 0.7, 0.4, panel, verts=8, bev=0.03),
         cyl('shaft', (0, 0, 3.2), 0.38, 5.8, plight, verts=8, bev=0.02),
         cyl('cap', (0, 0, 6.2), 0.6, 0.3, panel, verts=8, bev=0.03),
         cyl('orb_ring', (0, 0, 6.42), 0.45, 0.06, trim, verts=8)]
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        c = cube('strip', (math.cos(a) * 0.365, math.sin(a) * 0.365, 3.2), (0.05, 0.05, 5.0), trim if k % 2 == 0 else mag)
        c.rotation_euler.z = a; p.append(c)
    o = join(p, 'Pillar'); set_origin(o, (0, 0, 0))
    export_glb(os.path.join(ASSETS, 'pillar.glb'), [o])

def terminal():
    reset(); panel, plight, trim, mag = panel_mats()
    screen = mat('screen', (0.02, 0.1, 0.15), 0.0, 0.2, emit=(0.1, 0.6, 0.9), strength=2.5)
    p = [cyl('base', (0, 0, 0.08), 1.1, 0.16, panel, verts=8, bev=0.02),
         cyl('baser', (0, 0, 0.165), 1.0, 0.02, trim, verts=8),
         cyl('step', (0, 0, 0.22), 0.85, 0.1, plight, verts=8, bev=0.015),
         cyl('col', (0, 0, 0.62), 0.22, 0.8, panel, verts=8, bev=0.02),
         cyl('emitter', (0, 0, 1.06), 0.45, 0.1, plight, verts=24, bev=0.02),
         torus('emring', (0, 0, 1.12), 0.38, 0.025, trim),
         cyl('lens', (0, 0, 1.12), 0.12, 0.04, trim, verts=24)]
    con = cube('console', (0, -0.55, 0.78), (0.7, 0.08, 0.42), panel, bev=0.02)
    con.rotation_euler.x = math.radians(-35); p.append(con)
    scr = cube('screen', (0, -0.585, 0.80), (0.6, 0.02, 0.32), screen)
    scr.rotation_euler.x = math.radians(-35); p.append(scr)
    arm = cube('arm', (0, -0.36, 0.6), (0.12, 0.35, 0.08), panel); p.append(arm)
    o = join(p, 'Terminal'); set_origin(o, (0, 0, 0))
    export_glb(os.path.join(ASSETS, 'terminal.glb'), [o])

def arch():
    reset(); panel, plight, trim, mag = panel_mats()
    p = []
    for x in (-2.3, 2.3):
        p.append(cube('post', (x, 0, 2.3), (0.6, 0.8, 4.6), panel, bev=0.05))
        p.append(cube('postlight', (x * 0.87, 0, 2.2), (0.04, 0.5, 4.0), trim))
    p.append(cube('beam', (0, 0, 4.85), (5.8, 0.9, 0.6), panel, bev=0.05))
    p.append(cube('beamlight', (0, 0, 4.53), (4.2, 0.5, 0.04), trim))
    for x in (-1.5, 0, 1.5):
        p.append(cube('chevron', (x, -0.46, 4.85), (0.5, 0.03, 0.12), mag))
    o = join(p, 'Arch'); set_origin(o, (0, 0, 0))
    export_glb(os.path.join(ASSETS, 'arch.glb'), [o])

hex_platform(); pillar(); terminal(); arch()
