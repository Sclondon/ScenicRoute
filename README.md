# Scenic Route

A lounge on the line out of Wayside Station: pay a few tickets at the window and go and sit somewhere beautiful
for as long as you like. No goals, no score. Godot 4.7 (GL Compatibility), made for phones first and the web.

## The ticket window

You start at the window, with the place you are buying a ticket to drifting behind it. The ticket shows the
place, a line about it and the fare. **Punch ticket** punches a hole in it and the window lifts, and you are
standing there. **Leave** brings you back to the window.

Tickets are the site's coins (the counter at Wayside Station calls them tickets). The site has no route yet for
a game to spend them, so every ride is on a **preview pass** for now: the fare is shown and nothing is taken
(`scripts/tickets.gd`, `Tickets.preview`). `Tickets.admit(place, fare)` is the one place that changes when the
server can charge.

## Amberwood

The first stop: an autumn wood at the golden hour, after *Over the Garden Wall*. A pale dirt path wanders off
between dark trunks into a haze of sun; the crowns meet over it in gold, orange and rust; leaves come down;
shafts of sun slant across the path and patches of light drift over the ground as the wind moves the tops.

You stand at one of four spots and drag to look about (arrow keys work too). **On** and **Back** stroll you
along the path to the next spot, with leaves crunching underfoot:

1. **The way in**, looking down the path into the light
2. **The fallen log**, sitting on a felled trunk beside the path
3. **The pumpkin fence**, by a split-rail fence round a pumpkin patch gone to vine
4. **Where the light gets in**, near the bright end of the path

Left alone, the view drifts back to the spot's own view and breathes a little.

Sound, all made in code at start-up (`scripts/ambience.gd`): wind in the tops, dry leaves hissing in the gusts,
small birds now and then, a woodpecker far off, footsteps in leaves.

## How it is made

Everything is built from code and seeded (`scripts/amberwood/amberwood.gd`), so it is the same wood every visit.
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

saves the window, each spot, the view back the way you came, and a stroll from the first spot to the second.
`tests/smoke.gd` plays it with simulated touches (punch, drag, a drag with no finger-down, stroll, leave) and ends
PASSED or FAILED. `tests/attract.gd` plays the arcade preview film (see its header for recording it).

## Building

Export the **Web** preset to `build/` (`godot --headless --path . --export-release "Web" build/index.html`).
