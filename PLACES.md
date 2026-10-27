# Places

Scenic Route opens on a spread of postcards, one per place in `scripts/places.gd`; tap one and you are there,
standing in one spot, dragging to look all the way round. No buttons, no walking, no goals: only the little
postcard in the corner (to go back) is on screen. Mobile first (portrait 450x800 window, base 720x720,
`canvas_items` stretch with `expand`), and the web.

## What a place is

A place is one script, `scripts/<id>/<id>.gd`, that `extends Node3D` and builds everything in `_ready()`
from code, seeded, so it is the same every visit. `main.gd` loads it, adds it, and adds the camera to it
(`scripts/look.gd`). The script must have:

- `const VIEW := {"look": Vector2(yaw, pitch)}`: where you face on arriving, in degrees. Yaw 0 looks down -Z,
  positive turns left; pitch positive looks up. (Other keys are the place's own business.)
- `static func view_position() -> Vector3`: where your eyes are (about 1.6 m above the floor, or sitting:
  1.2 m).
- built a step at a time: `_ready()` calls `Places.build(self, [steps...])`, and the script declares
  `signal progress(done: float)`, `signal built` and `var is_built := false`. Main shows the place's postcard (the
  loading card) until it is built; anything in `_process` must cope with a place half made (check `is_built`).
- its own `WorldEnvironment` (and any lights). No camera: main adds it (fov 62, near 0.08, far 700).
- optionally `func make_ambience() -> Node`: a node with `start()` that plays the place's sound (main adds it
  and frees it when you leave). Sound made in code, as `scripts/ambience.gd` does (baked `AudioStreamWAV`,
  loops crossfaded, gusts or swells baked in; never change a player's volume every frame: it stutters on the
  web). Keep it gentle: nothing shrill or squeaky (made-up bird whistles were taken out of Amberwood for
  sounding like squeaks).

Put a place's own shaders in `shaders/<id>/` and anything else in `scripts/<id>/`. Shared, don't change for one
place: `main.gd`, `look.gd`, `places.gd`, `shaders/paint.gdshader` (over everything: a warm grade, a painted
plate's dark corners, paper grain).

## The look

Painted, after *Over the Garden Wall* for Amberwood; every place is a painting of its own, not realism. Amberwood
does it by lighting every material by hand (`render_mode unshaded`, a `sun_dir` uniform, a wrap and a rim) with
fog for depth; do the same or use the engine's light, whichever paints better. Big simple shapes, strong light
and shadow, a few accent colours, depth from haze. Things move a little (wind, water, people, lights) so it is
alive while you look.

## Budget

Built in under 2 s on a desktop; about 400k triangles and 200 draw calls at most, looking any way, at 450x800.
`tests/cost.gd -- --place=<id>` prints both. MultiMeshes for anything repeated, in squares if spread wide.

## Checking

```
godot --path . --audio-driver Dummy --resolution 450x800 -s tests/shots.gd -- --out=<folder> --place=<id>
godot --path . --audio-driver Dummy --resolution 450x800 -s tests/cost.gd -- --place=<id>
godot --path . --audio-driver Dummy --resolution 800x450 -s tests/cam.gd -- <out.png> x y z yaw pitch [wait] --place=<id>
```

Always `--audio-driver Dummy`. Godot 4.7.2:
`C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`.
