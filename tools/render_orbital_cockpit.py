"""Transparent physical cockpit for the live destination-aware Flutter flight.
Blender -b --factory-startup --python tools/render_orbital_cockpit.py
Reuses only original flight-deck geometry; no baked planet or star background.
"""
import os
source=os.path.join(os.path.dirname(__file__),'render_planet_flight.py')
with open(source) as f: setup=f.read().split('# Dimensional jump corridor:')[0]
exec(compile(setup,source,'exec'))
s.render.resolution_x=1440;s.render.resolution_y=1440
s.render.film_transparent=True;s.render.use_compositing=False;s.render.use_motion_blur=False
s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.compression=90
# Restrained silver, ice-cyan and ivory share the game's exact visual family.
for matname,color,strength in [('Navigation phosphor',(.32,.62,.65),.7),('Amber instruments',(.72,.58,.34),.65)]:
 p=bpy.data.materials[matname].node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*color,1);p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=strength
bpy.data.lights['Amber deck bounce'].color=(1,.87,.68);bpy.data.lights['Amber deck bounce'].energy=95
bpy.data.lights['Deck cool fill'].color=(.46,.62,.74);bpy.data.lights['Deck cool fill'].energy=200
for ob in bpy.data.objects:
 if ob.name.startswith(('HUD','Holographic')):ob.hide_render=True
 if ob.type=='FONT':
  if ob.name.startswith(('Flight velocity','Flight unit','Flight attitude','Navigation distance','Navigation range','Guidance confidence','Core value')):ob.hide_render=True
  if ob.name=='Navigation label':ob.data.body='NAV / LINK'
  if ob.name=='Flight label':ob.data.body='FLIGHT / VECTOR'
  if ob.name=='Guidance state':ob.data.body='GUIDE'
  if ob.name=='Guidance locked':ob.data.body='ACTIVE'
# Remove the earlier three display boxes and heavy grips. One low panoramic
# glass surface leaves the window and destination in control of the composition.
def under_pod(ob):
 while ob.parent:
  if ob.parent.name.startswith('Instrument pod'):return True
  ob=ob.parent
 return False
for ob in list(bpy.data.objects):
 if under_pod(ob) or ob.name.startswith(('Instrument pod','Curved instrument','Pilot control','Pilot grip','Thumb trigger','Tactile console','Fine status','Lower flight')):ob.hide_render=True
 if ob.name.startswith(('Forged canopy','Canopy seam')):ob.data.bevel_depth*=.58
# Ceramic prow and a single continuous inset glass instrument.
cube('Observatory deck',(0,2.6,-1.86),(5.2,1.1,.65),hull,.18,rig)
cube('Continuous instrument lip',(0,2.35,-1.51),(4.3,.16,.30),edge,.07,rig)
cube('Panoramic instrument glass',(0,2.25,-1.49),(4.15,.06,.235),black,.055,rig)
for side in [-1,1]:
 tube('Glass fine edge',[(side*.18,2.208,-1.40),(side*1.4,2.208,-1.40),(side*1.94,2.208,-1.44)],.0025,teal,rig)
 for i in range(12):
  x=side*(.26+i*.135);height=.020 if i%3 else .035
  tube('Instrument calibration',[(x,2.205,-1.51),(x,2.205,-1.51+height)],.002,edge,rig)
 tube('Instrument active channel',[(side*.4,2.203,-1.55),(side*1.1,2.203,-1.55)],.003,gold if side<0 else teal,rig)
# Small central route lock; imagery, not baked destination text.
for radius in [.065,.085]:
 tube('Central vector ring',[(math.cos(a)*radius,2.2,-1.49+math.sin(a)*radius) for a in [i*math.tau/64 for i in range(65)]],.002,teal,rig)
tube('Navigation bearing',[(-.04,2.194,-1.53),(0,2.194,-1.46),(.04,2.194,-1.53)],.003,gold,rig)
s.render.filepath=os.path.join(ROOT,'assets','worlds','cockpit-foreground.png');bpy.ops.render.render(write_still=True)
print('COCKPIT READY: original 3D foreground, transparent world opening, no baked destination')
