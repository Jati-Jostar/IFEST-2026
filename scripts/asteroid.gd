extends Area2D

# Asteroid: objek netral yang melayang pelan dan memantul di tepi arena.
# Bisa ditabrak player (sakit), dihancurkan peluru/ledakan, dan saat
# hancur memuntahkan 3-5 fragment — sumber chain reaction tambahan.

signal asteroid_destroyed(pos: Vector2, killed_by: String)

const FRAGMENT_SCENE := preload("res://scenes/asteroid_fragment.tscn")
const CONTACT_RANGE := 34.0   # jarak pusat-ke-pusat "menabrak player"
const EDGE_MARGIN := 20.0

var hp: int = 20
var velocity: Vector2 = Vector2.ZERO
var _spin: float = 0.0
var _player: Node2D

@onready var visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("asteroids")
	hp = GameBalance.asteroid_hp
	_spin = randf_range(-1.2, 1.2)
	_player = get_tree().get_first_node_in_group("player")
	if velocity == Vector2.ZERO:
		velocity = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(
			GameBalance.asteroid_speed_min, GameBalance.asteroid_speed_max)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	visual.rotation += _spin * delta
	_bounce_on_arena_edges()
	if _player != null and is_instance_valid(_player) and _player.has_method("take_damage"):
		if global_position.distance_to(_player.global_position) < CONTACT_RANGE:
			_player.take_damage(GameBalance.asteroid_contact_damage)


func _bounce_on_arena_edges() -> void:
	var w := GameBalance.arena_width
	var h := GameBalance.arena_height
	if (global_position.x < EDGE_MARGIN and velocity.x < 0.0) \
			or (global_position.x > w - EDGE_MARGIN and velocity.x > 0.0):
		velocity.x = -velocity.x
	if (global_position.y < EDGE_MARGIN and velocity.y < 0.0) \
			or (global_position.y > h - EDGE_MARGIN and velocity.y > 0.0):
		velocity.y = -velocity.y


# _depth diterima demi kompatibilitas dengan ledakan chain, tapi diabaikan:
# fragment selalu membawa depth 0 (mengabaikan decay) — itu peran asteroid.
func take_damage(amount: int, source: String = "bullet", _depth: int = 0) -> void:
	if hp <= 0:
		return
	hp -= amount
	if hp <= 0:
		die(source)
		return
	Juice.flash(visual, Color(6, 6, 6), GameBalance.hit_flash_duration)
	Juice.punch_scale(visual, GameBalance.hit_punch_amount, GameBalance.hit_punch_duration)


func die(killed_by: String = "bullet") -> void:
	AudioManager.play("asteroid_break", global_position)
	# Ditunda: dilarang menambah Area2D (fragment) di tengah physics
	# callback ("flushing queries"). Deferred jalan setelah physics step,
	# masih sebelum node ini benar-benar dihapus oleh queue_free.
	call_deferred("_spawn_fragments")
	asteroid_destroyed.emit(global_position, killed_by)
	queue_free()


# Pecahan selalu terbang ke arah yang SAMA setiap kali: sudut merata
# 360/fragment_count, dimulai dari fragment_start_angle_deg. Tidak ada
# unsur acak — supaya player bisa hafal polanya dan merencanakannya.
# Semua pecahan berbagi kecepatan dan umur yang sama persis.
func _spawn_fragments() -> void:
	var parent := get_tree().current_scene
	if parent == null:
		return
	var count: int = maxi(GameBalance.fragment_count, 1)
	var start := deg_to_rad(GameBalance.fragment_start_angle_deg)
	for i in count:
		var angle := start + TAU * float(i) / float(count)
		var fragment := FRAGMENT_SCENE.instantiate()
		fragment.position = global_position
		fragment.velocity = Vector2.RIGHT.rotated(angle) * GameBalance.fragment_speed
		parent.add_child(fragment)
		fragment.reset_physics_interpolation()
