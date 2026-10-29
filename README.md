# Shepherd (working title)

A pixel-art real-time roguelike made with Godot 4 and GDScript. You are a shepherd leading a flock of
sheep along mountain paths (inspired by transhumance) and protecting them from folklore creatures,
with the help of your dog.

## Status

The flock-guiding prototype is done and judged fun; the game is now growing past it, one small step
at a time. What can be played today is a short run: three escort trips in a row, with an upgrade chosen
between two trips.

- **The flock**: 40 sheep moving as boids. They follow the shepherd in a column, graze and wander at
  rest, gather into a group when the column stops, step aside from the shepherd, and panic and
  flee toward the flock when an enemy comes.
- **The shepherd's crook**: left click lobs a clod of earth at the mouse; its shadow shows how high
  it flies, with a limited reach and a cooldown. Each clod costs an attacking enemy one health
  (wolf 2, eagle 1): it flinches, then lets go of its sheep or gives up once out of health.
- **The dog**: three modes, cycled with Space. *Gather* brings stragglers back, *Rear guard* stays
  behind the flock and chases enemies coming near it, *Hunt* chases any enemy. A bark makes any
  enemy drop the sheep it holds and run off, whatever its health.
- **The trip**: a band walked left to right, from a start pasture to an end pasture, with a forest
  around it, lone trees and groves to steer around. The trip ends when every remaining sheep stands
  in the end pasture; an end screen gives the result.
- **The run**: the flock that arrives starts the next trip. Between two trips, on the pasture, pick
  one of three upgrades for the crook (Heavy Clod, Extra Clod, Quick Throw, Long Throw); they add
  up when taken again. The run ends after the third trip, or when no sheep is left.
- **Enemies**, sent at attack points along the trail:
  - **Wolves**, in packs: each one comes out of the forest edge beside a straggler, howls, charges,
    then drags the sheep back to the forest. The shepherd frees it by reaching the wolf.
  - **The eagle**: its shadow crosses the screen, a red sight locks on the most isolated sheep on
    screen, it dives from the top right and carries the sheep off to the left. Send the dog under
    it, or hit it with a clod, before the sheep is gone.

Not there yet: other weapons, other enemies, other upgrades, wool, shop, map, menus, sound.

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
| Mouse | Pick an upgrade (pasture screen) |
| R | Start a new run (end screen) |
| F3 | Debug overlay: sheep states and targets, flight zones, shepherd trail |
| Mouse wheel / keypad + and - | Zoom out and in (with F3 on) |
| E / L | Send an eagle / a wolf at once (testing aids) |

## Tuning

Every weight and speed is exposed in a resource, editable in the Godot inspector:

- `resources/flock_config.tres` (`FlockConfig`): sheep gaits, following, separation, flight, panic
- `resources/dog.tres` (`DogData`): dog speeds, reach, modes
- `resources/wolf.tres` (`EnemyData`): wolf approach, charge, carry; health on each enemy scene
  (`entities/wolf/wolf.tscn`, `entities/eagle/eagle.tscn`)
- `resources/eagle.tres` (`EagleData`): eagle pass, dive, carry, shadow
- `resources/crook.tres` (`CrookData`): throw cooldown, clod speed, reach and arc; `Shepherd`
  (`entities/shepherd/shepherd.tscn`): walking speed
- `resources/powers/*.tres` (`PowerData`): the upgrades, each a list of setting changes
- `AttackDirector` node in `scenes/main/main.tscn`: wolves and eagles of each attack

## Project layout

- `art/`: sprite sheets (made in Aseprite)
- `entities/`: one folder per entity, scene and script (`sheep`, `shepherd`, `clod`, `dog`, `wolf`,
  `eagle`, and `enemy`, the base shared by enemies)
- `scenes/main/`: the trip scene, its ground, forest, camera, attack director, debug overlay
- `resources/`: tunable `Resource` scripts and their `.tres` data, upgrades in `resources/powers/`
- `autoload/`: `RunManager`, the state of the run
- `effects/`: running dust, ground shadows, clod crumbs
- `ui/`: dog mode label, trip label, pasture (upgrade choice) and end screens

`CLAUDE.md` holds the full game design, the art and technical rules and the build order.
