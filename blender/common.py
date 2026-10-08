"""Shared helpers for the Hyperspace Walk Blender asset scripts (Blender 4.2+, run with -b --python)."""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, 'game', 'assets')
SHOTS = os.path.join(ROOT, 'shots')

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def mat(name, color=(0.8, 0.8, 0.8), metal=0.0, rough=0.5, emit=None, strength=0.0, alpha=1.0, coat=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    if coat: b.inputs['Coat Weight'].default_value = coat
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1)
        b.inputs['Emission Strength'].default_value = strength
    if alpha < 1:
        b.inputs['Alpha'].default_value = alpha
        m.surface_render_method = 'BLENDED'
    return m

def assign(obj, m):
    obj.data.materials.clear(); obj.data.materials.append(m)

def active(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True); bpy.context.view_layer.objects.active = obj

def bevel(obj, w=0.02, seg=3, angle=None):
    md = obj.modifiers.new('bev', 'BEVEL'); md.width = w; md.segments = seg
    if angle: md.limit_method = 'ANGLE'; md.angle_limit = math.radians(angle)
    return md

def subsurf(obj, lv=2):
    md = obj.modifiers.new('sub', 'SUBSURF'); md.levels = lv; md.render_levels = lv
    return md

def apply_all(obj):
    active(obj)
    for md in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)

def smooth(obj, auto=40):
    active(obj)
    bpy.ops.object.shade_smooth()
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(auto))
    except Exception:
        pass

def cube(name, loc, size, m=None, bev=0.0, seg=3):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object; o.name = name; o.scale = size
    active(o); bpy.ops.object.transform_apply(scale=True)
    if bev: bevel(o, bev, seg)
    if m: assign(o, m)
    return o

def cyl(name, loc, r, depth, m=None, verts=32, rot=(0, 0, 0), bev=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object; o.name = name
    if bev: bevel(o, bev, 2)
    if m: assign(o, m)
    return o

def sphere(name, loc, r, m=None, scale=(1, 1, 1), seg=32, ring=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, radius=r, location=loc)
    o = bpy.context.active_object; o.name = name; o.scale = scale
    active(o); bpy.ops.object.transform_apply(scale=True)
    if m: assign(o, m)
    return o

def torus(name, loc, R, r, m=None, rot=(0, 0, 0), maj=48, mi=12):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=maj, minor_segments=mi, location=loc, rotation=rot)
    o = bpy.context.active_object; o.name = name
    if m: assign(o, m)
    return o

def capsule(name, a, b, r, m=None, seg=24):
    """cylinder with hemispherical ends from point a to b"""
    a, b = Vector(a), Vector(b); d = b - a; L = d.length
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=(0, 0, 0))
    o = bpy.context.active_object; o.name = name
    bm = bmesh.new(); bm.from_mesh(o.data)
    for v in bm.verts:
        if v.co.z > 0: v.co.z += L
    bm.to_mesh(o.data); bm.free()
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    o.rotation_mode = 'QUATERNION'; o.rotation_quaternion = q; o.location = a
    active(o); bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.location = a
    active(o); bpy.ops.object.transform_apply(location=True)
    if m: assign(o, m)
    return o

def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        apply_all(o)
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object; o.name = name
    return o

def set_origin(obj, p):
    bpy.context.scene.cursor.location = p
    active(obj); bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.context.scene.cursor.location = (0, 0, 0)

def export_glb(path, objs=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    objs = objs or [o for o in bpy.data.objects if o.type == 'MESH']
    for o in objs:
        apply_all(o)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True,
                              export_yup=True, export_materials='EXPORT')
    print('EXPORTED', path)

def studio(target=(0, 0, 1), dist=3.2, height=1.4, lens=60, world=(0.004, 0.006, 0.014), res=(1280, 960), samples=64):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.samples = samples; sc.cycles.use_denoising = True
    sc.cycles.device = 'CPU'
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Punchy'
    w = bpy.data.worlds.new('W'); sc.world = w; w.use_nodes = True
    w.node_tree.nodes['Background'].inputs['Color'].default_value = (*world, 1)
    t = Vector(target)
    bpy.ops.object.camera_add(location=t + Vector((dist * 0.55, -dist, height - t.z + t.z * 0.2)))
    cam = bpy.context.active_object; cam.data.lens = lens; sc.camera = cam
    d = t - cam.location; cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    def area(name, loc, energy, color, size=2.0):
        bpy.ops.object.light_add(type='AREA', location=loc)
        l = bpy.context.active_object; l.data.energy = energy; l.data.color = color; l.data.size = size
        dd = t - l.location; l.rotation_euler = dd.to_track_quat('-Z', 'Y').to_euler()
    area('key', t + Vector((2.5, -2.5, 2.5)), 400, (1.0, 0.95, 0.9))
    area('rim', t + Vector((-2.5, 2.0, 1.5)), 600, (0.3, 0.7, 1.0))
    area('fill', t + Vector((-3, -2, 0.2)), 120, (0.8, 0.4, 1.0))
    # reflective dark floor
    bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
    fl = bpy.context.active_object; assign(fl, mat('floor', (0.02, 0.025, 0.04), 0.6, 0.25))
    return cam

def render(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print('RENDERED', path)
