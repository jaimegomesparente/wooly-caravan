class_name Enemy
extends CharacterBody2D
## What the sheep, the dog and the AttackDirector know of an enemy (group `enemy`).

signal sheep_captured(sheep: Sheep)
signal sheep_lost(sheep: Sheep)

## Spawns and despawns this far (px) outside the visible screen.
const OFFSCREEN_MARGIN := 24.0
## Every hit flashes the sprite white, fading over FLINCH_TIME s; a hit that leaves it some health
## also makes it recoil (px). Chased off (out of health, barked at, made to drop its sheep), it turns
## grey for good.
const FLINCH_TIME := 0.12
const FLINCH_RECOIL := 2.0
const TINT_SHADER := preload("res://effects/enemy_tint.gdshader")
const STUN_STARS := preload("res://effects/stun_stars.tscn")
## Burst of wool where a sheep is lost.
const LOST_FLUFF := preload("res://effects/wool_fluff.tscn")
## Strongest slow from mud (fraction of its speed lost).
const MAX_MUD_SLOW := 0.8
## Time (s) of the push back from a ram's butt.
const BUTT_PUSH_TIME := 0.15
## Impacts: the game freezes HIT_STOP s on a hit, KO_STOP s on the hit that sends it off (the screen
## shakes KO_SHAKE px too); a ram's butt shakes it BUTT_SHAKE px.
const HIT_STOP := 0.05
const KO_STOP := 0.09
const KO_SHAKE := 2.0
const BUTT_SHAKE := 1.0

## Hits (clods) it takes before it runs off; a bark makes it run off whatever is left.
@export var health: int = 1
## Where the stars circle (px from its origin) while it is stunned.
@export var head_offset: Vector2 = Vector2(0, -14)
## Its body, where a clod hits it: half its width and half its depth (px) on the ground around its
## origin, and how high (px) it goes, bottom and top, above its altitude.
@export var hit_half_size: Vector2 = Vector2(8.5, 3.0)
@export var hit_heights: Vector2 = Vector2(0.0, 10.0)

## The sprite's tint (flash, grey, mud), made on the first hit.
var _tint: ShaderMaterial
## 1, or less while slowed by mud: each enemy multiplies its speeds by it.
var _speed_scale: float = 1.0
## Mud slows still running (a new hit restarts the count, the last one to end lifts the slow).
var _mud_slows: int = 0
## Time (s) left stunned by a ram's butt: each enemy says what it does meanwhile.
var _stun_timer: float = 0.0
var _stars: StunStars
## Draws its indicators (`_draw_marks()`) above everything in the world, the night's veil included;
## each enemy redraws it every tick.
var _marks: Node2D


func _ready() -> void:
	_marks = Node2D.new()
	_marks.z_as_relative = false
	_marks.z_index = Night.MARKS_Z
	_marks.draw.connect(_draw_marks)
	add_child(_marks)


## Its indicators ("!", sight), drawn on `_marks`.
func _draw_marks() -> void:
	pass


## True while nearby sheep should panic.
func is_dangerous() -> bool:
	return false


## True while a ram may charge it (on the ground, within reach).
func can_be_butted() -> bool:
	return false


## True while the dog may chase it.
func is_threat() -> bool:
	return false


## Height (px) of its origin above the ground (its position is the point on the ground below it).
func altitude() -> float:
	return 0.0


## True when a clod `margin` px wide at `height` px above `ground` is in its body.
func is_hit_at(ground: Vector2, height: float, margin: float = 0.0) -> bool:
	var offset := ground - global_position
	var bottom := altitude() + hit_heights.x
	var top := altitude() + hit_heights.y
	var on_ground := absf(offset.x) <= hit_half_size.x + margin and absf(offset.y) <= hit_half_size.y + margin
	return on_ground and height >= bottom - margin and height <= top + margin


## Its body as seen on screen, in world coordinates (the point on the ground lifted by the height).
func seen_body() -> Rect2:
	var top := altitude() + hit_heights.y
	return Rect2(global_position + Vector2(-hit_half_size.x, -top),
			Vector2(hit_half_size.x * 2.0, hit_heights.y - hit_heights.x))


## Height (px) of the middle of its body: where a throw at it aims.
func aim_height() -> float:
	return altitude() + (hit_heights.x + hit_heights.y) / 2.0


## How close the sheep it holds is to being lost: 0 just caught, 1 lost (0 when holding none).
func carry_progress() -> float:
	return 0.0


## Barked at by the dog, or out of health: runs off, grey (each enemy says how).
func scare() -> void:
	pass


## Hit by a clod flying along `direction`: flashes and loses `damage` health; at none it turns grey
## and runs off, otherwise it recoils and goes on with what it was doing. A muddy clod also slows it
## by `mud_slow` for `mud_time` s.
func hit(direction: Vector2, damage: int = 1, mud_slow: float = 0.0, mud_time: float = 0.0) -> void:
	health -= damage
	_flash()
	if mud_slow > 0.0 and mud_time > 0.0:
		_slow(mud_slow, mud_time)
	if health <= 0:
		Sound.play(&"enemy_ko", global_position)
		HitStop.freeze(get_tree(), KO_STOP)
		get_tree().call_group("camera", "shake", KO_SHAKE)
		_set_tint(&"grey", 1.0)
		scare()
		return
	Sound.play(&"clod_hit", global_position)
	HitStop.freeze(get_tree(), HIT_STOP)
	global_position += direction.normalized() * FLINCH_RECOIL


## Butted by a ram along `direction`: hit like by a clod; with health left it is also pushed back
## `push` px and stunned for `stun_time` s, stars circling over its head.
func butted(direction: Vector2, damage: int, push: float, stun_time: float) -> void:
	hit(direction, damage)
	if health <= 0:
		return
	get_tree().call_group("camera", "shake", BUTT_SHAKE)
	_stun_timer = stun_time
	if _stars == null or not is_instance_valid(_stars):
		_stars = STUN_STARS.instantiate() as StunStars
		_stars.position = head_offset
		# Above the night's veil, like the other indicators.
		_stars.z_as_relative = false
		_stars.z_index = Night.MARKS_Z
		add_child(_stars)
	_stars.time = stun_time
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(self, "global_position", global_position + direction.normalized() * push,
			BUTT_PUSH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## `prey` is lost (no more rescue bar): a burst of wool where it is (`sheep_lost`).
func _lose(prey: Sheep) -> void:
	Sound.play(&"sheep_lost", prey.global_position)
	var fluff := LOST_FLUFF.instantiate() as Node2D
	fluff.position = prey.global_position + Vector2(0, -5 - prey.lift)
	add_sibling(fluff)
	prey.lost = true
	sheep_lost.emit(prey)


func _slow(amount: float, time: float) -> void:
	_speed_scale = 1.0 - minf(amount, MAX_MUD_SLOW)
	_mud_slows += 1
	_set_tint(&"mud", 1.0)
	# Pauses with the game; never called once this enemy is gone.
	get_tree().create_timer(time, false).timeout.connect(_end_slow)


func _end_slow() -> void:
	_mud_slows -= 1
	if _mud_slows == 0:
		_speed_scale = 1.0
		_set_tint(&"mud", 0.0)


func _flash() -> void:
	_set_tint(&"flash", 1.0)
	if _tint:
		create_tween().tween_property(_tint, "shader_parameter/flash", 0.0, FLINCH_TIME)


func _set_tint(parameter: StringName, value: float) -> void:
	if _tint == null:
		var sprite := get_node_or_null("AnimatedSprite2D") as CanvasItem
		if sprite == null:
			return
		_tint = ShaderMaterial.new()
		_tint.shader = TINT_SHADER
		sprite.material = _tint
	_tint.set_shader_parameter(parameter, value)


func _flock_center() -> Vector2:
	var flock := get_tree().get_nodes_in_group("sheep")
	if flock.is_empty():
		return global_position
	var center := Vector2.ZERO
	for sheep: Node2D in flock:
		center += sheep.global_position
	return center / flock.size()


## The part of the world visible on screen at normal zoom (the debug zoom never changes where an
## enemy appears or telegraphs).
func _view_rect() -> Rect2:
	var size := get_viewport_rect().size
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Rect2(Vector2.ZERO, size)
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)
