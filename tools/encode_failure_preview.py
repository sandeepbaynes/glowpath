"""Encode actual Flutter capture frames with Blender's bundled video encoder.

Run after tools/render_failure_preview_test.dart:
Blender -b --factory-startup --python tools/encode_failure_preview.py
This is a review artifact; it is never bundled as the game's animation.
"""
from pathlib import Path
import bpy

root = Path(__file__).resolve().parent.parent
frames = sorted((root / "build/review/failure-0.7.3-frames").glob("*.png"))
if not frames:
    raise RuntimeError("Capture Flutter frames first")

scene = bpy.context.scene
editor = scene.sequence_editor_create()
strip = editor.strips.new_image("Actual game animation", str(frames[0]), 1, 1)
for frame in frames[1:]:
    strip.elements.append(frame.name)
scene.frame_start = 1
scene.frame_end = len(frames)
scene.render.fps = 30
scene.render.resolution_x = 780
scene.render.resolution_y = 1688
scene.render.resolution_percentage = 100
scene.render.use_sequencer = True
scene.view_settings.view_transform = "Standard"
scene.render.image_settings.media_type = "VIDEO"
scene.render.image_settings.file_format = "FFMPEG"
scene.render.ffmpeg.format = "MPEG4"
scene.render.ffmpeg.codec = "H264"
scene.render.ffmpeg.constant_rate_factor = "HIGH"
scene.render.ffmpeg.ffmpeg_preset = "GOOD"
scene.render.filepath = str(root / "docs/screenshots/signal-lost-0.7.3.mp4")
bpy.ops.render.render(animation=True)
