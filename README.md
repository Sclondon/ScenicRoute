# Scenic Route

A scenic place to stand in and look around. No goals, no score, no buttons, no walking: you are there, and you
drag to look about. Godot 4.7 (GL Compatibility), made for phones first and the web.

## Amberwood

The edge of an autumn wood at the golden hour, after *Over the Garden Wall* (the user's reference art is in
`inspirationArt/`). A dirt path runs along the wood's edge. On one side the wood goes deep: dark trunks thick and
thin, old oaks with swirling ropey trunks and gnarled roots over the ground, trees leaning out over the path, groves
of pale aspens with their dark eyes, dead snags, great trees blown down with their roots torn up in a plate of
earth. On the other side the trees give out past a split-rail fence and a pumpkin patch, and the land falls away
into a valley: a stream winding down to a pond, rolling hills of dry grass going back in a patchwork of fields to
a far ridge, a field of corn, copses on the rises. Leaves come down all round; shafts of sun slant through the
trees, each coming and going on its own slow clock.

Things live there: a small herd of deer (a buck, two does and a fawn) comes along the valley now and then,
grazing as it goes; rabbits and a hare nibble and hop on the slope below the patch; a fox trots the valley,
stops to listen, and pounces; blue jays sit in the old oaks; frogs sing round the pond.

You stand on a low rise on the path by the patch. Drag to look (arrow keys work too), all the way round. Left
alone, the view drifts back out over the patch to the valley and breathes a little. The place's name and "Drag to
look around" show once as it fades in, then go.

Sound, all made in code at start-up (`scripts/ambience.gd`): wind in the tops, dry leaves hissing in the gusts,
small birds now and then, a woodpecker far off. The wind and the leaves are baked with their gusts in them, and
no volume is changed while they play: doing that every frame stutters in the web build. The frogs and jays have
their own voices (GameCommon's).

`scripts/tickets.gd` is kept for later, for charging site tickets for a visit; nothing uses it now.

## How it is made

Everything is built from code and seeded (`scripts/amberwood/amberwood.gd`), so it is the same place every visit.
Where you stand is `Amberwood.VIEW`; `scripts/look.gd` is the camera. The land is `Amberwood.height`: the wood's
floor, the fall into the valley from the wood's edge (steep at the top, so you see down into it from the rise you
stand on), the hills, then the pond and the stream cut into it (`POND`, `STREAM`).

The look comes from painting rather than lighting: nearly every material is `unshaded` and lights itself by hand
from `Amberwood.SUN_DIR`, and warm fog does the depth. The DirectionalLight is there for the fog's glow towards
the sun, and for the grass and the animals, the only things the engine lights. Over it all,
`shaders/paint.gdshader` warms the shadows, darkens the corners like a painted plate and adds paper grain.

| Piece | How |
| --- | --- |
| Trees | `tree_builder.gd` makes a tree from a shape (`Amberwood.KINDS`: oak, tall, leaner, aspen, snag): trunk girth, lean (curving back up to the light), twist and flute (ropes that spiral up the trunk, deepest at the foot), flare, roots snaking over the ground, branches that swirl in S-curves. Each kind has a few variants, each built twice from one seed: in full near where you stand, and plainer (fewer rings and sides, no roots or twigs) further off. Three old oaks are made one-off by the path. MultiMeshes in 40 m squares, so trees off screen are not drawn. |
| Bark | `bark.gdshader`: plates cut by furrows that follow the trunk's twist, drawn the same size on every tree (the girth is in the mesh); aspens are pale with dark eyes and brows, lenticels, black bands and a black, cracked foot |
| Leaves on trees | `foliage.gdshader`: camera-facing cards, each a clump of pointed leaves at their own slants, lit on the sun side and glowing when the sun is behind it |
| Bushes | close by, real ones (`bush_builder.gd`, `leaf3d.gdshader`): bronze, ember, bracken, dark and holly, every leaf its own card cut to its kind's shape; further off, painted clumps (`foliage.gdshader`) |
| Grass | GameCommon's grass (as Warren has it, `scripts/grass.gd`) over the open ground and along the path, in autumn colours |
| Corn | Warren's corn stalks (`corn_builder.gd`), swayed by `corn.gdshader` |
| Ground | one mesh following the path, its vertex colours marking wet ground, the corn's soil and how open it is; `ground.gdshader` draws the path (its line must match `Amberwood.path_x`), leaf litter, meadow, the far fields' patchwork and the drifting sun patches |
| Water | `water.gdshader`: the pond (ripples, rings where something touched it, the sun glittering) and the stream (ripples running down it) |
| Sky | `sky.gdshader`: gold low by the sun to grey-blue overhead, long cloud streaks |
| Leaves on the ground and falling | `leaf.gdshader`: oak, maple and plain leaves; falling ones swing and tumble down in the vertex shader and start again, many round where you stand |
| Sun shafts | `shaft.gdshader`, two crossed additive cards each, each coming and going over half a minute or so |
| Pumpkins, fence, stones, fallen trees | built in code, `prop.gdshader`, `bark.gdshader` |
| Animals | `wildlife.gd`, with GameCommon's deer (and elk, which its rig needs), rabbit, fox (and dog), crow and blue jay, frog and pond frog, installed with `sh kit.sh install godot/<name> <this folder>` |

## Checking it

```
godot --path . --audio-driver Dummy --resolution 450x800 -s tests/shots.gd -- --out=<folder>
```

saves the view, then round to the left, behind and the right. `tests/cam.gd` saves one picture from anywhere
(see its header). `tests/smoke.gd` plays it with simulated touches (no buttons, a drag turns the view, a drag with
no finger-down, you stay put) and ends PASSED or FAILED. `tests/cost.gd` prints the start-up time and the
triangles and draw calls looking four ways (about 300-380k and 100-190 on a desktop, 2026-10-26).
`tests/attract.gd` plays the arcade preview film (see its header for recording it).

## Building

Export the **Web** preset to `build/` (`godot --headless --path . --export-release "Web" build/index.html`).
