extends Node

# =====================================================================
#  CHAIN MANAGER — sistem pusat chain reaction.
#
#  Alur: musuh mati → emit signal → ChainManager menerima → update
#  chain/score → menjadwalkan ledakan kematian (burst) yang bisa
#  membunuh musuh lain → kematian itu masuk ke sini lagi → kaskade.
#
#  Aturan chain: kill langsung oleh PELURU tidak menambah chain.
#  Chain hanya naik saat kematian disebabkan reaksi berantai
#  (burst/ledakan; nanti juga fragment asteroid & nuke). Ini yang
#  membuat chain terasa spesial saat damage MENJALAR antar objek.
# =====================================================================

signal score_changed(score: int)
signal chain_changed(count: int)
signal chain_ended(final_count: int, highest: int)

var score: int = 0
var chain_count: int = 0
var highest_chain: int = 0

var _chain_time_left: float = 0.0


func _process(delta: float) -> void:
	if chain_count > 0:
		_chain_time_left -= delta
		if _chain_time_left <= 0.0:
			_end_chain()


# Dipanggil (via signal) setiap ada musuh mati.
# depth = kedalaman chain dari kematian ini (0 = dibunuh langsung player /
# nuke / fragment / ledakan heavy). Burst dari kematian depth-d damage-nya
# meluruh (decay^d), dan korbannya mati dengan depth d+1 — chain punya
# akhir alami kecuali "di-recharge" oleh Heavy atau fragment.
func on_enemy_died(enemy_type: String, pos: Vector2, killed_by: String, depth: int) -> void:
	if killed_by != "bullet":
		_increment_chain(pos)

	# Skor: nilai dasar x chain saat ini (minimal x1).
	var base: int = GameBalance.score_heavy if enemy_type == "heavy" else GameBalance.score_swarm
	score += base * maxi(chain_count, 1)
	score_changed.emit(score)

	# Efek kematian + burst yang menular.
	if enemy_type == "heavy":
		# Ledakan Heavy MENGABAIKAN decay: damage penuh, depth di-reset ke 0.
		# Inilah alat "recharge" chain yang sedang sekarat.
		Juice.spawn_ring(pos, GameBalance.heavy_explosion_radius, Color(1.0, 0.6, 0.2, 1.0), 0.4)
		Juice.shake(GameBalance.shake_heavy_intensity, GameBalance.shake_heavy_duration)
		Juice.hitstop(GameBalance.hitstop_heavy)
		Juice.screen_flash(Color(1.0, 0.85, 0.6, 1.0), 0.2, 0.15)
		_schedule_explosion(pos, GameBalance.heavy_explosion_radius,
			GameBalance.heavy_explosion_damage, 0)
	else:
		Juice.spawn_ring(pos, GameBalance.swarm_death_burst_radius, Color(1.0, 0.45, 0.35, 1.0), 0.25)
		Juice.shake(GameBalance.shake_swarm_intensity, GameBalance.shake_swarm_duration)
		# Burst swarm meluruh sesuai kedalaman; berhenti di cap atau saat
		# damage-nya habis termakan decay.
		if depth < GameBalance.chain_max_depth:
			var burst_damage := int(round(
				GameBalance.swarm_death_burst_damage * pow(GameBalance.chain_damage_decay, depth)))
			if burst_damage >= 1:
				_schedule_explosion(pos, GameBalance.swarm_death_burst_radius,
					burst_damage, depth + 1)


# Dipanggil (via signal) setiap ada asteroid hancur.
# Fragment-nya di-spawn oleh asteroid sendiri; di sini urus chain/skor/juice.
func on_asteroid_destroyed(pos: Vector2, killed_by: String) -> void:
	if killed_by != "bullet":
		_increment_chain(pos)
	score += GameBalance.score_asteroid * maxi(chain_count, 1)
	score_changed.emit(score)
	Juice.spawn_ring(pos, 90.0, Color(0.75, 0.75, 0.8, 1.0), 0.3)
	Juice.shake(GameBalance.shake_asteroid_intensity, GameBalance.shake_asteroid_duration)


func _increment_chain(pos: Vector2) -> void:
	chain_count += 1
	highest_chain = maxi(highest_chain, chain_count)
	_chain_time_left = GameBalance.chain_time_window
	chain_changed.emit(chain_count)

	# Pitch naik seiring chain — sudah siap untuk audio asli.
	AudioManager.play("chain_increment", pos, 1.0 + minf(chain_count * 0.05, 1.0))

	if chain_count >= 2:
		var size := 18.0 + minf(chain_count * 1.5, 26.0)
		Juice.floating_text(pos, "x%d" % chain_count, _chain_color(chain_count), size)

	# Milestone: perayaan ekstra di tengah layar.
	if chain_count == 10 or chain_count == 20 or chain_count == 30:
		Juice.shake(8.0, 0.3)
		var msg := "GREAT!"
		if chain_count == 20:
			msg = "AMAZING!"
		elif chain_count == 30:
			msg = "INSANE!"
		var cam := get_viewport().get_camera_2d()
		if cam != null:
			Juice.floating_text(cam.get_screen_center_position(), msg, _chain_color(chain_count), 48.0)


func _end_chain() -> void:
	AudioManager.play("chain_end")
	chain_ended.emit(chain_count, highest_chain)
	chain_count = 0
	_chain_time_left = 0.0


# Ledakan area dengan jeda stagger kecil: mencegah kaskade raksasa
# membeku dalam satu frame, sekaligus membuatnya terbaca sebagai kaskade.
# next_depth = kedalaman chain untuk korban ledakan ini.
func _schedule_explosion(pos: Vector2, radius: float, damage: int, next_depth: int) -> void:
	await get_tree().create_timer(GameBalance.chain_stagger).timeout

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.global_position.distance_to(pos) <= radius:
			enemy.take_damage(damage, "chain", next_depth)

	# Asteroid juga ikut rusak oleh ledakan -> bisa memuntahkan fragment.
	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		if is_instance_valid(asteroid) and asteroid.global_position.distance_to(pos) <= radius:
			asteroid.take_damage(damage, "chain", next_depth)

	# Player ikut kena, tapi dikali self-damage multiplier (default 0.35).
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		if player.global_position.distance_to(pos) <= radius:
			player.take_damage(int(ceil(damage * GameBalance.player_self_damage_multiplier)))


# Warna chain: putih → kuning → oranye → merah.
func _chain_color(count: int) -> Color:
	if count < 5:
		return Color.WHITE
	if count < 10:
		return Color(1.0, 0.9, 0.3)
	if count < 20:
		return Color(1.0, 0.6, 0.15)
	return Color(1.0, 0.25, 0.2)
