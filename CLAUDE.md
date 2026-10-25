# Project: Shepherd roguelike (working title)

A pixel-art real-time roguelike made with Godot 4 and GDScript. The player is a shepherd leading a flock of sheep along mountain paths (inspired by transhumance) and protecting them from folklore creatures. Each run is a series of escort trips between grass patches, with roguelike powers that rewrite the rules.

## Current scope: PROTOTYPE ONLY

Goal: prove that guiding the flock is fun before building anything else.

In scope:
- 10 sheep moving as boids and following the shepherd
- Shepherd (placeholder 12x16 rectangle, arrow keys / WASD)
- Plain green background (ColorRect)

Out of scope until explicitly requested: dog, enemies, powers, shop, map, meta-progression, menus, tilemaps, shadows, particles, sound.

**Do only the step you are asked to do, nothing more.** Do not add systems, menus or "nice to have" features.

## Build order (one step at a time, test and commit after each)

1. Chain following: front sheep follow the shepherd, the others follow the sheep ahead; discrete gaits (rest / walk / trot), limited turn rate, separation steers the heading
2. Graze and wander at rest (graze animation cycle, short steps toward neighbors, never alone)
3. One enemy that charges the most isolated sheep (flock panics and flees toward the center)
4. The dog, with a flee force that pushes sheep without oscillation

## Game design (reference for later steps)

**Core loop:** map of the mountain (Slay the Spire style) -> escort trip of 60-90 s with attacks -> rest patch (sheep graze, wool earned, shop, power choice) -> next trip -> region boss.

**Wool:** currency earned from sheep at patches. Fewer sheep = less wool. Must avoid a death spiral: guarantee a minimum wool per patch, cheap recruits, catch-up bonuses.

**Fairness rules (escort must never feel unfair):**
- Sheep AI is simple and predictable: they never wander off alone and flee toward the flock center, never toward danger
- Every attack is telegraphed (harpy shadow, werewolf growl, ground shaking before the ice worm)
- A captured sheep is not dead: about 5 s to rescue it
- Failure is gradual: losing sheep costs wool and power, no enemy wipes the flock in one hit
- End-of-run screen explains losses ("3 sheep lost to the harpy while the flock was stretched")

**Player roles:**
- Shepherd: controlled directly (move, aim, shoot). Starting weapon: sling. Other weapons later (bow, crook-spear, salt gun, torch).
- Dog: semi-autonomous AI. The dog cannot herd and attack at the same time, so every order has a cost.
- Sheep: boids with traits and mutations ("flock as a deck": horns, steel wool, foamy wool, one eye, ghost sheep; two sheep can be fused).

**Dog postures (permanent, one key to cycle):**
- Gather (default): brings stragglers back, tightens the flock
- Vanguard: pushes the flock forward, faster but the column stretches
- Rear guard: stays behind and bites anything approaching stragglers
- Circle: orbits the flock, compacts it and slows enemies, but everyone moves slowly
- Hunt: attacks the nearest threat alone, flock is no longer framed

Prototype uses only 3 postures (Gather, Rear guard, Hunt).

**Dog one-shot orders (aimed at cursor, with cooldown):**
- Go there: gathers everything in the targeted zone
- Bite: charges a specific enemy
- Fetch: retrieves a captured sheep
- Block: blocks a narrow passage for a few seconds
- Bark: area cry that scares small enemies and makes the flock bunch up

Prototype uses only 2 orders (Go there, Fetch).

**Bestiary (each forces a play style):** mist werewolf (pack, targets stragglers), cliff harpy (shadow then dive on isolated sheep), dahu (flank charge, can only turn one way), scree golem (slow, blocks the path, breaks into rocks), will-o'-the-wisp (leads sheep off the path), ice worm (erupts under a sheep), wool-shearing goblin (steals wool, not sheep), frost wyvern (freezing breath zone). Bosses: Harpy Queen, the Tarasque, the Living Storm.

**Powers:** passive and transformative, not simple active skills. Each has a real downside, scales with a counter, and carries tags (Wool, Fire, Charge, Heal, Crowd, Death, Trap) that trigger each other. Four targets: shepherd, weapon, dog, sheep. Examples: Bristling Wool (biters take damage, shearing pays -30%), Hydra Flock (a dead sheep splits into 2 fragile lambs), Domino Effect (a death enrages neighbors), Explosive Fleece, Cursed Bell (all enemies target one armored decoy sheep), Werewolf Pact. 3 choices per patch, paid reroll, option to refuse for a bonus.

## Boids guidelines

- Rules: follow the sheep ahead (guide = shepherd for the front sheep), separation, cohesion at rest, flee (from enemy or dog), obstacle avoidance, panic (speed up, lower cohesion)
- Movement is a heading turned at a limited `turn_rate` plus a speed tied to a discrete gait (rest / walk / trot); no free velocity vector, no slow creeping
- Expose ALL weights and speeds with `@export` (in a Resource if possible) so they can be tuned in the Godot inspector without editing code
- At ~10-30 sheep, compare every sheep with every other one (no spatial grid yet)
- Dog and enemies are state machines (FSM), not boids
- Sheep flip `flip_h` from the sign of `velocity.x` with a small threshold (about 5 px/s) to avoid flickering
- Walk animation speed is linked to real speed; when nearly still, play idle/graze instead of walk
- Random animation phase and +/-15% speed variation per sheep, from the first version

## Art constraints (do not modify sprites)

- Very simple pixel art: sheep are 10x10, one direction only (profile facing right), left is `flip_h`
- Sizes by importance: sheep 10x10, dog 12x8, shepherd 12x16, harpy 14x10, golem 24x24, boss 48x48
- Palette of 8-12 colors; enemies use saturated colors, never white (white/cream = sheep)
- Sheep animations: `walk` (2 frames), `idle` (body breathes 1 px, head moves on a different cycle), `graze` (body and legs fixed, only the head goes down), panic, captured
- Sheep sprites are split into body / head / legs when useful, so idle and graze can be done in code
- Sheep have no eyes and no grass blade in the graze animation (intentional)
- Shadows, indicators (`!`, flame, shield), particles and tints (golden, black, enraged) are done with code/shaders, not extra sprites
- Sprites live in `res://art/`

## Technical rules

- Godot 4.x, typed GDScript
- Base resolution 320x180, integer scaling, texture filter Nearest, `Snap 2D Transforms to Pixel` enabled
- Round animation offsets to whole pixels (`round()`) to avoid shimmering
- One scene per entity (`Sheep`, `Shepherd`, later `Dog`, enemies); no gameplay logic in `Main`
- `CharacterBody2D` + `AnimatedSprite2D` for sheep and shepherd; keep one `Sprite2D`/node per sheep (per-sheep logic is needed), do not use particles for the flock
- Data-driven content later: custom `Resource` types for powers, traits and enemies
- Autoload `RunManager` later for wool and run state
- Prefer creating complex `.tscn` scenes in the Godot editor; Claude Code edits scripts and simple scenes
- Do not reformat or rewrite files that are unrelated to the current task

## Project structure and conventions

- `art/` sprites; `entities/<name>/` scene + script + data of one entity; `scenes/` assembled screens (`main`, later map, shop, menus); `resources/` custom `Resource` scripts and `.tres` data; `autoload/` singletons (only `RunManager`, when needed); `ui/` when needed
- Create folders only when first used
- Entities communicate through signals and groups (`sheep`, `shepherd`), never `get_node("../..")`. `Main` only instantiates and wires
- Tunables live in `Resource` subclasses (`FlockConfig`, later `EnemyData`, `PowerData`) with `@export`
- Typed GDScript everywhere; `class_name` on entities and Resources that others reference
- Physics layers (2D): 1 shepherd, 2 sheep, 3 enemy, 4 dog, 5 obstacle
- Input actions: `move_left/right/up/down` (arrows + WASD by physical key). Add new actions with the step that needs them

## Commands

- Check scripts: `godot --headless --quit` (from the project root)
- Run the game: `godot --path .`
- If `godot` is not in PATH, use the full path to the executable here: ``C:\Users\jaime\Desktop\Godot\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe``

## Workflow

- Use git: one commit per working step
- Commit message format: `Initial commit` for the first one, then `type(scope): description` in lowercase imperative (e.g. `feat(sheep): add separation rule`). Types: `feat`, `fix`, `refactor`, `docs`, `chore`. Scope is the entity or system touched (`sheep`, `shepherd`, `dog`, `main`, `config`)
- Start every non-trivial task in plan mode and wait for validation before editing files
- Describe behavior, not only code: for example, "sheep should stop about 40 px from the shepherd without jittering"
- After each change, run the headless check and fix script errors before reporting
- The human judges game feel (too nervous, too clumped, jittering at rest) and tunes weights in the inspector; do not "tune by guessing" without being asked

## Success criteria for the prototype

1. The flock is pleasant to watch and to guide
2. There is a moment of panic where the player really decides something (the harpy dives: send the dog or shoot?)
3. After a failure, the player wants to restart

If at least two of three are true, continue to the next systems. Otherwise fix the core mechanics before adding content.
