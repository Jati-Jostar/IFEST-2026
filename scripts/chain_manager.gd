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

const EXPLOSION_SMALL := preload("res://scenes/fx/explosion_small.tscn")
const EXPLOSION_HEAVY := preload("res://scenes/fx/explosion_heavy.tscn")

signal score_changed(score: int)
signal chain_changed(count: int)
signal chain_ended(final_count: int, highest: int)

var score: int = 0
var chain_count: int = 0
var highest_chain: int = 0
# Teks milestone (GREAT!/AMAZING!/INSANE!) muncul di TENGAH layar.
# Dimatikan di demo menu supaya tidak menimpa judul & teks menu.
var show_milestones: bool = true

var _chain_time_left: float = 0.0


# Jendela chain dihitung dalam WAKTU NYATA, bukan waktu permainan.
# delta di sini sudah dikali Engine.time_scale, jadi saat ramp chaos
# menaikkan kecepatan ke 2x, jendela 2 detik ikut menyusut jadi 1 detik
# nyata — combo putus dua kali lebih cepat justru saat layar paling ramai.
# Membaginya kembali dengan time_scale mengembalikan durasi aslinya, dan
# ini juga benar saat hitstop (time_scale 0.05): waktu nyata tetap jalan.
func _process(delta: float) -> void:
	if chain_count > 0:
		_chain_time_left -= delta / maxf(Engine.time_scale, 0.001)
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
		Juice.spawn_fx(EXPLOSION_HEAVY, pos)
		Juice.spawn_ring(pos, GameBalance.heavy_explosion_radius, Color(1.0, 0.6, 0.2, 1.0), 0.4)
		Juice.shake(GameBalance.shake_heavy_intensity, GameBalance.shake_heavy_duration)
		Juice.hitstop(GameBalance.hitstop_heavy)
		Juice.screen_flash(Color(1.0, 0.85, 0.6, 1.0), 0.2, 0.15)
		_schedule_explosion(pos, GameBalance.heavy_explosion_radius,
			GameBalance.heavy_explosion_damage, 0)
	else:
		# Animasi ledakan (sprite) + ring kode: dua lapis, masing-masing
		# bisa diatur sendiri. Artist cukup mengganti SpriteFrames-nya.
		Juice.spawn_fx(EXPLOSION_SMALL, pos)
		# Ring pakai jatah terbatas: saat puluhan mati serempak, ring yang
		# dilewati lebih dulu — animasi di atas selalu kebagian slot.
		Juice.spawn_ring(pos, GameBalance.swarm_death_burst_radius,
			Color(1.0, 0.45, 0.35, 1.0), 0.25, GameBalance.fx_ring_budget)
		# SENGAJA tanpa screen shake: dengan puluhan swarm mati per detik,
		# shake kecil terus-menerus bikin pusing dan menenggelamkan momen
		# besar. Shake disimpan untuk Heavy, Nuke, asteroid, dan player kena.
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


# Dipanggil (via signal) saat Space Worm mati. Kematian worm SENDIRI tidak
# menambah chain (worm bukan umpan chain), tapi ledakan GARIS sepanjang
# badannya mereset depth ke 0 — sama seperti Heavy — jadi worm yang mati
# melintang di atas kerumunan bisa memicu kaskade penuh.
func on_worm_died(body_points: Array[Vector2], _killed_by: String) -> void:
	if body_points.is_empty():
		return
	score += GameBalance.score_worm * maxi(chain_count, 1)
	score_changed.emit(score)

	# Juice = gabungan swarm + Heavy, tapi berbentuk GARIS:
	# - kilatan garis hijau transparan sepanjang badan (di bawah semuanya)
	# - tiap ruas: animasi ledakan kecil + ring jangkauan (seperti swarm)
	# - kepala: animasi ledakan besar + ring besar + screen flash (seperti Heavy)
	Juice.spawn_line(body_points, GameBalance.worm_explosion_width,
		Color(0.75, 1.0, 0.45, GameBalance.worm_explosion_flash_alpha),
		GameBalance.worm_explosion_flash_time)
	for p in body_points:
		Juice.spawn_fx(EXPLOSION_SMALL, p)
		Juice.spawn_ring(p, GameBalance.worm_explosion_width * 0.5,
			Color(1.0, 0.6, 0.25, 1.0), GameBalance.worm_ring_duration)
	var head_pos: Vector2 = body_points[0]
	Juice.spawn_fx(EXPLOSION_HEAVY, head_pos)
	Juice.spawn_ring(head_pos, GameBalance.worm_explosion_width,
		Color(0.85, 1.0, 0.45, 1.0), GameBalance.worm_ring_duration + 0.1)
	Juice.screen_flash(Color(0.85, 1.0, 0.6, 1.0), 0.2, 0.15)
	Juice.shake(GameBalance.shake_worm_intensity, GameBalance.shake_worm_duration)
	Juice.hitstop(GameBalance.hitstop_worm)
	_schedule_line_explosion(body_points, GameBalance.worm_explosion_width * 0.5,
		GameBalance.worm_explosion_damage, 0)

func _increment_chain(pos: Vector2) -> void:
	chain_count += 1
	highest_chain = maxi(highest_chain, chain_count)
	_chain_time_left = GameBalance.chain_time_window
	chain_changed.emit(chain_count)

	# Pitch naik seiring chain — sudah siap untuk audio asli.
	AudioManager.play("chain_increment", pos, 1.0 + minf(chain_count * 0.05, 1.0))

	if chain_count >= 2:
		var size := 18.0 + minf(chain_count * 1.5, 26.0)
		# Angka "xN" per kematian pakai jatah paling kecil: saat puluhan mati
		# serempak, puluhan angka bertumpuk juga tidak terbaca. Yang harus
		# selalu muncul adalah animasi ledakannya.
		Juice.floating_text(pos, "x%d" % chain_count, _chain_color(chain_count), size,
			GameBalance.fx_text_budget)

	# Milestone: perayaan ekstra di tengah layar.
	if show_milestones and (chain_count == 10 or chain_count == 20 or chain_count == 30):
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

	# Jarak diukur sampai TEPI badan target, bukan titik pusatnya. Tanpa ini
	# objek besar seperti Heavy jadi kebal: swarm berhenti di luar badannya,
	# jadi pusat Heavy selalu di luar jangkauan burst.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var e := enemy as EnemyBase
		if e != null and e.global_position.distance_to(pos) - e.body_radius <= radius:
			e.take_damage(damage, "chain", next_depth)

	# Asteroid juga ikut rusak oleh ledakan -> bisa memuntahkan fragment.
	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		var a := asteroid as Node2D
		if a != null and a.global_position.distance_to(pos) - a.body_radius <= radius:
			a.take_damage(damage, "chain", next_depth)

	# Space Worm ikut kena, diukur ke bagian badan terdekat. Damage-nya TIDAK
	# ikut meluruh (min worm_min_chain_damage), jadi tiap ledakan yang
	# menimpa worm terasa. Kalau mati, ledakan garisnya menyambung chain.
	for worm in get_tree().get_nodes_in_group("worms"):
		var w := worm as SpaceWorm
		if w != null and w.distance_to_body(pos) <= radius:
			w.take_damage(maxi(damage, GameBalance.worm_min_chain_damage), "chain", next_depth)

	# Player ikut kena, tapi dikali self-damage multiplier (default 0.35).
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		if player.global_position.distance_to(pos) <= radius:
			player.take_damage(int(ceil(damage * GameBalance.player_self_damage_multiplier)))


# Versi GARIS dari _schedule_explosion: area kena = semua titik yang
# jaraknya ke garis badan (polyline) <= half_width. Target & aturan sama
# persis: kill = event chain biasa lewat take_damage(..., "chain", depth).
func _schedule_line_explosion(points: Array[Vector2], half_width: float,
		damage: int, next_depth: int) -> void:
	await get_tree().create_timer(GameBalance.chain_stagger).timeout

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var e := enemy as EnemyBase
		if e != null and _distance_to_polyline(e.global_position, points) - e.body_radius <= half_width:
			e.take_damage(damage, "chain", next_depth)

	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		var a := asteroid as Node2D
		if a != null and _distance_to_polyline(a.global_position, points) - a.body_radius <= half_width:
			a.take_damage(damage, "chain", next_depth)

	for worm in get_tree().get_nodes_in_group("worms"):
		var w := worm as SpaceWorm
		if w != null and _polyline_to_worm(points, w) <= half_width:
			w.take_damage(maxi(damage, GameBalance.worm_min_chain_damage), "chain", next_depth)

	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and player.has_method("take_damage"):
		if _distance_to_polyline(player.global_position, points) <= half_width:
			player.take_damage(int(ceil(damage * GameBalance.player_self_damage_multiplier)))


# Jarak terdekat antara garis ledakan dan badan worm (kepala/ruas mana pun).
func _polyline_to_worm(points: Array[Vector2], w: SpaceWorm) -> float:
	var best := INF
	for bp in w.get_body_points():
		best = minf(best, _distance_to_polyline(bp, points))
	return best


func _distance_to_polyline(p: Vector2, points: Array[Vector2]) -> float:
	if points.size() == 1:
		return p.distance_to(points[0])
	var best := INF
	for i in points.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
		best = minf(best, p.distance_to(c))
	return best

# Warna chain: putih → kuning → oranye → merah.
func _chain_color(count: int) -> Color:
	if count < 5:
		return Color.WHITE
	if count < 10:
		return Color(1.0, 0.9, 0.3)
	if count < 20:
		return Color(1.0, 0.6, 0.15)
	return Color(1.0, 0.25, 0.2)
