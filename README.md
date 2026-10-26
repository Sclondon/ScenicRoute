# Scenic Route

A scenic place to stand in and look around. No goals, no score, no buttons, no walking: you are there, and you
drag to look about. Godot 4.7 (GL Compatibility), made for phones first and the web.

## Amberwood

An autumn wood at the golden hour, after *Over the Garden Wall* (the user's reference art is in
`inspirationArt/`). A dirt path wanders off between the trees into a haze of sun going down. The wood is all round: dark trunks thick and
thin, old oaks with swirling ropey trunks and gnarled roots over the ground, trees leaning out over the path, groves
of pale aspens with their dark eyes, dead snags, great trees blown down with their roots torn up in a plate of
earth. In one place, past a split-rail fence and a pumpkin patch, the trees give out and the land falls away into a
valley (the gap, `Amberwood.gap_at`): a stream winding down to a pond, rolling hills of dry grass going back in a patchwork of fields to
a far ridge, a field of corn, copses on the rises. Leaves come down all round; shafts of sun slant through the
trees, each coming and going on its own slow clock.

Things live there: a small herd of deer (a buck, two does and a fawn) comes along the valley now and then,
grazing as it goes; rabbits and a hare nibble and hop on the slope below the patch; a fox trots the valley,
stops to listen, and pounces; blue jays sit in the old oaks; frogs sing round the pond.

You stand on a low rise on the path by the patch, the sun going down the path ahead and the valley off to the
left. Drag to look (arrow keys work too), all the way round. Left
alone, the view drifts back to that and breathes a little. The place's name and "Drag to
look around" show once as it fades in, then go.

Sound, all made in code at start-up (`scripts/ambience.gd`): wind in the tops, dry leaves hissing in the gusts,
a woodpecker far off. The wind and the leaves are baked with their gusts in them, and
no volume is changed while they play: doing that every frame stutters in the web build. The frogs and jays have
their own voices (GameCommon's). (Made-up small birds, pure whistles, were taken out: they only squeaked.)

`scripts/tickets.gd` is kept for later, for charging site tickets for a visit; nothing uses it now.

## The Velvet Moth

A night club, late, the floor still full (`scripts/velvet_moth/`, `shaders/velvet_moth/`). You stand at the brass
rail of a low mezzanine looking down over the dance floor to the DJ's booth, under a great neon moth that beats
its wings every two beats. The floor's glass tiles pulse to the beat in a pattern that changes every four bars
(checker, rings going out, tiles at random, sweeping stripes); beams from the truss and the stage sweep through
the haze; a mirror ball throws its specks round the walls, ceiling and people; speaker cones kick. The crowd is a
few hundred dark figures with coloured rims, lit from under by the tile each stands on, every one dancing its own
way (bouncing, a fist pumping, hands in the air, more of them as the night swells), danced in the vertex shader
on MultiMeshes. Behind you is the bar: a lit wall of bottles, lamps hanging over a buttoned velvet counter, the
club's name in neon script, a bartender and people leaning on it. To the sides, velvet booths up here and down by
the floor, little lamps on the tables, people round tall tables, smaller neon moths on the walls.

Everything moves to one beat, 122 BPM, handed to every shader each frame as `beat`; it is kept on the music's own
clock (`ClubSound.beat()`), so the lights land on the kick. All painted by hand, no engine lights:
`club.gdshaderinc` holds the beat, the floor's colours and `club_light` (a deep violet dark, the floor's glow
thrown up on everything near it, magenta and teal washes from the stage's sides, the warm bar), which every
material paints itself by; violet fog is the haze and the engine's glow is the neon. The room is built in code
(`geo.gd`) into one mesh per material, so it is about 25 draw calls any way you look.

Sound (`club_sound.gd`), all made in code at start-up: a house groove (four-on-the-floor kick, offbeat hats, a
clap on two and four, a rolling bassline and a soft chord stab over Am7, Fmaj7, Cmaj7, G), muffled as if heard
from up on the mezzanine through the room, as one 8-bar loop that wraps round without a seam; and a crowd's
murmur under it. Nothing's volume changes while they play.

## The Plumeria Beach Club

A Hawaiian beach club as the sun goes down (`scripts/plumeria/plumeria.gd`, id `plumeria`). You sit at the rail
of its open-air deck, a mai tai with a paper umbrella and a plumeria lei on the ledge in front of you, looking down
a path of tiki torches to the sea. The sun sits just over the water with bars of cloud across it, its road of
glitter coming over the sea to you. Long swells roll in, turn green-gold where the sun shines through their faces,
break into white water and wash up the wet sand (which mirrors the sky), then slide back. A palm leans out over the
beach; string lights sag between bamboo poles over you and back to the thatched A-frame tiki bar behind (shelves
of bottles, glass fishing floats glowing in their nets, carved tikis, the club's name on a board). Loungers and
furled umbrellas, an outrigger canoe on the sand, a surfboard rack, a lifeguard tower, plumeria trees and hibiscus
in planters, cottages back among the palms. A couple walks the water's edge, someone stands in the shallows, a
catamaran sails under the sun, frigatebirds wheel overhead; green fluted mountains rise inland and a worn crater
headland lies across the bay, all in the evening haze.

It is painted like Amberwood: every material is `unshaded` and lights itself off one low sun, and
`shaders/plumeria/common.gdshaderinc` holds that sun, the sky's colour in any direction (the sky, the sea's
reflections and the haze on far things all use it, so they agree) and the surf's clock. The ground and the sea are
grids laid along the curving shore (`Plumeria.shore_z`); the surf is shaped in the sea's vertex shader and the wash
drawn in the land's. Props are built from code into a few merged meshes (`mesh_kit.gd`), palms by
`palm_builder.gd` (two meshes for the near ones, two plainer for the far), the little lights as one MultiMesh,
the torches GameCommon's fire (`scripts/fire.gd`, lights off). Shadows are long soft quads laid on the sand.

Sound (`scripts/plumeria/sound.gd`), baked at start-up: the surf on a 24 s round of three waves (a crash, white
water rolling in, the wash, a fizzing draw-back) whose start is handed to the sea and sand shaders so each crash is
heard as it is seen; palms rustling; a soft torch crackle; and now and then a few strummed ukulele chords
(Karplus-Strong). No volume is changed while they play. About 245k triangles and 30 draw calls any way you look,
built in about 1.3 s (2026-10-26).

## How it is made

Everything is built from code and seeded (`scripts/amberwood/amberwood.gd`), so it is the same place every visit.
Where you stand is `Amberwood.VIEW`; `scripts/look.gd` is the camera. The land is `Amberwood.height`: the wood's
floor, the fall into the valley through the gap (steep at the top, so you see down into it from the rise you
stand on), the hills, then the pond and the stream cut into it (`POND`, `STREAM`).

The look comes from painting rather than lighting: nearly every material is `unshaded` and lights itself by hand
from `Amberwood.SUN_DIR`, and warm fog does the depth. The DirectionalLight is there for the fog's glow towards
the sun, and for the grass and the animals, the only things the engine lights. Over it all,
`shaders/paint.gdshader` warms the shadows, darkens the corners like a painted plate and adds paper grain.

The wood's own pieces live in `woodland/` (`Woodland`, `woodland/woodland.gd`): GameCommon's `painted-woodland`
component, made here. Change them here, then `sh kit.sh pull godot/painted-woodland <this folder>` from GameCommon.

| Piece | How |
| --- | --- |
| Trees | `woodland/tree_builder.gd` makes a tree from a shape (`Woodland.KINDS`: oak, tall, leaner, aspen, snag): trunk girth, lean (curving back up to the light), twist and flute (ropes that spiral up the trunk, deepest at the foot), flare, roots snaking over the ground, branches that swirl in S-curves. Each kind has a few variants, each built twice from one seed: in full near where you stand, and plainer (fewer rings and sides, no roots or twigs) further off. Three old oaks are made one-off by the path. MultiMeshes in 40 m squares, so trees off screen are not drawn. |
| Bark | `bark.gdshader`: plates cut by furrows that follow the trunk's twist, drawn the same size on every tree (the girth is in the mesh); aspens are pale with dark eyes and brows, lenticels, black bands and a black, cracked foot |
| Leaves on trees | `woodland/shaders/foliage.gdshader`, cut from real leaves (`woodland/leaf_atlas.gd`: oak, sugar maple, beech, aspen, birch, drawn as SVG at start-up): camera-facing cards, each a clump of leaves of the tree's own shape (beech, oak, maple or aspen) at their own slants, ragged with strays, twigs in the gaps, lit on the sun side and glowing when the sun is behind it; each card set a step nearer or further so crossing cards do not flicker, and shrunk away right by the camera |
| Bushes | close by, real ones (`bush_builder.gd`, `leaf3d.gdshader`): bronze, ember, bracken, dark and holly, a few clumps standing on the ground with stems up into them, every leaf its own card cut to its kind's shape; further off, painted clumps (`foliage.gdshader`) |
| Grass | GameCommon's grass (as Warren has it, `scripts/grass.gd`) over the open ground and along the path, in autumn colours |
| Corn | Warren's corn stalks (`corn_builder.gd`), swayed by `corn.gdshader` |
| Ground | one mesh following the path, its vertex colours marking wet ground, the corn's soil and how open it is; `ground.gdshader` draws the path (its line must match `Amberwood.path_x`), leaf litter, meadow, the far fields' patchwork and the drifting sun patches |
| Water | the pond is GameCommon's `water` (`scripts/water.gd`, `self_lit` so it sits in the painted light); the stream is the kit's `woodland/shaders/stream.gdshader` (ripples running down it) |
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
triangles and draw calls looking four ways (about 320-430k and 95-195 on a desktop, 2026-10-26).
`tests/attract.gd` plays the arcade preview film (see its header for recording it).

## Building

Export the **Web** preset to `build/` (`godot --headless --path . --export-release "Web" build/index.html`).
