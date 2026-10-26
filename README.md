# Scenic Route

A scenic place to stand in and look around. No goals, no score, no buttons, no walking: you are there, and you
drag to look about. Godot 4.7 (GL Compatibility), made for phones first and the web.

## Amberwood

An autumn wood at the golden hour, after *Over the Garden Wall*. A pale dirt path wanders off
between dark trunks into a haze of sun; the crowns meet over it in gold, orange and rust; leaves come down;
shafts of sun slant across the path and patches of light drift over the ground as the wind moves the tops.
You stand at a split-rail fence round a pumpkin patch gone to vine; back the way the path came is a fallen log.

Drag to look (arrow keys work too), all the way round. Left alone, the view drifts back to the patch and
breathes a little. The place's name and "Drag to look around" show once as it fades in, then go.

Sound, all made in code at start-up (`scripts/ambience.gd`): wind in the tops, dry leaves hissing in the gusts,
small birds now and then, a woodpecker far off. The wind and the leaves are baked with their gusts in them, and
no volume is changed while they play: doing that every frame stutters in the web build.

`scripts/tickets.gd` is kept for later, for charging site tickets for a visit; nothing uses it now.

## How it is made

Everything is built from code and seeded (`scripts/amberwood/amberwood.gd`), so it is the same wood every visit.
Where you stand is `Amberwood.VIEW`; `scripts/look.gd` is the camera.
The look comes from painting rather than lighting: every material is `unshaded` and lights itself by hand from
`Amberwood.SUN_DIR` (the DirectionalLight is only there for the fog's glow towards the sun), and warm exponential
fog does the depth. Over it all, `shaders/paint.gdshader` warms the shadows, darkens the corners like a painted
plate and adds paper grain.

| Piece | How |
| --- | --- |
| Trees | `tree_builder.gd` makes 12 trunk shapes (3 birch) with branches reaching towards +X; each tree is turned so they reach over the path. A MultiMesh per shape. |
| Leaves on trees | `foliage.gdshader`: camera-facing cards, one MultiMesh for the whole wood. Each card is a clump of pointed leaves at their own slants, with a dark middle, lit on the sun side and glowing when the sun is behind it. |
| Undergrowth | the same shader, darker (bushes), and in `blades` mode for dry grass at the path's edges |
| Ground | one mesh following the path; `ground.gdshader` draws the dirt path (its line must match `Amberwood.path_x`), leaf litter in dabs and the drifting sun patches |
| Leaves on the ground and falling | `leaf.gdshader`: oak, maple and plain leaves; falling ones swing and tumble down in the vertex shader and start again |
| Sun shafts | `shaft.gdshader`, two crossed additive cards each, fading out when you are close |
| The light at the end | `glow.gdshader`, a big additive glow card past the end of the path |
| Pumpkins, fence, stones | built in code, `prop.gdshader` |

## Checking it

```
godot --path . --audio-driver Dummy --resolution 450x800 -s tests/shots.gd -- --out=<folder>
```

saves the view, then round to the left, behind and the right. `tests/smoke.gd` plays it with simulated touches
(no buttons, a drag turns the view, a drag with no finger-down, you stay put) and ends PASSED or FAILED.
`tests/attract.gd` plays the arcade preview film (see its header for recording it).

## Building

Export the **Web** preset to `build/` (`godot --headless --path . --export-release "Web" build/index.html`).
