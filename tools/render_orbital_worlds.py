"""Original atmospheric planet turntables. Blender 5.2 EEVEE; no downloaded assets.
Blender -b --factory-startup --python tools/render_orbital_worlds.py
Twelve lit surface orientations cross-fade at runtime; the light stays fixed.
"""
import bpy, math, os, sys
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT=os.path.join(ROOT,'assets','worlds'); os.makedirs(OUT,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=96
s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100
s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
s.render.image_settings.color_depth='8';s.render.image_settings.compression=85
s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.025,.04,.065,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.16
s.view_settings.view_transform='AgX'
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(0,-6,1.8));cam=bpy.context.object;aim(cam,(0,0,0));cam.data.type='ORTHO';s.camera=cam
for name,loc,energy,col,size in [('Sun',(-3,-4,4),390,(1,.91,.78),1.8),('Space bounce',(2,-1,0),12,(.34,.5,.74),4)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.color=col;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.location=loc;aim(o,(0,0,0))
def mat(name):
 m=bpy.data.materials.new(name);m.use_nodes=True;nt=m.node_tree;p=nt.nodes['Principled BSDF'];p.inputs['Roughness'].default_value=.8;return m,nt,p
def sphere(name,r,m):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=128,ring_count=96,radius=r);o=bpy.context.object;o.name=name;o.data.materials.append(m)
 for f in o.data.polygons:f.use_smooth=True
 return o
def ramp(nt,src,points):
 r=nt.nodes.new('ShaderNodeValToRGB');r.color_ramp.elements.remove(r.color_ramp.elements[1])
 for i,(pos,col) in enumerate(points):
  e=r.color_ramp.elements[0] if i==0 else r.color_ramp.elements.new(pos);e.position=pos;e.color=(*col,1)
 nt.links.new(src,r.inputs[0]);return r.outputs['Color']
def noise(nt,scale,detail=5,rough=.7):
 n=nt.nodes.new('ShaderNodeTexNoise');n.inputs['Scale'].default_value=scale;n.inputs['Detail'].default_value=detail;n.inputs['Roughness'].default_value=rough;return n
for kind in range(4):
 objects=[];m,nt,p=mat(['Glacial regolith','Basalt highlands','Ocean shelves','Cloud bands'][kind]);n=noise(nt,[6,5,3.2,4][kind]);n.inputs['Distortion'].default_value=.6
 colors=[[(.18,(.08,.13,.15)),(.42,(.20,.27,.28)),(.58,(.36,.43,.42)),(.78,(.56,.59,.55))],[(.2,(.035,.022,.018)),(.45,(.11,.065,.042)),(.62,(.21,.135,.088)),(.8,(.35,.28,.21))],[(.28,(.005,.025,.05)),(.45,(.01,.055,.085)),(.50,(.025,.11,.13)),(.535,(.13,.18,.13)),(.64,(.24,.27,.19)),(.8,(.5,.51,.42))]][kind] if kind<3 else None
 if kind==3:
  wave=nt.nodes.new('ShaderNodeTexWave');wave.wave_type='BANDS';wave.bands_direction='Z';wave.inputs['Scale'].default_value=4.5;wave.inputs['Distortion'].default_value=7;wave.inputs['Detail'].default_value=5;wave.inputs['Detail Scale'].default_value=2;col=ramp(nt,wave.outputs['Fac'],[(0,(.20,.17,.13)),(.28,(.27,.235,.18)),(.65,(.34,.305,.25)),(1,(.39,.35,.29))]);nt.links.new(col,p.inputs['Base Color'])
 else:nt.links.new(ramp(nt,n.outputs['Fac'],colors),p.inputs['Base Color'])
 micro=noise(nt,95,3);bump=nt.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.25 if kind<2 else .08;bump.inputs['Distance'].default_value=.045 if kind<2 else .01;nt.links.new(micro.outputs['Fac'],bump.inputs['Height']);nt.links.new(bump.outputs[0],p.inputs['Normal'])
 if kind==0:
  cr=nt.nodes.new('ShaderNodeTexVoronoi');cr.inputs['Scale'].default_value=9;crater=ramp(nt,cr.outputs['Distance'],[(0,(.35,.35,.35)),(.22,(.30,.30,.30)),(.31,(.64,.64,.64)),(.37,(.5,.5,.5)),(1,(.5,.5,.5))]);cb=nt.nodes.new('ShaderNodeBump');cb.inputs['Strength'].default_value=.5;cb.inputs['Distance'].default_value=.055;nt.links.new(crater,cb.inputs['Height']);nt.links.new(bump.outputs[0],cb.inputs['Normal']);nt.links.new(cb.outputs[0],p.inputs['Normal'])
 if kind==2:p.inputs['Roughness'].default_value=.39;p.inputs['Metallic'].default_value=.10
 planet=sphere('World',1,m);objects.append(planet)
 if kind==2:
  cm,cnt,cp=mat('Fine cloud layer');cloud=noise(cnt,8,6);alpha=ramp(cnt,cloud.outputs['Fac'],[(.51,(0,0,0)),(.66,(.36,.36,.36)),(.83,(.65,.65,.65))]);cnt.links.new(alpha,cp.inputs['Alpha']);cp.inputs['Base Color'].default_value=(.65,.71,.72,1);cp.inputs['Roughness'].default_value=1;cm.surface_render_method='DITHERED';cloudbody=sphere('Clouds',1.008,cm);objects.append(cloudbody)
 if kind==3:
  # Thousands of fine concentric ice grains, with clear ring divisions.
  rm,rnt,rp=mat('Ring dust');tex=rnt.nodes.new('ShaderNodeTexCoord');vec=rnt.nodes.new('ShaderNodeVectorMath');vec.operation='LENGTH';rnt.links.new(tex.outputs['Object'],vec.inputs[0]);mul=rnt.nodes.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=230;rnt.links.new(vec.outputs['Value'],mul.inputs[0]);sin=rnt.nodes.new('ShaderNodeMath');sin.operation='SINE';rnt.links.new(mul.outputs[0],sin.inputs[0]);rnt.links.new(ramp(rnt,sin.outputs[0],[(-1,(.07,.065,.06)),(.4,(.27,.25,.21)),(1,(.55,.51,.42))]),rp.inputs['Base Color']);rp.inputs['Roughness'].default_value=.9
  for inner,outer in [(1.2,1.4),(1.45,1.66)]:
   verts=[];faces=[]
   for i in range(257):
    a=i*math.tau/256;verts.extend([(math.cos(a)*inner,math.sin(a)*inner,0),(math.cos(a)*outer,math.sin(a)*outer,0)])
   for i in range(256):faces.append((i*2,i*2+1,i*2+3,i*2+2))
   mesh=bpy.data.meshes.new('Ring');mesh.from_pydata(verts,[],faces);o=bpy.data.objects.new('Ice ring',mesh);bpy.context.collection.objects.link(o);o.data.materials.append(rm);objects.append(o)
 cam.data.ortho_scale=3.55 if kind==3 else 2.12
 for frame in range(12):
  for o in objects:
   if o.name.startswith(('World','Cloud')):o.rotation_euler.z=frame*math.tau/12
  s.render.filepath=os.path.join(OUT,f'world-{kind}-{frame:02}.png');bpy.ops.render.render(write_still=True)
 for o in objects:bpy.data.objects.remove(o,do_unlink=True)
print('ORBITAL WORLDS READY 48 original 640px RGBA frames')
