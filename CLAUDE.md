# Project: Shepherd roguelike (working title)

A pixel-art real-time roguelike made with Godot 4 and GDScript. The player is a shepherd leading a flock of sheep along mountain paths (inspired by transhumance) and protecting them from folklore creatures. Each run is a series of escort trips between grass patches, with roguelike powers that rewrite the rules.

## Current scope: PROTOTYPE ONLY

Goal: prove that guiding the flock is fun before building anything else.

In scope:
- 10 sheep moving as boids and following the shepherd
- Shepherd (sprite sheet `art/sprites/shepherd/`, animations idle / run / call, origin at the feet; arrow keys / WASD)
- One trip drawn in code (`scenes/main/ground.gd`): a band walked left to right, taller than the screen, start and end pastures, walls and forest edges at top and bottom; grass tufts and stones, no tilemap (decor sprites will come from Aseprite)
- Camera following the shepherd, leaning toward the flock, whole-pixel positions (`scenes/main/flock_camera.gd`)

Added since: a wolf (step 4), the trip band with an end screen (R restarts), the dog (step 5) with three modes cycled with Space: Gather, Rear guard, Hunt (a chased wolf is barked at and runs off, dropping its sheep; after such a bark the dog chases nothing for `DogData.bark_cooldown`, 6 s), shown top left. Wolves come as packs sent by `AttackDirector` (`scenes/main/attack_director.gd`) at attack points spread along the trail, never in the pastures, each wolf making one attack. The forest around the trip is rows of tree sprites on all four sides (`scenes/main/forest.gd`, sheet `art/sprites/environment/trees.png`), spilling up to 16 px onto the walkable band with a receding front line and clearings (noise), y-sorted with the entities, no collision; a shade laid over the whole forest (`effects/forest_shade.gdshader`, multiply, `Forest.SHADE_Z` 7, under the night and the indicators) darkens the trees, the ground and what stands there alike, by each pixel's depth behind the front line (the four sides combined like the distance from a rounded corner, so the corners join): `shade_levels` (5) levels from no change at `shade_start` (-4 px) to `shade_darkest` at `shade_end` (40 px), with an ordered 4x4 dithering fixed on the world's pixels from one level to the next (`effects/dither.gdshaderinc`). Between the pastures, lone trees and groves of 6-12 trees stand on the walkable band, each grove blocking the whole outline of its trunks (obstacle layer, nothing gets in between them), its whole inside shaded darkest and the shade fading out in 3 levels around it (`trail_shade_colors`), dithered across `dither_width` px; sheep and dog veer around each grove or lone tree ahead, seen as a disc (`Forest.avoidance()`), the shepherd slides along. Every trip has its own layout (ground tufts and stones, forest edges, trail trees) from `RunManager.trip_seed()`, drawn anew each run. The shepherd's collision is a footprint at his feet. An eagle (`entities/eagle/`, placeholder body drawn in code until the sprite comes), also sent by `AttackDirector` (`eagles` per attack): its shadow crosses the screen left to right, a red sight locks on the most isolated sheep on screen that no other eagle is after (always one, unless none is free on screen: it leaves, or passes again if `max_passes` > 1), it dives from the top right (its shadow below it, growing as it comes down) and grabs it wherever it is, carries it off to the left, climbing (lost out of the screen or too high), and always flies off toward the top left; a dog bark below makes it drop the sheep. Its shadow is a flapping silhouette from its sheet (mask drawn by `effects/shadow_mask.gdshader`), cast over everything below it, smaller as it climbs (by sixteenths), flapping fast once the attack is over; each pass varies slightly (height, slope, shadow size, flapping speed). Wolf and eagle share the `Enemy` base (`entities/enemy/enemy.gd`). **Strays**: a trip has `Strays.chance` (50%) to meet, between the pastures (`pasture_margin` away from them, beyond a sheep's reach there) and away from the trees, a sheep, a lamb or a ewe with her lamb grazing alone (`scenes/main/strays.gd`, `Sheep.stray`: out of the `sheep` group, so nothing hunts, herds or waits for them); they join the flock with a hop when the shepherd or a sheep of the flock comes within `FlockConfig.stray_join_radius` (40 px), a lamb with its stray mother, and count in the trip and the run from then on. **Night**: a trip has `Night.chance` (30%) to be walked at night (`scenes/main/night.gd`, `Night.active`, banner "Trip n/5 - Night"): a veil over the whole trip (the `Night` node at `Night.OVERLAY_Z`, shader `effects/lantern_light.gdshader`, multiply blend, no Godot lights: they take no texture made on the GPU) takes `darkness` away from the world, except around the shepherd's lantern: full in `lantern_core`, then fading to `lantern_radius` in `lantern_levels` levels with ordered 4x4 dithering between them (`dither_band`); the fade is centered exactly where the shepherd is drawn (interpolated, never snapped) while the dithering pattern stays put on the world's pixels; indicators are drawn above the veil at `Night.MARKS_Z`, by a child node of their entity (`_marks`: the sheep's "!" and rescue bar, the wolf's "!", the eagle's sight, the dog's mode icon) or on their own (bark ring, stun stars; the aim preview too at night, so no tree hides it then); no eagle comes at night (E still sends one). **Run**: the autoload `RunManager` (`autoload/run_manager.gd`) chains 5 trips for now (testing; the flock that arrives starts the next one; the trip scene is reloaded) and keeps the powers taken; between two trips, on the end pasture the game goes on (shepherd and dog stand still, enemies left run off, no attack): `Shearing` (`scenes/main/shearing.gd`) shears the sheep one by one left to right, faster and faster (burst of 1 px fluff `effects/wool_fluff.tscn`, `_shaved` animations, a wool icon hops out and flies to the counter top left, `ui/wool_counter.gd`, 2 wool per sheep in `RunManager.wool`, kept for the run), then the trip report (`ui/trip_report.tscn`, light veil: sheep arrived, how many each kind of enemy took, `Trip.losses`; sheep rescued; lines one by one, then Continue), then the pasture screen (`ui/pasture_screen.tscn`, light veil) offers 3 powers picked at random, each on the card of its target (`PowerCard`, `ui/power_card.gd`: frame from `art/ui/power_cards/power_cards_frames.png` by `PowerData.target`, crook / sheep / dog, title in the banner, description on the parchment, artwork window empty for now), and one is clicked, then the shop (`ui/shop_screen.tscn`) spends wool on recruits (Sheep 10, Lamb 5, prices exported on the node, bought again while the wool lasts) that join the flock at once next to a random sheep in a burst of fluff (`Shearing.recruit()`, a lamb gets that sheep as mother), or on Ram 15 (a ram takes the place of a random sheep that is not one, its lambs follow the ram), Continue leaves; meanwhile each graze has 10% chance to give a shorn sheep its wool back (`FlockConfig.regrow_chance`); once the shop is left the screen fades to black and the next trip loads, fading back in (`RunManager.go_to_next_trip()`); the end screen shows the run result and R starts a new run. Powers are `PowerData` resources (`resources/powers/*.tres`, names and texts in English) made of `PowerEffect`s (a property multiplied, then a bonus added) applied to the run's copy of the settings of their target (`RunManager.settings()`: `CrookData` for the crook, `FlockConfig` for the sheep and the lambs, `DogData` for the dog; the base `.tres` are never changed); they add up when taken again, by small steps (about 10%, an additive bonus). Pool: Heavy Clod (+1 damage, clods 1 px bigger, cooldown +50%), Extra Clod (+1 clod per throw, landing spots `spread` (16) px apart across the throw), Quick Throw (cooldown x0.75), Long Throw (reach x1.33), Flat Throw (clods 40% faster, arc x0.6), Mudball (a clod hit slows the enemy by 40% for 2 s, `CrookData.mud_slow`/`mud_time`, `Enemy._speed_scale`, muddy brown tint; taken twice it slows by 80%, the most); the crook's base reach is 70 px. Sheep powers: Swift Hooves (trot +4 px/s), Tight Flock (separation -1.5 px), Hot-Headed (sheep powers recharge 0.2 s sooner, rams only for now), Pregnancy (a sheep lost leaves a lamb by a random sheep, 25% then +10% per extra pick, `FlockConfig.lamb_chance()`, through `Trip.born` and `Shearing.recruit()`); dog powers: Loud Bark (bark distance +2 px), Quick Paws (speed +6 px/s), Keen Eye (`gather_delay` -0.1 s), Relentless (`bark_cooldown` -0.5 s); none has a downside. The shepherd lobs clods with his crook (left click, `entities/clod/`): the clod flies in height (`Clod.flight()`: a point on the ground and a height) to what is aimed (`Shepherd.aim()`: the middle of the body of the attacking enemy seen under the mouse, up in the air for the eagle, otherwise the ground under the mouse; within `max_range` (70 px) on the ground and `max_height` (60 px), otherwise the crosshair turns red) along an arc higher for longer throws, then on along the same curve to the ground if it missed, with a small shadow on the ground below it, and a cooldown (settings in `CrookData`, `resources/crook.tres`); it hits an attacking enemy whose body it goes through at its height (`Enemy.is_hit_at()`: `hit_half_size` on the ground, `hit_heights` above `altitude()`), so a clod flying over a wolf misses it; every tree (edge and trail) stops a clod flying through it as drawn (`Forest.blocks()`: its silhouette read from the sheet row by row, turned round its trunk, shrunk by `block_margin`, 1 px; with the base throws no clod flies over a tree), and the dotted arc stops there; the clod, the dots of its arc, the eagle and the sheep it carries keep their position on the ground and are drawn lifted (`Sheep.hang()`), so they are y-sorted with the trees and a tree in front hides them (the eagle's shadow is still cast over everything); an attacking enemy hit loses one health (`Enemy.health`: wolf 2, eagle 1): with some left it flinches (flash, 2 px recoil) and goes on, at none it is scared off like by a bark (drops its sheep or gives up); an enemy chased off (out of health, barked at, made to drop its sheep) turns grey; a dog bark scares any enemy off whatever its health; it crumbles into a burst of 1 px crumbs (`effects/crumble.tscn`) on hitting or landing. The throw plays the `call` animation for now. Lambs (`entities/sheep/lamb.tscn`: the `Sheep` script with `lamb = true`, config `resources/lamb_config.tres`, sheet `art/sprites/sheeps/lamb-Sheet.png`, `idle` only, hops drawn in code with `FlockConfig.hop_height`/`hop_length`): `lamb_ratio` (30%) of the starting sheep have one, put by its mother; it follows her instead of the column (adopts the nearest sheep if she is taken), stops by her side, flees toward her, is never a guide for the others, is not shorn (no wool for now) and grows into a sheep on the pasture after 2, 3 or 4 trips drawn at random (`Main.lamb_grow_trips`, swapped by `Shearing` with a burst of fluff); `RunManager.lambs` carries the trips left of each lamb from one trip to the next. Rams (`entities/sheep/ram.tscn`: the `Sheep` script with `ram = true`, sheet `art/sprites/sheeps/ram-Sheet.png` of 16x16 frames: idle, run, to_graze / graze / finished_graze, butt; never shorn, so no wool; counted in `RunManager.rams`): a ram ready to butt charges the nearest attacking enemy on the ground (`Enemy.can_be_butted()`: a wolf charging or dragging a sheep) within `ram_charge_radius` (40 px), at `ram_charge_speed` (60), head down (`butt`), giving up after `ram_charge_time` (1.5 s); on reaching it (`ram_butt_distance`, 6 px), or when an enemy comes to grab it first (`Sheep.fends_off()`, called before `capture()`), it `Enemy.butted()` it: -1 health (`ram_damage`), and with some left a 10 px push (`ram_push`) and a 1.5 s stun (`ram_stun_time`: the wolf stands frozen, then goes on; yellow stars drawn in code circle over its head, `effects/stun_stars.tscn`, at `Enemy.head_offset`); the eagle always gives up; the ram charges again after `ram_cooldown` (2 s), meanwhile it can be caught. **Game feel** (all drawn in code): each trip opens with a banner sliding across (`ui/trip_banner.gd`); during a trip the HUD (dog mode, wool, trip) is hidden, each element showing for 2 s when it changes and all of them at the start of the trip, and it stays shown on the pasture (`ui/hud_fader.gd`); during a trip the mouse is a pixel crosshair (`ui/crosshair.gd`), red beyond the crook's reach, with a ring filling up during the throw cooldown and small crosses where the clods would land (`Shepherd.landing_spots()`) and their arcs dotted, drawn in the world without pixel snapping (`entities/shepherd/aim_preview.gd`); a clod hit freezes the game a few frames (`effects/hit_stop.gd`), the hit that sends an enemy off, a ram's butt and an eagle's grab shake the camera (`shake()`, group `camera`); a bark spreads a ring to its reach (`effects/bark_wave.gd`) and a mode change shows the mode's icon over the dog and makes the label hop; a sheep startled by an enemy shows a yellow "!", a caught sheep a bar that empties as it is taken toward where it is lost (`Enemy.carry_progress()`, red and blinking near the end), a lost one bursts into wool; freed or arrived on the pasture, sheep hop for joy, shorn they squash; the pasture screen and the shop fade in, power cards come in one after another and go away once one is picked, a hovered card shows what it would change for this run, before and after (`PowerCard.changes()`, e.g. `Cooldown 0.70 » 0.53 s`), an offer too dear shakes and flashes red, the wool counter rolls, the end screen reveals its lines and R fades to the new run (`RunManager.restart()`). **UI text**: the project theme `ui/theme.tres` (`gui/theme/custom`) sets the pixel fonts for every Control: m5x7 at 16 (one font pixel per game pixel), cream with a 1 px shadow; titles use the `TitleLabel` variation (alagard 16) or, for the end screen's large title, `HeadingLabel` (m5x7 32); alagard has no accents nor m5x7 an em dash, all game text is in English; buttons are pixel frames in the cards' browns. Do not force font sizes on nodes (the HUD's ones in `main.tscn` are removed in code); the power cards and the trip banner keep their own fonts.

**Sound** (hooks ready, no file yet): the autoload `Sound` (`autoload/sound.gd`) plays files found by name, and a name with no file plays nothing, so a sound is added by dropping its file in: `Sound.play(name, at)` plays `audio/sfx/<name>.wav` (or `.ogg`, `.mp3`; or variants `<name>_1`, `<name>_2`... picked at random) on the `Sfx` bus, at a point of the world (`AudioStreamPlayer2D`, panned to its side of the screen) or, without `at`, in the middle (interface); `Sound.play_music(name)` crossfades to `audio/music/<name>.ogg` (or `.wav`, `.mp3`), looped, on the `Music` bus (buses in `default_bus_layout.tres`); a music with no file leaves the one playing on, and it goes on across the trip scene reloads. Settings in `SoundConfig` (`resources/sound_config.tres`): `pitch_spread` (each effect at +/-5% pitch), `repeat_interval` (the same effect never restarts sooner than 0.05 s), `panning_strength`, `max_distance`, `music_fade`, and `volumes` (dB by sound or music name). The player's volume of each bus (`Sound.volume()` / `set_volume()`, 0-10 steps, amplitude step / 10, muted at 0, full by default) is set in the pause menu and saved at once in `user://settings.cfg`, read back at launch. Effects: `throw`, `clod_hit` (enemy hit, health left), `enemy_ko` (no health left), `clod_crumble` (on the ground or a tree), `bark`, `wolf_howl` (comes out of the forest), `wolf_growl` (its red "!"), `eagle_cry` (its shadow passes), `eagle_dive`, `sheep_alert` (yellow "!"), `sheep_caught`, `sheep_lost`, `sheep_freed`, `ram_butt`, `stray_join`, `shear`, `puff` (lamb grows, recruit joins), and in the interface `wool` (an icon reaches the counter), `banner`, `power_pick`, `buy`, `refuse` (too dear), `click` (Continue). Music: `trip` or `night` during a trip, `attack` while an enemy is around (`AttackDirector`), `pasture` between two trips, `victory` / `defeat` on the end screen.

**Pause**: Escape (action `pause`) pauses the game and shows the pause menu (`ui/pause_menu.tscn`, `PauseMenu`, added by `Main`) over a dark veil that takes the clicks: Resume (or Escape again), Settings, Restart run (`RunManager.restart()`), Quit; Settings swaps the buttons for the player's volumes, Volume (`Master`), Music, Effects (`Sfx`), each a bar of 10 pixel steps drawn in code (`ui/volume_bar.gd`, `VolumeBar`: click or drag, mouse wheel; the left half of the first step mutes), then Back (or Escape); it does not open while the game is already paused (end screen, P testing screen) nor during a fade to black (`RunManager.is_fading()`), so the trip scene never reloads frozen.

Out of scope until explicitly requested: other dog postures (Vanguard, Circle) and the one-shot orders, enemies other than the wolf and the eagle, map, meta-progression, menus other than the pause menu, tilemaps, shadows, other particles (only running dust and the clod's crumbs exist).

**Do only the step you are asked to do, nothing more.** Do not add systems, menus or "nice to have" features.

## Build order (one step at a time, test and commit after each)

1. Chain following: front sheep follow the shepherd, the others follow the sheep ahead; discrete gaits (rest / walk / trot), limited turn rate, separation steers the heading
2. Graze and wander at rest (graze animation cycle, short steps toward neighbors, never alone); a stopped column gathers into a group
3. Flight zone: sheep step aside from the shepherd, sideways to his path (`_flee_from`, reused by the dog)
4. One enemy that charges the most isolated sheep (flock panics and flees toward the center)
5. The dog, with a flee force that pushes sheep without oscillation

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
- Shepherd: controlled directly (move, aim, shoot). Starting weapon: the crook, used as a houlette (a shepherd's staff with a small scoop that throws clods of earth). Other weapons later (bow, crook-spear, salt gun, torch).
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
- Base resolution 320x180, integer scaling, texture filter Nearest, `Snap 2D Transforms to Pixel` disabled (smoother motion), physics interpolation enabled
- Round animation offsets to whole pixels (`round()`) to avoid shimmering
- One scene per entity (`Sheep`, `Shepherd`, later `Dog`, enemies); no gameplay logic in `Main`
- `CharacterBody2D` + `AnimatedSprite2D` for sheep and shepherd; keep one `Sprite2D`/node per sheep (per-sheep logic is needed), do not use particles for the flock
- Data-driven content later: custom `Resource` types for powers, traits and enemies
- Autoload `RunManager` later for wool and run state
- Prefer creating complex `.tscn` scenes in the Godot editor; Claude Code edits scripts and simple scenes
- Do not reformat or rewrite files that are unrelated to the current task

## Project structure and conventions

- `art/` sprites; `entities/<name>/` scene + script + data of one entity; `scenes/` assembled screens (`main`, later map, shop, menus); `resources/` custom `Resource` scripts and `.tres` data; `autoload/` singletons (`RunManager`, `Sound`); `audio/sfx/` and `audio/music/` sound files; `ui/` when needed; `effects/` reusable visual effects (`dust.tscn`: square dust while a body runs, threshold `min_speed` per instance)
- Create folders only when first used
- Entities communicate through signals and groups (`sheep`, `shepherd`), never `get_node("../..")`. `Main` only instantiates and wires
- Tunables live in `Resource` subclasses (`FlockConfig`, later `EnemyData`, `PowerData`) with `@export`
- Typed GDScript everywhere; `class_name` on entities and Resources that others reference
- Physics layers (2D): 1 shepherd, 2 sheep, 3 enemy, 4 dog, 5 obstacle
- Input actions: `move_left/right/up/down` (arrows + WASD by physical key). Add new actions with the step that needs them

## Commands

- Check scripts: `godot --headless --quit` (from the project root)
- Run the game: `godot --path .`
- A run is 5 trips for now (`RunManager.TRIPS`, testing); between two trips the flock is shorn, the pasture screen offers 3 upgrades, click one, buy recruits in the shop, Continue, and the next trip fades in
- Escape pauses: Resume (or Escape again), Settings (volumes, saved), Restart run, Quit
- On the end-of-run screen, R starts a new run
- Space cycles the dog's mode (Gather, Rear guard, Hunt); the current mode is shown top left
- Left click lobs a clod at the mouse
- E sends an eagle at once, L a wolf, P opens a choice of every power (applied at once, the trip goes on), N takes the flock, shepherd and dog straight to the end pasture (testing aids)
- With the F3 overlay on, mouse wheel / keypad + and - zoom the camera out and in (testing aid, gameplay ignores it); F3 also draws the dog's flight zone (brown circle)
- In game, F3 toggles the debug overlay (shepherd trail, flight zone, each sheep's target line and state color: white stand, yellow-green graze, blue walk, orange trot, purple wander, red flee or panic, magenta captured; magenta line from the wolf or the eagle to its target)
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
