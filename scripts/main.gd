extends Node2D

# Main scene: arena, posisi awal player, spawner musuh, restart.
# UI, chain system, dan game over screen menyusul di phase berikutnya.

const SWARM_SCENE := preload("res://scenes/enemies/swarm_enemy.tscn")
const HEAVY_SCENE := preload("res://scenes/enemies/heavy_enemy.tscn")
const ASTEROID_SCENE := preload("res://scenes/asteroid.tscn")

var _spawn_timer: float = 0.0
var _spawn_count: int = 0
var _asteroid_timer: float = 0.0

@onready var arena_border: Line2D = $ArenaBorder
@onready var player: CharacterBody2D = $Player
@onready var chain_manager: Node = $ChainManager
@onready var ui: CanvasLayer = $UI


func _ready() -> void:
	# Sambungkan sistem pusat: ChainManager -> UI, Player -> UI.
	chain_manager.score_changed.connect(ui.set_score)
	chain_manager.chain_changed.connect(ui.set_chain)
	chain_manager.chain_ended.connect(ui.on_chain_ended)
	player.hp_changed.connect(ui.set_hp)
	ui.set_hp(GameBalance.player_max_hp)
	ui.set_score(0)

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

	_spawn_timer = GameBalance.enemy_spawn_interval


func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = GameBalance.enemy_spawn_interval
		_try_spawn_enemy()
	_asteroid_timer -= delta
	if _asteroid_timer <= 0.0:
		_asteroid_timer = GameBalance.asteroid_spawn_interval
		_try_spawn_asteroid()


func _unhandled_input(event: InputEvent) -> void:
	# Restart sederhana untuk keperluan playtest (dipoles di Phase 7).
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _try_spawn_enemy() -> void:
	# Batasi jumlah musuh demi performa browser.
	if get_tree().get_nodes_in_group("enemies").size() >= GameBalance.max_enemies:
		return
	_spawn_count += 1
	if _spawn_count % GameBalance.heavy_spawn_every == 0:
		_spawn_one(HEAVY_SCENE, _random_edge_position())
	else:
		# Swarm muncul bergerombol dari satu titik — gerombolan = bahan chain.
		var center := _random_edge_position()
		var count := randi_range(GameBalance.swarm_group_min, GameBalance.swarm_group_max)
		var spread := GameBalance.swarm_group_spread
		for i in count:
			if get_tree().get_nodes_in_group("enemies").size() >= GameBalance.max_enemies:
				break
			var offset := Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
			_spawn_one(SWARM_SCENE, center + offset)


func _spawn_one(scene: PackedScene, pos: Vector2) -> void:
	var enemy := scene.instantiate()
	enemy.position = pos
	enemy.enemy_died.connect(chain_manager.on_enemy_died)
	add_child(enemy)
	enemy.reset_physics_interpolation()


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
