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
const HEAL_PICKUP_SCENE := preload("res://scenes/abilities/heal_pickup.tscn")
const WORM_SCENE := preload("res://scenes/enemies/space_worm.tscn")
const MENU_SCENE := "res://scenes/main_menu.tscn"

# Mode demo: scene ini juga dipakai sebagai latar hidup di main menu.
# Tanpa player, tanpa HUD, tanpa input, tanpa pickup. Musuh mengejar
# titik tak terlihat yang berkeliling pelan, dan sesekali satu swarm
# di kerumunan terpadat diledakkan otomatis supaya chain terlihat.
@export var demo_mode: bool = false

var _cluster_timer: float = 0.0  # diisi initial_spawn_delay di _ready
var _asteroid_timer: float = 0.0
var _pickup_timer: float = 0.0   # diisi ability_first_spawn_delay di _ready
var _next_pickup_is_singularity: bool = true
var _ammo_timer: float = 3.0     # amunisi pertama muncul lebih cepat dari ability
var _heal_timer: float = 15.0    # heal pertama tidak di awal run
var _next_cluster_id: int = 0
var _elapsed: float = 0.0        # waktu bermain, untuk ramp spacing
var _game_over: bool = false
var _leaving: bool = false
var _demo_chain_timer: float = 0.0
var _demo_target: Node2D
var _demo_waypoint: Vector2
var _worm_timer: float = 0.0     # jeda antar spawn worm
var _laser_was_ready: bool = false
var _paused: bool = false
var _game_speed: float = 1.0     # ramp chaos: naik tiap game_speed_score_step

@onready var arena_border: Line2D = $ArenaBorder
@onready var player: CharacterBody2D = $Player
@onready var chain_manager: Node = $ChainManager
@onready var ui: CanvasLayer = $UI


func _ready() -> void:
	# Pulihkan kecepatan normal — restart bisa terjadi saat slow-motion
	# game over masih aktif (autoload Juice tidak ikut ke-reset).
	Engine.time_scale = 1.0
	Juice.base_time_scale = 1.0

	if demo_mode:
		_setup_demo()
		return

	# Sambungkan sistem pusat: ChainManager -> UI, Player -> UI.
	chain_manager.score_changed.connect(ui.set_score)
	chain_manager.chain_changed.connect(ui.set_chain)
	chain_manager.chain_ended.connect(ui.on_chain_ended)
	player.hp_changed.connect(ui.set_hp)
	player.abilities_changed.connect(ui.set_abilities)
	player.ammo_changed.connect(ui.set_ammo)
	chain_manager.score_changed.connect(player.on_score_changed)
	chain_manager.score_changed.connect(_on_score_changed_speed)
	player.laser_changed.connect(ui.set_laser)
	player.laser_changed.connect(_on_laser_changed)
	player.laser_denied.connect(ui.flash_laser_denied)
	ui.resume_pressed.connect(_set_paused.bind(false))
	ui.restart_pressed.connect(_restart)
	ui.menu_pressed.connect(_to_menu)
	ui.pause_toggle_requested.connect(_toggle_pause)
	player.player_died.connect(_on_player_died)
	ui.set_hp(GameBalance.player_max_hp)
	ui.set_score(0)
	ui.set_abilities(false, false)
	ui.set_ammo(GameBalance.player_max_ammo, GameBalance.player_max_ammo)
	ui.set_laser(0.0, false)
	ui.set_speed(1.0)

	_draw_arena_border()

	player.global_position = Vector2(GameBalance.arena_width, GameBalance.arena_height) * 0.5
	# Cegah efek "meluncur" di frame pertama setelah player dipindah paksa.
	player.reset_physics_interpolation()

	# Lagu gameplay; kalau slotnya kosong, lagu menu lanjut tanpa jeda.
	AudioManager.play_music(AudioManager.game_music)
	_pickup_timer = GameBalance.ability_first_spawn_delay
	_next_pickup_is_singularity = not GameBalance.ability_first_is_nuke
	_cluster_timer = GameBalance.initial_spawn_delay
	ui.fade_in(GameBalance.gameover_fade_time)


# Garis batas arena (bukan entity — boleh diatur dari kode).
func _draw_arena_border() -> void:
	var w := GameBalance.arena_width
	var h := GameBalance.arena_height
	arena_border.points = PackedVector2Array([
		Vector2.ZERO,
		Vector2(w, 0),
		Vector2(w, h),
		Vector2(0, h),
		Vector2.ZERO,
	])


func _process(delta: float) -> void:
	if demo_mode:
		_process_demo(delta)
		return
	if _game_over:
		return  # berhenti spawn; tombol di layar game over tetap aktif
	_elapsed += delta
	_cluster_timer -= delta
	if _cluster_timer <= 0.0:
		_cluster_timer = _current_cluster_interval()
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
	_update_worm_spawning(delta)
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		_heal_timer = randf_range(
			GameBalance.heal_spawn_interval_min, GameBalance.heal_spawn_interval_max)
		_try_spawn_heal()


# ESC = buka/tutup layar jeda (event-nya datang dari UI, lihat ui.gd).
# Restart & keluar ke menu lewat TOMBOL, bukan tombol keyboard.
func _toggle_pause() -> void:
	if _leaving or demo_mode or _game_over:
		return
	_set_paused(not _paused)


# Jeda: pohon scene berhenti, layar jeda muncul (UI-nya process_mode
# ALWAYS jadi tombolnya tetap bisa diklik).
func _set_paused(paused: bool) -> void:
	if _leaving or _game_over:
		return
	_paused = paused
	get_tree().paused = paused
	ui.set_paused(paused)


func _restart() -> void:
	get_tree().paused = false
	_paused = false
	_leave(func() -> void: get_tree().reload_current_scene())


func _to_menu() -> void:
	get_tree().paused = false
	_paused = false
	_leave(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))


# Pindah scene selalu lewat fade gelap dulu.
# Rekor sudah tersimpan saat player mati, jadi aman keluar kapan saja.
func _leave(change_scene: Callable) -> void:
	_leaving = true
	await ui.fade_out(GameBalance.gameover_fade_time).finished
	Engine.time_scale = 1.0
	Juice.base_time_scale = 1.0
	change_scene.call()


# Ramp chaos: tiap game_speed_score_step skor, seluruh game berjalan
# game_speed_increment lebih cepat, sampai game_speed_max.
func _on_score_changed_speed(score: int) -> void:
	var steps := int(float(score) / float(GameBalance.game_speed_score_step))
	var speed := minf(1.0 + steps * GameBalance.game_speed_increment, GameBalance.game_speed_max)
	if is_equal_approx(speed, _game_speed):
		return
	_game_speed = speed
	ui.set_speed(speed)
	if not _game_over:
		Juice.set_base_time_scale(speed)


# Catatan playtest (hanya di build debug): kapan laser pertama kali READY,
# untuk menyetel laser_score_thresholds.
func _on_laser_changed(_progress: float, ready: bool) -> void:
	if ready and not _laser_was_ready and OS.is_debug_build():
		print("[LASER] READY  t=%.1f detik  skor=%d" % [_elapsed, chain_manager.score])
	_laser_was_ready = ready


func _on_player_died() -> void:
	_game_over = true
	# Hook tetap dipasang walau slot audionya sengaja kosong (lihat
	# audio_manager.gd) — aman dipanggil, dan siap kalau nanti diisi.
	AudioManager.play("game_over")
	# Slow-motion sesaat, lalu layar game over fade in.
	# Slow-motion game over memakai nilai absolut (tidak ikut ramp chaos).
	Juice.base_time_scale = GameBalance.game_over_slowmo_scale
	Engine.time_scale = GameBalance.game_over_slowmo_scale
	SaveData.submit_run(chain_manager.score, chain_manager.highest_chain)
	ui.show_game_over(chain_manager.score, chain_manager.highest_chain,
		SaveData.last_new_high_score, SaveData.last_new_best_chain)
	await get_tree().create_timer(GameBalance.game_over_slowmo_time, true, false, true).timeout
	# Kembali ke kecepatan ramp yang sedang berlaku, bukan selalu 1.0.
	Juice.set_base_time_scale(_game_speed)


# ---------------- CLUSTER SPAWNING ----------------

func _try_spawn_cluster() -> void:
	var swarm_cap := _current_swarm_cap()
	if _swarm_count() >= swarm_cap:
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
			# Kuota Heavy penuh: lewati Heavy saja, JANGAN batalkan swarm-nya.
			if _heavy_count() >= GameBalance.heavy_max_on_screen:
				break
			var heavy_off := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, 40.0)
			_spawn_one(HEAVY_SCENE, center + heavy_off, cid)

	# Swarm menyebar di sekeliling pusat cluster — tersebar sejak spawn,
	# bukan menumpuk di 1 titik; separation langsung merapikan sisanya.
	var swarm_count := randi_range(GameBalance.cluster_swarm_min, GameBalance.cluster_swarm_max)
	for i in swarm_count:
		if _swarm_count() >= swarm_cap:
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


func _swarm_count() -> int:
	return get_tree().get_nodes_in_group("swarms").size()


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


# Batas swarm hidup SAAT INI: naik bertahap dari max_swarms_start ke
# max_swarms_end, murni mengikuti SKOR (bukan waktu bertahan).
func _current_swarm_cap() -> int:
	var t := clampf(
		float(chain_manager.score) / maxf(GameBalance.max_swarms_ramp_score, 0.001), 0.0, 1.0)
	return int(round(lerpf(GameBalance.max_swarms_start, GameBalance.max_swarms_end, t)))


# Kesulitan 0..1 dari waktu bertahan + total skor.
func _difficulty() -> float:
	var t_time: float = _elapsed / GameBalance.cluster_spacing_ramp
	var t_score: float = float(chain_manager.score) / GameBalance.score_ramp_full
	return clampf(t_time + t_score, 0.0, 1.0)


# Jarak minimal antar cluster: mulai renggang, makin rapat seiring waktu
# bertahan + skor. Late game chain bisa melompat antar cluster.
func _current_cluster_spacing() -> float:
	return lerpf(GameBalance.cluster_spacing_start, GameBalance.cluster_spacing_end, _difficulty())


# Jeda spawn cluster ikut memendek seiring kesulitan — kepadatan naik
# di atas ramp jarak antar cluster.
func _current_cluster_interval() -> float:
	return lerpf(
		GameBalance.cluster_spawn_interval, GameBalance.cluster_spawn_interval_min, _difficulty())


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


# Heal hanya muncul kalau HP player sedang kurang — kalau penuh, dicoba
# lagi sebentar kemudian supaya arena tidak penuh pickup yang tak terpakai.
func _try_spawn_heal() -> void:
	if get_tree().get_nodes_in_group("heal_pickups").size() >= GameBalance.heal_max_on_field:
		return
	if player.hp >= GameBalance.player_max_hp:
		_heal_timer = 5.0
		return
	var heal := HEAL_PICKUP_SCENE.instantiate()
	heal.position = _random_inner_position()
	add_child(heal)
	heal.reset_physics_interpolation()


# ---------------- SPACE WORM ----------------

# Batas worm bersamaan dari skor: 0 sebelum worm_first_score, lalu 1,
# +1 tiap worm_score_step, maksimal worm_max_cap.
func _allowed_worm_count() -> int:
	var s: int = chain_manager.score
	if s < GameBalance.worm_first_score:
		return 0
	var steps := int(float(s - GameBalance.worm_first_score) / float(GameBalance.worm_score_step))
	return mini(1 + steps, GameBalance.worm_max_cap)


# Timer sendiri, kuota sendiri — tidak pernah memperlambat spawn lain.
func _update_worm_spawning(delta: float) -> void:
	_worm_timer -= delta
	if _worm_timer > 0.0:
		return
	if get_tree().get_nodes_in_group("worms").size() >= _allowed_worm_count():
		return
	_worm_timer = GameBalance.worm_spawn_cooldown
	_spawn_worm()


# Muncul di tepi arena, cukup jauh dari player supaya tidak langsung
# menerjang dari jarak dekat. Kalau tidak ketemu, pakai titik terjauh.
func _spawn_worm() -> void:
	var best := _random_edge_position()
	var best_dist := -1.0
	for attempt in 10:
		var candidate := _random_edge_position()
		var d := candidate.distance_to(player.global_position)
		if d >= GameBalance.worm_spawn_min_player_distance:
			best = candidate
			break
		if d > best_dist:
			best_dist = d
			best = candidate
	var worm := WORM_SCENE.instantiate()
	worm.position = best
	worm.worm_died.connect(chain_manager.on_worm_died)
	add_child(worm)
	worm.reset_physics_interpolation()


# ---------------- ASTEROID & PICKUP ----------------

func _try_spawn_asteroid() -> void:
	if get_tree().get_nodes_in_group("asteroids").size() >= GameBalance.asteroid_max_on_screen:
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


# ---------------- MODE DEMO (latar main menu) ----------------

func _setup_demo() -> void:
	var w := GameBalance.arena_width
	var h := GameBalance.arena_height
	var center := Vector2(w, h) * 0.5
	_draw_arena_border()

	chain_manager.show_milestones = false
	$Background.set_static()

	# Player & HUD tidak dipakai di demo.
	player.queue_free()
	ui.queue_free()
	# Player sudah di-queue_free tapi masih ada di grup sampai akhir frame;
	# keluarkan sekarang supaya musuh tidak mengincarnya.
	player.remove_from_group("player")

	# Target tak terlihat yang dikejar musuh. Tidak punya take_damage(),
	# jadi semua kode "melukai player" otomatis melewatinya.
	_demo_target = Node2D.new()
	_demo_target.name = "DemoTarget"
	_demo_target.position = center
	_demo_target.add_to_group("player")
	add_child(_demo_target)
	_demo_waypoint = center

	# Kamera diam di tengah, di-zoom out supaya sebagian besar arena terlihat.
	var cam := Camera2D.new()
	cam.position = center
	cam.zoom = Vector2.ONE * GameBalance.menu_demo_camera_zoom
	add_child(cam)
	cam.make_current()

	_cluster_timer = 0.0  # langsung isi layar
	_demo_chain_timer = GameBalance.menu_demo_chain_interval


func _process_demo(delta: float) -> void:
	_elapsed += delta
	_cluster_timer -= delta
	if _cluster_timer <= 0.0:
		_cluster_timer = _current_cluster_interval()
		_try_spawn_cluster()
	if _elapsed >= GameBalance.asteroid_start_time:
		_asteroid_timer -= delta
		if _asteroid_timer <= 0.0:
			_asteroid_timer = GameBalance.asteroid_spawn_interval
			_try_spawn_asteroid()

	# Target berkeliling pelan di sekitar tengah arena.
	var to_wp := _demo_waypoint - _demo_target.position
	if to_wp.length() < 10.0:
		var center := Vector2(GameBalance.arena_width, GameBalance.arena_height) * 0.5
		_demo_waypoint = center + Vector2.RIGHT.rotated(randf() * TAU) \
			* randf_range(0.0, GameBalance.menu_demo_wander_radius)
	else:
		_demo_target.position += to_wp.normalized() \
			* minf(GameBalance.menu_demo_wander_speed * delta, to_wp.length())

	_demo_chain_timer -= delta
	if _demo_chain_timer <= 0.0:
		_demo_chain_timer = GameBalance.menu_demo_chain_interval
		_trigger_demo_chain()


# Ledakkan swarm yang tetangganya paling banyak -> kaskade paling panjang.
# Sumber "demo" (bukan "bullet"), jadi ChainManager menghitungnya sebagai
# chain sungguhan lengkap dengan floating text x2, x3, ...
func _trigger_demo_chain() -> void:
	var swarms := get_tree().get_nodes_in_group("swarms")
	if swarms.is_empty():
		return
	swarms.shuffle()
	var radius := GameBalance.swarm_death_burst_radius
	var best: Node2D = null
	var best_neighbors := -1
	for i in mini(swarms.size(), 25):
		var s := swarms[i] as Node2D
		if s == null:
			continue
		var n := 0
		for other in swarms:
			var o := other as Node2D
			if o != null and o != s and o.global_position.distance_to(s.global_position) < radius:
				n += 1
		if n > best_neighbors:
			best_neighbors = n
			best = s
	if best != null and best.has_method("take_damage"):
		best.take_damage(9999, "demo", 0)
