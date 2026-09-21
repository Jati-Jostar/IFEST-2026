extends CharacterBody2D

# Player: gerakan 8 arah WASD/panah, dibatasi di dalam arena.
# Menembak ke arah kursor mouse (klik kiri / Space, tahan untuk autofire).
# Nilai default diambil dari GameBalance; isi export di Inspector
# hanya jika ingin override cepat saat playtest (0 = pakai GameBalance).

@export var speed_override: float = 0.0
@export var fire_rate_override: float = 0.0

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const SINGULARITY_SCENE := preload("res://scenes/abilities/singularity.tscn")
const NUKE_SCENE := preload("res://scenes/abilities/nuke.tscn")
const LASER_SCENE := preload("res://scenes/abilities/laser_beam.tscn")

# Jarak minimal pusat player dari tepi arena (kira-kira radius collision).
const ARENA_MARGIN := 16.0
# Jarak titik keluar peluru dari pusat player (ujung "hidung" pesawat).
const MUZZLE_OFFSET := 20.0

signal player_died
signal hp_changed(hp: int)
signal abilities_changed(has_singularity: bool, has_nuke: bool)
signal ammo_changed(ammo: int, max_ammo: int)
# progress = 0..1 menuju ambang skor berikutnya; ready = charge laser siap.
signal laser_changed(progress: float, ready: bool)
# F ditekan tanpa charge — HUD mengedipkan gauge supaya player paham kenapa.
signal laser_denied

var hp: int = 100
var has_singularity: bool = false
var has_nuke: bool = false
var ammo: int = 0
var has_laser: bool = false       # maks 1 charge (tidak menumpuk)
var _laser_index: int = 0         # ambang ke berapa yang sedang dituju
var _laser_prev_threshold: int = 0 # ambang sebelumnya (awal bar)
var _last_score: int = 0
var _laser_active: bool = false   # wind-up + beam: gerak lambat, tidak bisa menembak biasa
var _fire_cooldown: float = 0.0
var _invuln_left: float = 0.0
var _is_dead: bool = false

@onready var visual: Node2D = $Visual
# Thruster opsional: dicari dengan aman supaya game tetap jalan kalau
# artist menghapus atau mengganti namanya di dalam $Visual.
@onready var thruster: AnimatedSprite2D = visual.get_node_or_null("Thruster")
@onready var camera: Camera2D = $Camera2D


var _shoot_locked: bool = false

# --- Feedback menembak (muzzle flash + recoil) ---
# Node kilatan dibuat lewat kode sebagai SAUDARA $Visual, bukan anaknya:
# artist bebas mengganti isi $Visual tanpa menghapus efek ini, dan efeknya
# tidak ikut berputar mengikuti rotasi badan kapal.
var _muzzle_fx: Node2D
var _muzzle_left: float = 0.0      # sisa waktu kilatan (detik)
var _muzzle_dir: Vector2 = Vector2.UP
var _recoil: float = 0.0           # seberapa jauh badan kapal masih mundur (px)
var _recoil_dir: Vector2 = Vector2.UP
var _visual_home: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	# Space yang dipakai untuk mulai dari menu mungkin masih tertahan —
	# jangan sampai langsung membuang peluru. Tunggu dilepas dulu.
	_shoot_locked = Input.is_action_pressed("shoot")
	_visual_home = visual.position
	_muzzle_fx = Node2D.new()
	_muzzle_fx.z_index = 1   # di atas badan kapal
	add_child(_muzzle_fx)
	_muzzle_fx.draw.connect(_draw_muzzle)
	hp = GameBalance.player_max_hp
	ammo = GameBalance.player_max_ammo
	# Kamera tidak boleh memperlihatkan area di luar arena.
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(GameBalance.arena_width)
	camera.limit_bottom = int(GameBalance.arena_height)
	# Zoom sedikit keluar: arena jauh lebih besar dari layar, jadi makin
	# luas pandangan makin adil (lihat juga penanda ancaman di HUD).
	camera.zoom = Vector2.ONE * GameBalance.camera_zoom


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
	_handle_abilities()
	_update_shoot_fx(delta)


# ---------------- CHARGED LASER: charge dari skor ----------------

# Ambang ke-i: dari daftar GameBalance, lalu +laser_threshold_step setelahnya.
func laser_threshold(i: int) -> int:
	var list := GameBalance.laser_score_thresholds
	if i < list.size():
		return list[i]
	return list[-1] + GameBalance.laser_threshold_step * (i - list.size() + 1)


# Dipanggil (via signal) setiap skor berubah.
func on_score_changed(score: int) -> void:
	_last_score = score
	_update_laser()


# Charge dipakai: maju ke ambang berikutnya. Kalau skor ternyata sudah
# melewati ambang itu juga, laser langsung READY lagi — progres tidak
# pernah hilang, tapi tetap hanya 1 charge yang dipegang sekaligus.
func consume_laser() -> bool:
	if not has_laser:
		return false
	has_laser = false
	_laser_prev_threshold = laser_threshold(_laser_index)
	_laser_index += 1
	_update_laser()
	return true


# F: dengan charge -> wind-up dimulai (tidak bisa dibatalkan). Tanpa
# charge -> tidak terjadi apa-apa selain gauge berkedip di HUD.
func _try_fire_laser() -> void:
	if _laser_active:
		return
	if not consume_laser():
		laser_denied.emit()
		return
	_laser_active = true
	var beam := LASER_SCENE.instantiate()
	beam.finished.connect(func() -> void: _laser_active = false)
	add_child(beam)


func _update_laser() -> void:
	var target := laser_threshold(_laser_index)
	if not has_laser and _last_score >= target:
		has_laser = true
		AudioManager.play("laser_ready", global_position)
	var progress := 1.0
	if not has_laser:
		progress = clampf(float(_last_score - _laser_prev_threshold)
			/ float(target - _laser_prev_threshold), 0.0, 1.0)
	laser_changed.emit(progress, has_laser)


# Dipanggil pickup saat disentuh. Mengembalikan false jika slot penuh
# (pickup dibiarkan di lapangan).
func collect_ability(ability_type: String) -> bool:
	if ability_type == "singularity":
		if has_singularity:
			return false
		has_singularity = true
	else:
		if has_nuke:
			return false
		has_nuke = true
	abilities_changed.emit(has_singularity, has_nuke)
	return true


func _handle_abilities() -> void:
	if Input.is_action_just_pressed("ability_singularity") and has_singularity:
		has_singularity = false
		abilities_changed.emit(has_singularity, has_nuke)
		_spawn_ability(SINGULARITY_SCENE)
	if Input.is_action_just_pressed("ability_nuke") and has_nuke:
		has_nuke = false
		abilities_changed.emit(has_singularity, has_nuke)
		_spawn_ability(NUKE_SCENE)
	if Input.is_action_just_pressed("ability_laser"):
		_try_fire_laser()


# Ability muncul di posisi kursor mouse (di-clamp ke dalam arena).
func _spawn_ability(scene: PackedScene) -> void:
	var pos := get_global_mouse_position().clamp(
		Vector2(40, 40),
		Vector2(GameBalance.arena_width - 40, GameBalance.arena_height - 40))
	var ability := scene.instantiate()
	ability.position = pos
	get_tree().current_scene.add_child(ability)
	ability.reset_physics_interpolation()


# Dipanggil pickup heal. Gagal (false) kalau HP sudah penuh — pickup
# dibiarkan di lapangan untuk diambil nanti.
func heal(amount: int) -> bool:
	if _is_dead or hp >= GameBalance.player_max_hp:
		return false
	hp = mini(hp + amount, GameBalance.player_max_hp)
	hp_changed.emit(hp)
	Juice.flash(visual, Color(0.4, 1.6, 0.8), 0.25)
	Juice.floating_text(global_position, "+%d HP" % amount, Color(0.45, 1.0, 0.65), 22.0)
	return true


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
	Juice.spawn_ring(global_position, 60.0, Color(0.3, 0.9, 1.0, 1.0), 0.4)
	player_died.emit()


func _handle_movement() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Semburan thruster hanya menyala saat benar-benar bergerak.
	if thruster != null:
		thruster.visible = input_dir != Vector2.ZERO
	var speed := speed_override if speed_override > 0.0 else GameBalance.player_speed
	if _laser_active:
		speed *= GameBalance.laser_move_speed_mult
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
	if _laser_active:
		return
	if _shoot_locked:
		_shoot_locked = Input.is_action_pressed("shoot")
		return
	if not Input.is_action_pressed("shoot"):
		return
	# Peluru habis = tidak bisa menembak sama sekali. Isi ulang hanya
	# lewat pickup amunisi — tidak ada reload otomatis / regen.
	if ammo <= 0:
		return
	if _fire_cooldown > 0.0:
		return
	var fire_rate := fire_rate_override if fire_rate_override > 0.0 else GameBalance.player_fire_rate
	_fire_cooldown = fire_rate
	_shoot()


# Dipanggil pickup amunisi. Selalu berhasil (tidak seperti slot ability).
func refill_ammo(amount: int) -> void:
	ammo = mini(ammo + amount, GameBalance.player_max_ammo)
	ammo_changed.emit(ammo, GameBalance.player_max_ammo)


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
	ammo -= 1
	ammo_changed.emit(ammo, GameBalance.player_max_ammo)
	AudioManager.play("player_shoot", global_position)
	_kick_shoot_fx(aim)


# ---------------- FEEDBACK MENEMBAK (muzzle flash + recoil) ----------------

# Dipanggil sekali tiap peluru keluar. Tidak ada node baru yang di-spawn,
# jadi autofire tidak ikut memakan cap FX di Juice.
func _kick_shoot_fx(aim: Vector2) -> void:
	_muzzle_dir = aim
	_recoil_dir = aim
	_muzzle_left = GameBalance.muzzle_flash_time
	_recoil = GameBalance.shoot_recoil_distance


func _update_shoot_fx(delta: float) -> void:
	if _muzzle_left > 0.0:
		_muzzle_left = maxf(_muzzle_left - delta, 0.0)
		_muzzle_fx.queue_redraw()
	if _recoil > 0.0:
		_recoil = maxf(_recoil - GameBalance.shoot_recoil_recover * delta, 0.0)
		# Badan kapal mundur sedikit, lalu merayap kembali ke posisi semula.
		# _visual_home dipakai supaya offset bawaan artist tidak ikut hilang.
		visual.position = _visual_home - _recoil_dir * _recoil


# Kilatan di ujung hidung kapal: bola terang + garis pendek ke arah tembak,
# keduanya mengecil dan memudar bersamaan.
func _draw_muzzle() -> void:
	if _muzzle_left <= 0.0:
		return
	var k := _muzzle_left / maxf(GameBalance.muzzle_flash_time, 0.001)
	var base := _muzzle_dir * MUZZLE_OFFSET
	var c := GameBalance.muzzle_flash_color
	var r := GameBalance.muzzle_flash_radius * k
	_muzzle_fx.draw_circle(base, r * 1.9, Color(c.r, c.g, c.b, 0.25 * k))
	_muzzle_fx.draw_circle(base, r, Color(c.r, c.g, c.b, 0.85 * k))
	_muzzle_fx.draw_line(base, base + _muzzle_dir * GameBalance.muzzle_flash_length * k,
		Color(1.0, 1.0, 1.0, 0.8 * k), maxf(r * 0.7, 1.0))
