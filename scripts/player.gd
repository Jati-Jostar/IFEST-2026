extends CharacterBody2D

# Player: gerakan 8 arah WASD/panah, dibatasi di dalam arena.
# Menembak ke arah kursor mouse (klik kiri / Space, tahan untuk autofire).
# Nilai default diambil dari GameBalance; isi export di Inspector
# hanya jika ingin override cepat saat playtest (0 = pakai GameBalance).

@export var speed_override: float = 0.0
@export var fire_rate_override: float = 0.0

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

# Jarak minimal pusat player dari tepi arena (kira-kira radius collision).
const ARENA_MARGIN := 16.0
# Jarak titik keluar peluru dari pusat player (ujung "hidung" pesawat).
const MUZZLE_OFFSET := 20.0

signal player_died
signal hp_changed(hp: int)

var hp: int = 100
var _fire_cooldown: float = 0.0
var _invuln_left: float = 0.0
var _is_dead: bool = false

@onready var visual: Node2D = $Visual
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	hp = GameBalance.player_max_hp
	# Kamera tidak boleh memperlihatkan area di luar arena.
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(GameBalance.arena_width)
	camera.limit_bottom = int(GameBalance.arena_height)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_invuln_left -= delta
	# Berkedip selama invuln window supaya kondisinya terbaca.
	if _invuln_left > 0.0:
		visual.visible = fmod(_invuln_left, 0.15) > 0.06
	else:
		visual.visible = true
	_handle_movement()
	_handle_aim()
	_handle_shooting(delta)


func take_damage(amount: int) -> void:
	if _is_dead or _invuln_left > 0.0:
		return
	hp -= amount
	_invuln_left = GameBalance.player_invuln_time
	hp_changed.emit(hp)
	AudioManager.play("player_hit", global_position)
	Juice.flash(visual, Color(1, 0.25, 0.25), 0.2)
	Juice.shake(GameBalance.shake_player_hit_intensity, GameBalance.shake_player_hit_duration)
	if hp <= 0:
		_die()


func _die() -> void:
	_is_dead = true
	hide()
	AudioManager.play("player_death", global_position)
	print("GAME OVER — tekan R untuk restart (layar game over menyusul di Phase 7)")
	player_died.emit()


func _handle_movement() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := speed_override if speed_override > 0.0 else GameBalance.player_speed
	velocity = input_dir * speed
	move_and_slide()
	global_position = global_position.clamp(
		Vector2(ARENA_MARGIN, ARENA_MARGIN),
		Vector2(GameBalance.arena_width - ARENA_MARGIN, GameBalance.arena_height - ARENA_MARGIN)
	)


func _handle_aim() -> void:
	# Placeholder segitiga menghadap ke atas (-Y), jadi rotasi digeser 90 derajat.
	var aim := get_global_mouse_position() - global_position
	if aim.length_squared() > 1.0:
		visual.rotation = aim.angle() + PI / 2.0


func _handle_shooting(delta: float) -> void:
	_fire_cooldown -= delta
	if not Input.is_action_pressed("shoot"):
		return
	if _fire_cooldown > 0.0:
		return
	var fire_rate := fire_rate_override if fire_rate_override > 0.0 else GameBalance.player_fire_rate
	_fire_cooldown = fire_rate
	_shoot()


func _shoot() -> void:
	var aim := (get_global_mouse_position() - global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.UP
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.direction = aim
	projectile.global_position = global_position + aim * MUZZLE_OFFSET
	# Peluru jadi anak scene utama, bukan anak player, supaya tidak ikut bergerak.
	get_tree().current_scene.add_child(projectile)
	projectile.reset_physics_interpolation()  # cegah kedip 1 frame di posisi salah
	AudioManager.play("player_shoot", global_position)
