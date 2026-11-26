# Shepherd (working title)

A pixel-art real-time roguelike made with Godot 4 and GDScript. You are a shepherd leading a flock of
sheep along mountain paths (inspired by transhumance) and protecting them from folklore creatures,
with the help of your dog.

## Status

The flock-guiding prototype is done and judged fun; the game is now growing past it, one small step
at a time. What can be played today is a run of five escort trips in a row, with shearing, a power
and a shop on the pasture between two trips.

- **The flock**: 15 sheep moving as boids, some with a lamb. They follow the shepherd in a column,
  graze and wander at rest, gather into a group when the column stops, step aside from the shepherd,
  steer around the trees, and panic and flee toward the flock when an enemy comes.
  - **Lambs** follow their mother, hop along, and grow into sheep after a few trips.
  - **Rams** (bought in the shop) charge the wolves nearby and butt them, stunning them.
  - **Strays**: a trip may meet a sheep, a lamb or a ewe with her lamb grazing alone on the trail;
    they join the flock when the shepherd or a sheep comes near.
- **The shepherd's crook**: left click lobs a clod of earth at the mouse, along an arc shown by a
  crosshair, landing crosses and a dotted line, with a limited reach and a cooldown. The trees stop
  the clods. Each clod costs an attacking enemy one health (wolf 2, eagle 1): it flinches, then lets
  go of its sheep or gives up once out of health.
- **The dog**: three modes, cycled with Space. *Gather* brings stragglers back, *Rear guard* stays
  behind the flock and chases enemies coming near it, *Hunt* chases any enemy. A bark makes any
  enemy drop the sheep it holds and run off, whatever its health.
- **The trip**: a band walked left to right, from a start pasture to an end pasture, with a forest
  around it, lone trees and groves to steer around; each trip has its own layout. A trip may be
  walked **at night**: the world goes dark but around the shepherd's lantern. The trip ends when
  every remaining sheep stands in the end pasture.
- **Enemies**, sent at attack points along the trail:
  - **Wolves**, in packs: each one comes out of the forest edge beside a straggler, growls, charges,
    then drags the sheep back to the forest. The shepherd frees it by reaching the wolf.
  - **The eagle** (never at night): its shadow crosses the screen, a red sight locks on the most
    isolated sheep on screen, it dives from the top right and carries the sheep off to the left.
    Send the dog under it, or hit it with a clod, before the sheep is gone.
- **The run**: the flock that arrives starts the next trip. Between two trips, on the pasture:
  - the sheep are shorn, 2 wool each, kept for the run;
  - a trip report tells how many sheep arrived, were rescued, and what each enemy took;
  - pick one of three **powers**, on cards: for the crook (Heavy Clod, Extra Clod, Quick Throw,
    Long Throw, Flat Throw, Mudball), the sheep (Swift Hooves, Tight Flock, Hot-Headed, Pregnancy)
    or the dog (Loud Bark, Quick Paws, Keen Eye, Relentless); they add up when taken again;
  - spend wool in the **shop**: a sheep (10), a lamb (5) or a ram (15).

  The run ends after the fifth trip, or when no sheep is left; an end screen gives the result.
- **Pause menu** (Escape): resume, volume settings (saved), restart the run, quit.
- **Sound**: every event and every music context is hooked up, but no sound file is there yet (see
  *Adding sounds*).

Not there yet: other weapons, other enemies, the dog's one-shot orders, the mountain map, bosses,
sound files.

## Running

Open the project in Godot 4.7 (`project.godot`) and press F5, or from the project root:

```
godot --path .
```

Check the scripts without opening the editor: `godot --headless --quit`.

## Controls

| Key | Action |
| --- | --- |
| Arrows / WASD | Move the shepherd |
| Left click | Lob a clod with the crook at the mouse |
| Space | Next dog mode (Gather, Rear guard, Hunt) |
| Mouse | Pick a power, buy in the shop (pasture) |
| Escape | Pause menu |
| R | Start a new run (end screen) |
| F3 | Debug overlay: sheep states and targets, flight zones, shepherd trail |
| Mouse wheel / keypad + and - | Zoom out and in (with F3 on) |
| E / L | Send an eagle / a wolf at once (testing aids) |
| P | Pick any power now, the trip goes on (testing aid) |
| N | Take everyone straight to the end pasture (testing aid) |

## Adding sounds

Drop a file in the right folder under the right name and it plays; a name with no file stays
silent. Effects go in `audio/sfx/<name>.wav` (or `.ogg`, `.mp3`; variants `<name>_1`, `<name>_2`...
are picked at random), music in `audio/music/<name>.ogg` (looped, crossfaded).

- Effects: `throw`, `clod_hit`, `enemy_ko`, `clod_crumble`, `bark`, `wolf_howl`, `wolf_growl`,
  `eagle_cry`, `eagle_dive`, `sheep_alert`, `sheep_caught`, `sheep_lost`, `sheep_freed`, `ram_butt`,
  `stray_join`, `shear`, `puff`, and in the interface `wool`, `banner`, `power_pick`, `buy`,
  `refuse`, `click`
- Music: `trip`, `night`, `attack` (while an enemy is around), `pasture`, `victory`, `defeat`

Balance them in `resources/sound_config.tres` (volume per name, pitch variation, panning).

## Tuning

Every weight and speed is exposed in a resource, editable in the Godot inspector:

- `resources/flock_config.tres` (`FlockConfig`): sheep gaits, following, separation, flight, panic,
  rams, strays; `resources/lamb_config.tres` for the lambs
- `resources/dog.tres` (`DogData`): dog speeds, reach, modes, bark
- `resources/wolf.tres` (`EnemyData`): wolf approach, charge, carry; health on each enemy scene
  (`entities/wolf/wolf.tscn`, `entities/eagle/eagle.tscn`)
- `resources/eagle.tres` (`EagleData`): eagle pass, dive, carry, shadow
- `resources/crook.tres` (`CrookData`): throw cooldown, clod speed, reach and arc; `Shepherd`
  (`entities/shepherd/shepherd.tscn`): walking speed
- `resources/powers/*.tres` (`PowerData`): the powers, each a list of setting changes
- `resources/sound_config.tres` (`SoundConfig`): sound volumes, pitch variation, panning, music fade
- Nodes of `scenes/main/main.tscn`: `Main` (sheep count, lambs), `AttackDirector` (wolves and eagles
  of each attack), `Forest` (trees, shade), `Strays` and `Night` (chance per trip), `Shearing`;
  shop prices on `ui/shop_screen.tscn`

## Project layout

- `art/`: sprite sheets (made in Aseprite), fonts, UI frames
- `audio/`: `sfx/` and `music/`, the sound files (empty for now)
- `entities/`: one folder per entity, scene and script (`sheep` with the lamb and ram scenes,
  `shepherd`, `clod`, `dog`, `wolf`, `eagle`, and `enemy`, the base shared by enemies)
- `scenes/main/`: the trip scene, its ground, forest, camera, attack director, strays, night,
  shearing, debug overlay
- `resources/`: tunable `Resource` scripts and their `.tres` data, powers in `resources/powers/`
- `autoload/`: `RunManager`, the state of the run; `Sound`, sound effects and music
- `effects/`: running dust, ground shadows, clod crumbs, wool fluff, bark ring, stun stars, hit
  stop, shaders (forest shade, night lantern, eagle shadow, enemy tint)
- `ui/`: HUD (dog mode, trip, wool counter), trip banner, crosshair, trip report, power cards,
  pasture and shop screens, end screen, pause menu, theme

`CLAUDE.md` holds the full game design, the art and technical rules and the build order.
