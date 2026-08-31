extends Node2D

# Main scene: arena, player, spawner cluster musuh, asteroid, pickup,
# game over, restart. Musuh spawn sebagai CLUSTER (swarm mengelilingi
# Heavy) dan ramp kesulitan utamanya = jarak antar cluster yang makin
# rapat seiring waktu bertahan (dipercepat skor).

const SWARM_SCENE := preload("res://scenes/enemies/swarm_enemy.tscn")
const HEAVY_SCENE := preload("res://scenes/enemies/heavy_enemy.tscn")
const ASTEROID_SCENE := preload("res://scenes/asteroid.tscn")
const PICKUP_SCENE := preload("res://scenes/abilities/ability_pickup.tscn")
const AMMO_PICKUP_SCENE := preload("res://scenes/abilities/ammo_pickup.tscn")

var _cluster_timer: float = 1.5  # cluster pertama muncul cepat
var _asteroid_timer: float = 0.0
var _pickup_timer: float = 8.0   # drop pertama cepat supaya player segera kenal ability
var _next_pickup_is_singularity: bool = true
var _ammo_timer: float = 3.0     # amunisi pertama muncul lebih cepat dari ability
var _next_cluster_id: int = 0
var _elapsed: float = 0.0        # waktu bermain, untuk ramp spacing
var _game_over: bool = false

@onready var arena_border: Line2D = $ArenaBorder
@onready var player: CharacterBody2D = $Player
@onready var chain_manager: Node = $ChainManager
@onready var ui: CanvasLayer = $UI


func _ready() -> void:
	# Pulihkan kecepatan normal — restart bisa terjadi saat slow-motion
	# game over masih aktif (autoload Juice tidak ikut ke-reset).
	Engine.time_scale = 1.0
	Juice.base_time_scale = 1.0

	# Sambungkan sistem pusat: ChainManager -> UI, Player -> UI.
	chain_manager.score_changed.connect(ui.set_score)
	chain_manager.chain_changed.connect(ui.set_chain)
	chain_manager.chain_ended.connect(ui.on_chain_ended)
	player.hp_changed.connect(ui.set_hp)
	player.abilities_changed.connect(ui.set_abilities)
	player.ammo_changed.connect(ui.set_ammo)
	player.player_died.connect(_on_player_died)
	ui.set_hp(GameBalance.player_max_hp)
	ui.set_score(0)
	ui.set_abilities(false, false)
	ui.set_ammo(GameBalance.player_max_ammo, GameBalance.player_max_ammo)

	var w := GameBalance.arena_width
	var h := GameBalance.arena_height

	# Garis batas arena (bukan entity — boleh diatur dari kode).
	arena_border.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(w, 0),
		Vector2(w, h),
		Vector2(0, h),
		Vector2.ZERO,
	])

	player.global_position = Vector2(w, h) * 0.5
	# Cegah efek "meluncur" di frame pertama setelah player dipindah paksa.
	player.reset_physics_interpolation()


func _process(delta: float) -> void:
	if _game_over:
		return  # berhenti spawn; restart tetap bisa lewat _unhandled_input
	_elapsed += delta
	_cluster_timer -= delta
	if _cluster_timer <= 0.0:
		_cluster_timer = GameBalance.cluster_spawn_interval
		_try_spawn_cluster()
	if _elapsed >= GameBalance.asteroid_start_time:
		_asteroid_timer -= delta
		if _asteroid_timer <= 0.0:
			_asteroid_timer = GameBalance.asteroid_spawn_interval
			_try_spawn_asteroid()
	_pickup_timer -= delta
	if _pickup_timer <= 0.0:
		_pickup_timer = randf_range(
			GameBalance.ability_spawn_interval_min, GameBalance.ability_spawn_interval_max)
		_try_spawn_pickup()
	_ammo_timer -= delta
	if _ammo_timer <= 0.0:
		_ammo_timer = GameBalance.ammo_spawn_interval
		_try_spawn_ammo()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _on_player_died() -> void:
	_game_over = true
	AudioManager.play("game_over")
	# Slow-motion sesaat, lalu layar game over fade in.
	Juice.base_time_scale = GameBalance.game_over_slowmo_scale
	Engine.time_scale = GameBalance.game_over_slowmo_scale
	ui.show_game_over(chain_manager.score, chain_manager.highest_chain)
	await get_tree().create_timer(GameBalance.game_over_slowmo_time, true, false, true).timeout
	Juice.base_time_scale = 1.0
	Engine.time_scale = 1.0


# ---------------- CLUSTER SPAWNING ----------------

func _try_spawn_cluster() -> void:
	if _enemy_count() >= GameBalance.max_enemies:
		return
	var center := _find_cluster_center()
	var cid := _next_cluster_id
	_next_cluster_id += 1

	# Heavy: hanya SEBAGIAN cluster yang membawanya (cluster_heavy_chance),
	# jumlahnya di layar dibatasi, dan posisinya ditolak kalau terlalu
	# dekat Heavy lain. Tujuannya Heavy terbaca sebagai kejadian penting —
	# "ada Heavy di sana, itu pemicu chain-ku" — bukan hiasan latar.
	if _elapsed >= GameBalance.heavy_start_time \
			and randf() < GameBalance.cluster_heavy_chance \
			and _can_spawn_heavy_at(center):
		for i in GameBalance.cluster_heavy_max:
			if _enemy_count() >= GameBalance.max_enemies:
				return
			if _heavy_count() >= GameBalance.heavy_max_on_screen:
				break
			var heavy_off := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, 40.0)
			_spawn_one(HEAVY_SCENE, center + heavy_off, cid)

	# Swarm menyebar di sekeliling pusat cluster — tersebar sejak spawn,
	# bukan menumpuk di 1 titik; separation langsung merapikan sisanya.
	var swarm_count := randi_range(GameBalance.cluster_swarm_min, GameBalance.cluster_swarm_max)
	for i in swarm_count:
		if _enemy_count() >= GameBalance.max_enemies:
			return
		var off := Vector2.RIGHT.rotated(randf() * TAU) \
			* randf_range(25.0, GameBalance.cluster_spawn_radius)
		_spawn_one(SWARM_SCENE, center + off, cid)


func _spawn_one(scene: PackedScene, pos: Vector2, cid: int) -> void:
	var enemy := scene.instantiate()
	enemy.position = pos
	enemy.cluster_id = cid
	enemy.enemy_died.connect(chain_manager.on_enemy_died)
	add_child(enemy)
	enemy.reset_physics_interpolation()


func _enemy_count() -> int:
	return get_tree().get_nodes_in_group("enemies").size()


func _heavy_count() -> int:
	return get_tree().get_nodes_in_group("heavies").size()


# Heavy ditolak kalau kuota layar penuh atau ada Heavy lain terlalu dekat.
func _can_spawn_heavy_at(pos: Vector2) -> bool:
	if _heavy_count() >= GameBalance.heavy_max_on_screen:
		return false
	for h in get_tree().get_nodes_in_group("heavies"):
		var node := h as Node2D
		if node != null and node.global_position.distance_to(pos) < GameBalance.heavy_min_distance:
			return false
	return true


# Jarak minimal antar cluster: mulai renggang, makin rapat seiring waktu
# bertahan + skor. Late game chain bisa melompat antar cluster.
func _current_cluster_spacing() -> float:
	var t_time: float = _elapsed / GameBalance.cluster_spacing_ramp
	var t_score: float = float(chain_manager.score) / GameBalance.score_ramp_full
	var t := clampf(t_time + t_score, 0.0, 1.0)
	return lerpf(GameBalance.cluster_spacing_start, GameBalance.cluster_spacing_end, t)


# Cari titik tepi yang berjarak >= spacing dari semua musuh hidup.
# Kalau 10 percobaan gagal (arena penuh), pakai kandidat terjauh.
func _find_cluster_center() -> Vector2:
	var spacing := _current_cluster_spacing()
	var best := _random_edge_position()
	var best_nearest := -1.0
	for attempt in 10:
		var candidate := _random_edge_position()
		var nearest := INF
		for e in get_tree().get_nodes_in_group("enemies"):
			var node := e as Node2D
			if node != null:
				nearest = minf(nearest, candidate.distance_to(node.global_position))
		if nearest >= spacing:
			return candidate
		if nearest > best_nearest:
			best_nearest = nearest
			best = candidate
	return best


func _random_edge_position() -> Vector2:
	var w := GameBalance.arena_width
	var h := GameBalance.arena_height
	match randi() % 4:
		0:
			return Vector2(randf_range(0.0, w), 0.0)      # atas
		1:
			return Vector2(randf_range(0.0, w), h)        # bawah
		2:
			return Vector2(0.0, randf_range(0.0, h))      # kiri
		_:
			return Vector2(w, randf_range(0.0, h))        # kanan


# ---------------- ASTEROID & PICKUP ----------------

func _try_spawn_asteroid() -> void:
	if get_tree().get_nodes_in_group("asteroids").size() >= GameBalance.max_asteroids:
		return
	var asteroid := ASTEROID_SCENE.instantiate()
	var pos := _random_edge_position()
	asteroid.position = pos
	# Melayang ke arah tengah arena (dengan sedikit acak) supaya tidak
	# langsung memantul keluar-masuk di tepi.
	var target := Vector2(GameBalance.arena_width, GameBalance.arena_height) * 0.5 \
		+ Vector2(randf_range(-250.0, 250.0), randf_range(-250.0, 250.0))
	asteroid.velocity = (target - pos).normalized() * randf_range(
		GameBalance.asteroid_speed_min, GameBalance.asteroid_speed_max)
	asteroid.asteroid_destroyed.connect(chain_manager.on_asteroid_destroyed)
	add_child(asteroid)
	asteroid.reset_physics_interpolation()


func _try_spawn_pickup() -> void:
	if get_tree().get_nodes_in_group("pickups").size() >= GameBalance.ability_max_on_field:
		return
	var pickup := PICKUP_SCENE.instantiate()
	# Selang-seling supaya player selalu bisa melengkapi combo gather+detonate.
	pickup.ability_type = "singularity" if _next_pickup_is_singularity else "nuke"
	_next_pickup_is_singularity = not _next_pickup_is_singularity
	pickup.position = _random_inner_position()
	add_child(pickup)
	pickup.reset_physics_interpolation()


# Titik acak di dalam arena, menjauh dari tepi — dipakai semua pickup
# supaya selalu terlihat dan bisa dijangkau player.
func _random_inner_position() -> Vector2:
	var m := GameBalance.pickup_edge_margin
	return Vector2(
		randf_range(m, GameBalance.arena_width - m),
		randf_range(m, GameBalance.arena_height - m))


# Pickup amunisi: muncul acak di dalam arena, menjauh dari tepi supaya
# selalu terlihat dan bisa dijangkau. Memakai scene/logika pickup yang
# sama dengan ability (PickupBase), hanya beda grup dan efek ambilnya.
func _try_spawn_ammo() -> void:
	if get_tree().get_nodes_in_group("ammo_pickups").size() >= GameBalance.ammo_max_on_field:
		return
	var ammo := AMMO_PICKUP_SCENE.instantiate()
	ammo.position = _random_inner_position()
	add_child(ammo)
	ammo.reset_physics_interpolation()
