"""Reproducible real-geometry cockpit fly-through, rendered with Blender EEVEE.

Blender -b --factory-startup --python tools/render_planet_flight.py -- preview
Blender -b --factory-startup --python tools/render_planet_flight.py -- movie
1440-square, 30 fps, six seconds. Preview frames stay in /tmp; movie mode
atomically replaces the deliverable video and matching poster after rendering.
No downloaded artwork, external textures, or paid assets.
"""
import bpy
import math
import os
import random
import sys
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT = os.path.join(ROOT, 'assets', 'cinematics')
os.makedirs(OUTPUT, exist_ok=True)
mode = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else 'preview'
random.seed(761)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
s = bpy.context.scene
s.render.engine = 'BLENDER_EEVEE'
s.render.resolution_x = 1440
s.render.resolution_y = 1440
s.render.resolution_percentage = 100
s.render.fps = 30
s.render.use_motion_blur = True
s.render.motion_blur_shutter = .28
s.eevee.motion_blur_steps = 2
s.eevee.motion_blur_max = 28
s.frame_start = 1
s.frame_end = 180
s.render.image_settings.color_mode = 'RGB'
s.render.film_transparent = False
s.world.color = (0.004, 0.008, 0.025)
s.world.use_nodes = True
s.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.001, .003, .012, 1)
s.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .3
s.view_settings.view_transform = 'AgX'
if hasattr(s.eevee, 'taa_render_samples'):
    s.eevee.taa_render_samples = 128
s.render.use_compositing = True
s.use_nodes = True
nt=bpy.data.node_groups.new('Flight compositor','CompositorNodeTree')
s.compositing_node_group=nt
nt.interface.new_socket(name='Image', in_out='OUTPUT', socket_type='NodeSocketColor')
nt.nodes.clear()
rl=nt.nodes.new('CompositorNodeRLayers')
gl=nt.nodes.new('CompositorNodeGlare'); gl.inputs['Type'].default_value='Fog Glow'; gl.inputs['Quality'].default_value='High'; gl.inputs['Threshold'].default_value=2.8; gl.inputs['Strength'].default_value=.12
out=nt.nodes.new('NodeGroupOutput')
nt.links.new(rl.outputs['Image'],gl.inputs['Image']); nt.links.new(gl.outputs['Image'],out.inputs['Image'])

def material(name, color, metallic=0, roughness=.4, emission=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metallic
    p.inputs['Roughness'].default_value=roughness
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1)
        p.inputs['Emission Strength'].default_value=emission
    return m

hull=material('Ceramic titanium',(.012,.021,.034),.68,.43)
edge=material('Machined edges',(.105,.14,.19),.86,.27)
black=material('Matte instrument glass',(.002,.008,.018),.4,.22)
teal=material('Navigation phosphor',(.12,.68,.61),.1,.35,1.55)
gold=material('Amber instruments',(.95,.46,.10),.15,.35,1.6)
blue=material('Ion coils',(.11,.24,.7),.15,.35,1.6)
white=material('Star glow',(.75,.86,1),0,.5,4)
purple=material('Jump-field filament',(.22,.12,.52),.2,.4,1.35)

# Microstructure changes specular response, not the silhouette.
for mat, roughness in [(hull, .43), (edge, .27)]:
    nt=mat.node_tree; p=nt.nodes['Principled BSDF']
    noise=nt.nodes.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=220
    noise.inputs['Detail'].default_value=2; noise.inputs['Roughness'].default_value=.55
    ramp=nt.nodes.new('ShaderNodeMapRange'); ramp.inputs['From Min'].default_value=0; ramp.inputs['From Max'].default_value=1
    ramp.inputs['To Min'].default_value=roughness-.05; ramp.inputs['To Max'].default_value=roughness+.07
    nt.links.new(noise.outputs['Fac'], ramp.inputs['Value']); nt.links.new(ramp.outputs['Result'], p.inputs['Roughness'])


def apply_mat(obj, m): obj.data.materials.append(m)
def smooth(obj):
    if obj.type=='MESH':
        for p in obj.data.polygons:p.use_smooth=True

def cube(name, location, scale, mat, bevel=0, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    o=bpy.context.object; o.name=name; o.dimensions=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    apply_mat(o,mat)
    if bevel:
        mod=o.modifiers.new('Precision rounded edges','BEVEL');mod.width=bevel;mod.segments=4
        mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    if parent:o.parent=parent
    return o

def tube(name, points, radius, mat, parent=None):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=radius;cu.bevel_resolution=3;cu.resolution_u=10
    sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
    for p,co in zip(sp.points,points):p.co=(*co,1)
    ob=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(ob);apply_mat(ob,mat)
    if parent:ob.parent=parent
    return ob

def sphere(name, center, radius, mat, segments=96, rings=64):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=radius,location=center)
    o=bpy.context.object;o.name=name;apply_mat(o,mat);smooth(o);return o

def light(name,location,energy,color,size):
    d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.color=color;d.shape='DISK';d.size=size
    ob=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(ob);ob.location=location
    return ob

def aim(o, point): o.rotation_euler=(Vector(point)-o.location).to_track_quat('-Z','Y').to_euler()
def center(y): return Vector((3.1*math.sin(y*.032), y, 1.5*math.sin(y*.025)))

# Flight deck is genuine beveled 3D geometry, parented to the moving pilot rig.
rig=bpy.data.objects.new('Flight deck rig',None);bpy.context.collection.objects.link(rig)
bpy.ops.object.camera_add(location=(0,0,0))
cam=bpy.context.object;cam.name='Pilot eye';cam.parent=rig;cam.rotation_euler=(math.pi/2,0,0);cam.data.lens=23;cam.data.clip_end=1400;s.camera=cam
# Thin arch surrounds the window. Central line of sight remains clean.
arch=[(math.cos(a)*2.7,2.2,math.sin(a)*2.35) for a in [math.pi*.04+i*math.pi*.92/64 for i in range(65)]]
tube('Forged canopy arch',arch,.068,hull,rig)
tube('Canopy seam',[(x,y-.042,z-.019) for x,y,z in arch],.007,edge,rig)
for side in [-1,1]:
    tube('Side pillar',[(side*2.56,2.2,.3),(side*2.02,1.85,-.8),(side*1.65,1.6,-1.8)],.095,hull,rig)
    tube('Pillar running light',[(side*2.51,2.17,.28),(side*1.98,1.82,-.8),(side*1.62,1.57,-1.8)],.006,teal,rig)
    for i in range(5):
        cube('Canopy fastener',(side*(2.04+i*.08),1.83+i*.06,-.74+i*.16),(.06,.045,.075),edge,.012,rig)
# Sculpted console, not an overlaid flat graphic.
console=cube('Curved instrument binnacle',(0,1.7,-1.55),(4.2,.95,.43),hull,.08,rig)

def display_text(name, value, x, z, pod, color=teal, size=.032):
    data=bpy.data.curves.new(name, 'FONT'); data.body=value; data.size=size; data.space_character=1.1
    data.align_x='LEFT'; data.align_y='CENTER'; data.extrude=.0002
    ob=bpy.data.objects.new(name, data); bpy.context.collection.objects.link(ob)
    ob.parent=pod; ob.location=(x,1.003,z); ob.rotation_euler=(math.pi/2,0,0); apply_mat(ob,color)
    return ob

def display_line(name, points, pod, color=teal, width=.0025):
    return tube(name, [(x,1.005,z) for x,z in points], width, color, pod)

for index,x in enumerate([-1.25,0,1.25]):
    pod=bpy.data.objects.new('Instrument pod',None);bpy.context.collection.objects.link(pod)
    pod.parent=rig;pod.location=(x,0,0);pod.rotation_euler[2]=-.075*(index-1)
    cube('Precision display housing',(0,1.13,-1.29),(1.02,.15,.41),edge,.024,pod)
    cube('Recessed display gasket',(0,1.032,-1.28),(.94,.025,.355),hull,.012,pod)
    cube('Optical instrument glass',(0,1.014,-1.28),(.895,.013,.315),black,.007,pod)
    for sx in [-1,1]:
        for z in [-1.45,-1.12]:
            bolt=sphere('Display fastener',(sx*.472,1.02,z),.012,black,12,6);bolt.parent=pod
    display_line('Display header rule',[(-.41,-1.20),(.41,-1.20)],pod,edge,.0018)
    # Left-hand display is a flight-vector readout, right-hand a core monitor.
    if index == 0:
        display_text('Flight label','FLIGHT / VECTOR',-.40,-1.155,pod)
        for z in [-1.27,-1.33,-1.39]:
            display_line('Graph grid',[(-.40,z),(.10,z)],pod,edge,.0014)
        display_line('Altitude trace',[(-.40,-1.38),(-.31,-1.37),(-.23,-1.30),(-.15,-1.32),(-.06,-1.25),(.02,-1.28),(.10,-1.25)],pod,teal,.003)
        display_line('Trim trace',[(-.40,-1.32),(-.29,-1.32),(-.18,-1.35),(-.07,-1.34),(.10,-1.31)],pod,gold,.002)
        display_text('Flight velocity','041',.22,-1.28,pod,size=.045)
        display_text('Flight unit','M / S',.23,-1.34,pod,edge,.024)
        display_text('Flight attitude','TRIM  +02',.17,-1.407,pod,size=.022)
    elif index == 1:
        display_text('Navigation label','NAV / APPROACH',-.40,-1.155,pod)
        for radius in [.043,.081,.12]:
            display_line('Radar range circle',[(math.cos(a)*radius,-1.325+math.sin(a)*radius) for a in [i*math.pi*2/64 for i in range(65)]],pod,teal,.0016)
        display_line('Planned vector',[(-.09,-1.39),(-.04,-1.34),(.015,-1.34),(.068,-1.27)],pod,gold,.003)
        display_text('Navigation distance','014.8',.23,-1.275,pod,size=.036)
        display_text('Navigation range unit','RANGE / KM',.20,-1.323,pod,edge,.021)
        display_text('Guidance state','AUTO',-.40,-1.29,pod,gold,.03)
        display_text('Guidance locked','TRACK',-.40,-1.344,pod,size=.024)
        display_text('Guidance confidence','98.4',-.40,-1.398,pod,size=.028)
    else:
        display_text('Core label','CORE / STABLE',-.40,-1.155,pod,gold)
        for row,value in enumerate([.78,.58,.91]):
            z=-1.27-row*.065
            display_text('Core channel',['ION','O2','PWR'][row],-.40,z,pod,teal,.027)
            display_line('Core empty rail',[(-.24,z),(.26,z)],pod,edge,.005)
            display_line('Core active rail',[(-.24,z),(-.24+value*.50,z)],pod,gold,.005)
            display_text('Core value',str(round(value*100)),.31,z,pod,gold,.026)
    for j in range(5):
        cube('Instrument soft key',(-.34+j*.17,1.035,-1.54),(.065,.04,.035),hull,.004,pod)
        cube('Instrument key index',(-.34+j*.17,1.010,-1.54),(.023,.004,.003),teal if j==2 else edge,.001,pod)
for side in [-1,1]:
    for j in range(7):
        cube('Tactile console key',(side*(1.55+j*.052),1.1,-1.60),(.038,.04,.07),gold if j==3 else edge,.01,rig)
    grip=cube('Pilot control grip',(side*.62,.60,-1.79),(.12,.22,.50),black,.055,rig);grip.rotation_euler[1]=side*.16
    cube('Thumb trigger',(side*.62,.51,-1.55),(.07,.05,.06),edge,.012,rig)
    cube('Thumb trigger indicator',(side*.62,.482,-1.54),(.027,.007,.004),teal,.001,rig)
    for rib in range(7):
        detail=cube('Pilot grip rib',(side*.62,.60,-1.96+rib*.048),(.137,.234,.012),black,.004,rig);detail.rotation_euler[1]=side*.16
# Segmented deck seams and physical illuminated switches catch the rim light.
for side in [-1,1]:
    for j in range(3):
        cube('Fine status separator',(side*(.85+j*.22),1.06,-1.68),(.13,.012,.012),edge,.002,rig)
# Lower hull hides the under-console void and grounds the pilot viewpoint.
cube('Lower flight deck',(0,1.4,-2.18),(4.3,1.1,1.1),hull,.22,rig)
# Central transparent HUD reticle: geometry in space, with no text to localize.
for a0,a1 in [(0,.7),(1.05,1.75),(2.1,2.8),(3.14,3.84),(4.2,4.9),(5.25,5.95)]:
    tube('Holographic reticle',[(.27*math.cos(a),3.4,.27*math.sin(a)) for a in [a0+(a1-a0)*i/12 for i in range(13)]],.0035,teal,rig)
for side in [-1,1]:
    tube('HUD horizon',[(side*.36,3.4,0),(side*.6,3.4,0)],.004,teal,rig)
    tube('HUD side scale',[(side*.66,3.4,-.2),(side*.66,3.4,.2)],.003,teal,rig)
    for j in range(5): tube('HUD measurement',[(side*.66,3.4,-.2+j*.1),(side*.72,3.4,-.2+j*.1)],.0025,teal,rig)
key=light('Deck cool fill',(1.5,.8,1.5),260,(.25,.46,.78),2.4);key.parent=rig;aim(key,(0,2.4,-.9))
key=light('Amber deck bounce',(-1.8,1.6,.4),105,(1,.55,.22),1.5);key.parent=rig;aim(key,(0,2.2,-.9))

# Frame the deck at the bottom of a square master, keeping it visible after
# phone/tablet aspect cropping. The flying scene remains centrally composed.
for ob in list(bpy.data.objects):
    if ob.parent==rig and any(ob.name.startswith(n) for n in ['Curved instrument','Instrument pod','Tactile console','Pilot control','Pilot grip','Thumb trigger','Fine status','Lower flight']):
        ob.location += Vector((0,.8,.82))
    if ob.parent==rig and any(ob.name.startswith(n) for n in ['Forged canopy','Canopy seam']):
        ob.scale.x=.70;ob.scale.z=.70
    if ob.parent==rig and any(ob.name.startswith(n) for n in ['Side pillar','Pillar running','Canopy fastener']):
        ob.scale.x=.72;ob.scale.z=.82

# Dimensional jump corridor: nested machined rings and helical luminous veins.
for k in range(32):
    y=k*5.1
    c=center(y)
    twist=.07*k
    points=[c+Vector((8.2*math.cos(a+twist),0,8.2*math.sin(a+twist))) for a in [i*2*math.pi/96 for i in range(97)]]
    tube('Jump gate rib %02d'%k,points,.085,edge)
    for sector in range(8):
        a0=sector*math.pi/4+twist
        pts=[c+Vector((8.05*math.cos(a),-.05,8.05*math.sin(a))) for a in [a0+.08+i*.57/20 for i in range(21)]]
        tube('Ion ring segment',pts,.025,blue if sector%2 else teal)
    # Brackets add real depth and passing parallax.
    for sector in range(4):
        a=sector*math.pi/2+twist
        cube('Ring power housing',c+Vector((8.4*math.cos(a),0,8.4*math.sin(a))),(.32,.65,.32),hull,.06)
for ly in [15,45,80,115,145]:
    d=bpy.data.lights.new('Ion field bounce','POINT');d.energy=900;d.color=(.18,.40,1);d.shadow_soft_size=3
    ob=bpy.data.objects.new('Ion field bounce',d);bpy.context.collection.objects.link(ob);ob.location=center(ly)+Vector((0,0,3))
for strand in range(4):
    pts=[]
    for j in range(320):
        y=j*.52;a=strand*2*math.pi/4+y*.035;c=center(y)
        pts.append(c+Vector((8.55*math.cos(a),0,8.55*math.sin(a))))
    tube('Helical field conduit',pts,.027,purple if strand%3==0 else blue)
# Starfield, mesh batched for efficient Eevee rendering.
verts=[];faces=[]
for j in range(650):
    a=random.uniform(0,2*math.pi);r=random.uniform(40,400);y=random.uniform(-20,600)
    x=math.cos(a)*r;z=math.sin(a)*r;sz=random.uniform(.045,.20)
    start=len(verts)
    verts.extend([(x-sz,y,z),(x,y-sz,z),(x+sz,y,z),(x,y+sz,z),(x,y,z+sz),(x,y,z-sz)])
    faces.extend([(start+a,start+b,start+c) for a,b,c in [(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)]])
me=bpy.data.meshes.new('Deep sky stars');me.from_pydata(verts,[],faces);me.materials.append(white)
ob=bpy.data.objects.new('Deep sky stars',me);bpy.context.collection.objects.link(ob)

# Ocean, continental shelf, dry land and clouds are separate material systems.
planetmat=material('Distant ocean and land',(.02,.12,.16),.03,.65)
nt=planetmat.node_tree;p=nt.nodes['Principled BSDF']
tex=nt.nodes.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=3.8;tex.inputs['Detail'].default_value=5;tex.inputs['Roughness'].default_value=.68
ramp=nt.nodes.new('ShaderNodeValToRGB'); ramp.color_ramp.interpolation='EASE'
colors=[(.25,(.002,.014,.045,1)),(.46,(.005,.045,.095,1)),(.495,(.012,.14,.17,1)),(.505,(.055,.12,.066,1)),(.60,(.15,.21,.075,1)),(.72,(.35,.30,.18,1)),(.84,(.68,.72,.65,1))]
for element in list(ramp.color_ramp.elements)[1:]:ramp.color_ramp.elements.remove(element)
ramp.color_ramp.elements[0].position=colors[0][0];ramp.color_ramp.elements[0].color=colors[0][1]
for position,color in colors[1:]:ramp.color_ramp.elements.new(position).color=color
nt.links.new(tex.outputs['Fac'],ramp.inputs[0]);nt.links.new(ramp.outputs[0],p.inputs['Base Color'])
rough=nt.nodes.new('ShaderNodeValToRGB');rough.color_ramp.elements[0].position=.49;rough.color_ramp.elements[0].color=(.28,.28,.28,1);rough.color_ramp.elements[1].position=.51;rough.color_ramp.elements[1].color=(.78,.78,.78,1)
nt.links.new(tex.outputs['Fac'],rough.inputs[0]);nt.links.new(rough.outputs[0],p.inputs['Roughness'])
height=nt.nodes.new('ShaderNodeMath');height.operation='SUBTRACT';height.inputs[1].default_value=.5;height.use_clamp=True
nt.links.new(tex.outputs['Fac'],height.inputs[0])
bump=nt.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.24;bump.inputs['Distance'].default_value=.10
nt.links.new(height.outputs[0],bump.inputs['Height']);nt.links.new(bump.outputs['Normal'],p.inputs['Normal'])
planet=sphere('Ocean destination',(9,300,17),39,planetmat,256,128)
planet.rotation_euler[2]=0;planet.keyframe_insert('rotation_euler',frame=1);planet.rotation_euler[2]=.07;planet.keyframe_insert('rotation_euler',frame=180)
# Atmosphere uses angle-based emission so the globe remains correctly shaded.
atmos=bpy.data.materials.new('Atmospheric limb');atmos.use_nodes=True;nt=atmos.node_tree;nt.nodes.clear()
o=nt.nodes.new('ShaderNodeOutputMaterial');mix=nt.nodes.new('ShaderNodeMixShader');tr=nt.nodes.new('ShaderNodeBsdfTransparent');em=nt.nodes.new('ShaderNodeEmission');em.inputs[0].default_value=(.12,.48,1,1);em.inputs[1].default_value=.48
lw=nt.nodes.new('ShaderNodeLayerWeight');r=nt.nodes.new('ShaderNodeValToRGB');r.color_ramp.elements[0].position=.65;r.color_ramp.elements[0].color=(0,0,0,1);r.color_ramp.elements[1].position=.98;r.color_ramp.elements[1].color=(.48,.48,.48,1)
nt.links.new(lw.outputs['Facing'],r.inputs[0]);nt.links.new(r.outputs[0],mix.inputs[0]);nt.links.new(tr.outputs[0],mix.inputs[1]);nt.links.new(em.outputs[0],mix.inputs[2]);nt.links.new(mix.outputs[0],o.inputs[0])
sphere('Blue atmospheric limb',(9,300,17),39.8,atmos,192,96)
# Thin cloud cover casts and catches light above the continental surface.
cloud=bpy.data.materials.new('High cloud deck');cloud.use_nodes=True;nt=cloud.node_tree;nt.nodes.clear()
outcloud=nt.nodes.new('ShaderNodeOutputMaterial'); mixcloud=nt.nodes.new('ShaderNodeMixShader'); transparent=nt.nodes.new('ShaderNodeBsdfTransparent'); diffuse=nt.nodes.new('ShaderNodeBsdfPrincipled');diffuse.inputs['Base Color'].default_value=(.72,.78,.79,1);diffuse.inputs['Roughness'].default_value=1
cloudnoise=nt.nodes.new('ShaderNodeTexNoise');cloudnoise.inputs['Scale'].default_value=8;cloudnoise.inputs['Detail'].default_value=6;cloudnoise.inputs['Roughness'].default_value=.65
cloudmask=nt.nodes.new('ShaderNodeValToRGB');cloudmask.color_ramp.elements[0].position=.59;cloudmask.color_ramp.elements[1].position=.73
nt.links.new(cloudnoise.outputs['Fac'],cloudmask.inputs[0]);nt.links.new(cloudmask.outputs[0],mixcloud.inputs[0]);nt.links.new(transparent.outputs[0],mixcloud.inputs[1]);nt.links.new(diffuse.outputs[0],mixcloud.inputs[2]);nt.links.new(mixcloud.outputs[0],outcloud.inputs[0])
cloudsphere=sphere('High cloud layer',(9,300,17),39.3,cloud,192,96)
cloudsphere.rotation_euler[2]=.2
moonmat=material('Moon basalt',(.28,.31,.38),.1,.8)
sphere('Companion moon',(-47,289,52),7.8,moonmat,128,64)
sun=light('Distant starlight',(-100,180,110),180000,(1,.92,.78),75);aim(sun,(9,300,17))
# Additional bounce ensures the night side still has ocean detail.
sun=light('Planet reflected light',(80,210,-10),9000,(.08,.24,.55),65);aim(sun,(9,300,17))

# Smooth physical camera path: accelerate, bank through the gates, decelerate.
for f in range(1,181):
    t=(f-1)/179
    # Integrated ease gives a deliberate launch and a soft arrival.
    u=t*t*(3-2*t)
    y=-22+u*214
    pos=center(min(y,166))
    if y>166: pos=Vector((center(166).x+(y-166)*.045,y,center(166).z+(y-166)*.06))
    rig.location=pos
    yaw=-.085*math.cos(max(0,y)*.032)*(math.sin(math.pi*t)**1.2)
    pitch=.024*math.sin(t*math.pi*2)
    roll=.085*math.sin(t*math.pi*2)*math.sin(math.pi*t)
    rig.rotation_euler=(pitch,roll,yaw)
    rig.keyframe_insert('location',frame=f);rig.keyframe_insert('rotation_euler',frame=f)

# Instruments report the shot's actual travel instead of static placeholder bars.
def update_instruments(scene, _depsgraph=None):
    # Keep display glyph geometry fixed across motion-blur subframe samples.
    if abs(scene.frame_subframe) > 0.00001: return
    t=max(0,min(1,(scene.frame_current-1)/179))
    y=-22+t*t*(3-2*t)*214
    position=center(min(y,166))
    if y>166: position=Vector((center(166).x+(y-166)*.045,y,center(166).z+(y-166)*.06))
    distance=(planet.location-position).length*.13
    bpy.data.objects['Navigation distance'].data.body=f'{distance:05.1f}'
    bpy.data.objects['Flight velocity'].data.body=f'{round(214*t*(1-t)):03d}'
bpy.app.handlers.frame_change_pre.append(update_instruments)

# Save reusable native scene and render only the deliverable assets.
scene_path=os.path.join('/tmp','glowpath-planet-flight.blend')
bpy.ops.wm.save_as_mainfile(filepath=scene_path)
mesh_polys=sum(len(o.data.polygons) for o in bpy.data.objects if o.type=='MESH')
print('FLIGHT_SCENE',len(bpy.data.objects),'objects',mesh_polys,'base mesh polygons plus bevelled curves')
if mode=='preview':
    s.render.image_settings.file_format='PNG'
    for f in [65,110,170]:
        s.frame_set(f);s.render.filepath=os.path.join('/tmp',f'glowpath-flight-polished-{f}.png');bpy.ops.render.render(write_still=True)
    s.render.image_settings.file_format='JPEG';s.render.image_settings.quality=91
    s.frame_set(170);s.render.filepath=os.path.join('/tmp','glowpath-planet-flight-polished-poster.jpg');bpy.ops.render.render(write_still=True)
else:
    s.render.image_settings.media_type='VIDEO'
    s.render.image_settings.file_format='FFMPEG'
    s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH';s.render.ffmpeg.ffmpeg_preset='GOOD';s.render.ffmpeg.audio_codec='NONE'
    s.render.filepath=os.path.join('/tmp','glowpath-planet-flight-polished.mp4')
    if mode == 'motion-check':
        s.frame_start=110;s.frame_end=117;s.render.filepath='/tmp/glowpath-flight-motion-check.mp4'
    bpy.ops.render.render(animation=True)
    if mode == 'motion-check': sys.exit(0)
    s.render.image_settings.media_type='IMAGE'
    s.render.image_settings.file_format='JPEG';s.render.image_settings.quality=94
    s.frame_set(170);s.render.filepath=os.path.join('/tmp','glowpath-planet-flight-polished-poster.jpg');bpy.ops.render.render(write_still=True)
    os.replace('/tmp/glowpath-planet-flight-polished.mp4',os.path.join(OUTPUT,'planet-flight.mp4'))
    os.replace('/tmp/glowpath-planet-flight-polished-poster.jpg',os.path.join(OUTPUT,'planet-flight-poster.jpg'))
