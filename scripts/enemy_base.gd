extends Area2D
class_name EnemyBase

# Dasar semua musuh: HP, mengejar player, contact damage, mati.
# Subclass (swarm/heavy) mengisi stat dari GameBalance lewat _setup_stats().
# Musuh sengaja pakai Area2D + gerak langsung (bukan physics body) demi
# performa di browser — cukup untuk gameplay arcade ini.
#
# Kematian TIDAK diproses di sini — musuh hanya emit signal enemy_died;
# ChainManager yang mengurus chain, skor, dan ledakan berantai.

signal enemy_died(enemy_type: String, pos: Vector2, killed_by: String, depth: int)

# Override cepat per-scene saat playtest (0 = pakai nilai GameBalance).
@export var hp_override: int = 0
@export var speed_override: float = 0.0

var enemy_type: String = "swarm"
var max_hp: int = 10
var speed: float = 100.0
var contact_damage: int = 5
var contact_range: float = 26.0          # jarak pusat-ke-pusat yang dihitung "menyentuh player"
var body_radius: float = 14.0            # ukuran badan untuk jarak anti-tumpuk (diisi subclass)
var death_audio_event: String = "swarm_death"

var hp: int = 1
var cluster_id: int = -1                  # cluster asal (-1 = tanpa cluster), diisi spawner
var _player: Node2D
var _separation: Vector2 = Vector2.ZERO   # cache gaya dorong-menjauh dari tetangga
var _cohesion: Vector2 = Vector2.ZERO     # cache tarikan ke pusat cluster sendiri
var _sep_frame_offset: int = 0            # sebar beban update antar frame

@onready var visual: Node2D = $Visual
# Bar HP opsional: hanya ada di musuh bernyawa tebal (mis. Heavy). Musuh
# tanpa node "HealthBar" tetap jalan normal.
@onready var health_bar: Node2D = get_node_or_null("HealthBar")

var _bar_width: float = 0.0
var _chip_tween: Tween


func _ready() -> void:
	add_to_group("enemies")
	_setup_stats()
	if enemy_type == "heavy":
		add_to_group("heavies")   # dipakai spawner untuk membatasi jumlah & jarak antar-Heavy
	else:
		add_to_group("swarms")    # kuota swarm dihitung terpisah dari Heavy
	if hp_override > 0:
		max_hp = hp_override
	if speed_override > 0.0:
		speed = speed_override
	hp = max_hp
	if health_bar != null:
		_bar_width = (health_bar.get_node("Fill") as ColorRect).size.x
	_player = get_tree().get_first_node_in_group("player")
	# Musuh tidak perlu MENDETEKSI apa pun (collision_mask sudah 0) — peluru
	# dan ledakan yang mencari musuh, bukan sebaliknya. Mematikan monitoring
	# mengeluarkan ratusan Area2D dari pass deteksi physics tiap frame.
	monitoring = false
	_sep_frame_offset = randi() % maxi(GameBalance.separation_update_interval, 1)

# ---------------- DATA BERSAMA PER FRAME (performa) ----------------
# Separation dulunya O(n^2): tiap musuh me-loop SEMUA musuh lewat
# get_nodes_in_group(). Di 300 musuh itu ~10.000 perbandingan per frame
# fisika PLUS ratusan Array baru dialokasikan tiap frame.
#
# Sekarang data yang sama dihitung SEKALI per frame fisika, lalu dipakai
# bersama semua musuh:
#   _grid          -> musuh dikelompokkan per sel; tetangga dicari di 3x3 sel
#   _cluster_sum/_count -> total posisi & jumlah per cluster (untuk cohesion)
#   _heavies       -> daftar Heavy (jumlahnya kecil, dipakai apa adanya)
#
# Hasilnya IDENTIK, bukan aproksimasi: pasangan yang kini dilewati adalah
# pasangan yang kontribusinya memang NOL karena jaraknya di luar min_dist.
# Satu-satunya beda: posisi dibaca dari satu snapshot di awal frame, bukan
# saat musuh lain sudah bergerak beberapa piksel di frame yang sama.
const GRID_CELL := 80.0   # harus >= radius interaksi terbesar yang lewat grid
						  # (swarm 14 + heavy 60 + padding 2 = 76)
static var _frame_stamp: int = -1
static var _grid: Dictionary = {}
static var _cluster_sum: Dictionary = {}
static var _cluster_count: Dictionary = {}
# Sel sendiri + 8 tetangga, dibuat sekali (range() bikin Array baru tiap
# dipanggil — mahal di loop panas). EMPTY_BUCKET dipakai sebagai nilai
# default Dictionary.get() dengan alasan yang sama.
const CELL_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]
const EMPTY_BUCKET: Array[EnemyBase] = []

static var _heavies: Array = []


static func _refresh_frame_data(tree: SceneTree) -> void:
	var stamp := Engine.get_physics_frames()
	if _frame_stamp == stamp:
		return
	_frame_stamp = stamp
	_grid.clear()
	_cluster_sum.clear()
	_cluster_count.clear()
	_heavies = tree.get_nodes_in_group("heavies")
	for n in tree.get_nodes_in_group("enemies"):
		var e := n as EnemyBase
		if e == null:
			continue
		# Cohesion menghitung SEMUA anggota cluster, termasuk Heavy.
		if e.cluster_id >= 0:
			_cluster_sum[e.cluster_id] = \
				_cluster_sum.get(e.cluster_id, Vector2.ZERO) + e.global_position
			_cluster_count[e.cluster_id] = int(_cluster_count.get(e.cluster_id, 0)) + 1
		# Grid hanya untuk musuh biasa — Heavy ditangani lewat _heavies.
		if e.enemy_type == "heavy":
			continue
		var cell := Vector2i(
			floori(e.global_position.x / GRID_CELL),
			floori(e.global_position.y / GRID_CELL))
		var bucket: Array[EnemyBase] = _grid.get(cell, EMPTY_BUCKET)
		if bucket.is_empty():
			bucket = []
			_grid[cell] = bucket
		bucket.append(e)


func _setup_stats() -> void:
	pass  # diisi subclass


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	# Data bersama (grid, centroid cluster, daftar Heavy) dibangun sekali
	# per frame oleh musuh mana pun yang pertama sampai di sini.
	_refresh_frame_data(get_tree())
	var to_player := _player.global_position - global_position
	var chase_dir := to_player.normalized()

	# Separation dihitung ulang hanya tiap N frame, bergiliran antar musuh,
	# supaya tetap ringan dengan 60+ musuh di browser.
	var interval: int = maxi(GameBalance.separation_update_interval, 1)
	if (Engine.get_physics_frames() + _sep_frame_offset) % interval == 0:
		_update_separation()

	var final_dir := (chase_dir
		+ _separation * GameBalance.separation_weight
		+ _cohesion * GameBalance.cluster_cohesion_weight).normalized()
	global_position += final_dir * speed * delta
	# Visual tetap menghadap player (arah niat), bukan arah geser separation.
	visual.rotation = chase_dir.angle() + PI / 2.0

	# Jaminan keras: swarm tidak boleh berada DI DALAM badan Heavy.
	# Gaya dorong saja kadang kalah oleh dorongan mengejar player, dan
	# kalau swarm tembus ke dalam Heavy, animasi kematian/ledakannya
	# tertutup badan Heavy. Di sini posisinya didorong balik ke tepi.
	if enemy_type != "heavy":
		_push_out_of_heavies()

	# Contact damage pakai cek jarak sederhana; invuln window player
	# yang mencegah damage beruntun tiap frame.
	if to_player.length() < contact_range and _player.has_method("take_damage"):
		_player.take_damage(contact_damage)
# Dorong keluar kalau tumpang tindih dengan badan Heavy. Tetap dijalankan
# TIAP frame (ini jaminan keras, bukan estetika), tapi daftar Heavy-nya
# diambil dari cache bersama supaya tidak bikin Array baru per musuh.
func _push_out_of_heavies() -> void:
	for h in _heavies:
		var heavy := h as EnemyBase
		if heavy == null or heavy == self or not is_instance_valid(heavy):
			continue
		var min_dist := heavy.body_radius + body_radius
		var diff := global_position - heavy.global_position
		var dist := diff.length()
		if dist >= min_dist:
			continue
		if dist < 0.01:
			# Persis di titik yang sama: pilih arah keluar acak.
			diff = Vector2.RIGHT.rotated(randf() * TAU)
			dist = 1.0
		global_position = heavy.global_position + diff / dist * min_dist


# Dua hal sekaligus, keduanya dari data bersama yang sudah dihitung
# sekali per frame (lihat _refresh_frame_data):
# - cohesion : tarikan ke centroid cluster sendiri -> dari total per cluster
# - separation: dorong-menjauh dari tetangga dekat -> dari 3x3 sel grid
func _update_separation() -> void:
	_separation = Vector2.ZERO
	_cohesion = Vector2.ZERO

	# Centroid cluster = (total anggota - diri sendiri) / (jumlah - 1).
	if cluster_id >= 0:
		var members: int = int(_cluster_count.get(cluster_id, 0)) - 1
		if members > 0:
			var sum: Vector2 = _cluster_sum.get(cluster_id, Vector2.ZERO)
			var centroid := (sum - global_position) / float(members)
			_cohesion = (centroid - global_position).normalized()

	# Heavy hanya terdorong sesama Heavy, dan jumlah Heavy kecil — jadi
	# tidak perlu lewat grid sama sekali. Heavy juga bisa berjarak sampai
	# 122 px (60+60+2), lebih lebar dari satu sel grid.
	if enemy_type == "heavy":
		for h in _heavies:
			_accumulate_separation(h as EnemyBase)
		return

	# Musuh biasa: Heavy diperiksa dari daftar (sedikit), sesama swarm
	# dari sel sendiri + 8 sel tetangga.
	# Musuh biasa: Heavy diperiksa dari daftar (sedikit), sesama swarm
	# dari sel sendiri + 8 sel tetangga.
	for h in _heavies:
		_accumulate_separation(h as EnemyBase)

	# Loop di bawah ini SENGAJA ditulis "mentah" (tanpa memanggil
	# _accumulate_separation, tanpa range(), tanpa Vector2): inilah satu-
	# satunya bagian yang berjalan puluhan ribu kali per detik. Pengukuran
	# menunjukkan biayanya didominasi overhead pemanggilan fungsi GDScript,
	# bukan matematikanya. Bentuk rapi disimpan di _accumulate_separation
	# yang dipakai jalur Heavy — logikanya sama persis.
	var pos := global_position
	var min_self := body_radius + GameBalance.separation_padding
	var cx := floori(pos.x / GRID_CELL)
	var cy := floori(pos.y / GRID_CELL)
	for off in CELL_OFFSETS:
		var bucket: Array[EnemyBase] = _grid.get(Vector2i(cx + off.x, cy + off.y), EMPTY_BUCKET)
		for other: EnemyBase in bucket:
			if other == self:
				continue
			var min_dist := min_self + other.body_radius
			var o := other.global_position
			var dx := pos.x - o.x
			var dy := pos.y - o.y
			var d2 := dx * dx + dy * dy
			if d2 >= min_dist * min_dist:
				continue
			if d2 < 1.0:
				# Persis bertumpuk: dorong ke arah acak supaya bisa terpisah.
				_separation += Vector2.RIGHT.rotated(randf() * TAU)
				continue
			var dist := sqrt(d2)
			var push := (1.0 - dist / min_dist) / dist
			_separation.x += dx * push
			_separation.y += dy * push


# Satu pasangan. sqrt hanya dihitung untuk tetangga yang benar-benar
# bersentuhan — sisanya ditolak lewat perbandingan kuadrat.
func _accumulate_separation(node: EnemyBase) -> void:
	if node == null or node == self or not is_instance_valid(node):
		return
	var min_dist := body_radius + node.body_radius + GameBalance.separation_padding
	var diff := global_position - node.global_position
	var d2 := diff.length_squared()
	if d2 >= min_dist * min_dist:
		return
	if d2 < 1.0:
		# Persis bertumpuk: dorong ke arah acak supaya bisa terpisah.
		_separation += Vector2.RIGHT.rotated(randf() * TAU)
		return
	var dist := sqrt(d2)
	_separation += diff / dist * (1.0 - dist / min_dist)



# depth = kedalaman chain dari sumber damage (0 = langsung dari player;
# burst kedalaman-d membunuh dengan depth d+1). Dipakai ChainManager
# untuk meluruhkan damage burst berikutnya.
func take_damage(amount: int, source: String = "bullet", depth: int = 0) -> void:
	if hp <= 0:
		return
	hp -= amount
	if hp <= 0:
		die(source, depth)
		return
	_update_health_bar()
	# Feedback kena hit (hanya kalau masih hidup).
	Juice.flash(visual, Color(6, 6, 6), GameBalance.hit_flash_duration)
	Juice.punch_scale(visual, GameBalance.hit_punch_amount, GameBalance.hit_punch_duration)


# Bar merah langsung turun; bar putih menyusul -> damage bertubi terbaca.
func _update_health_bar() -> void:
	if health_bar == null:
		return
	health_bar.visible = true
	var fill := health_bar.get_node("Fill") as ColorRect
	var chip := health_bar.get_node("Chip") as ColorRect
	fill.size.x = _bar_width * clampf(float(hp) / float(max_hp), 0.0, 1.0)
	if _chip_tween != null and _chip_tween.is_valid():
		_chip_tween.kill()
	_chip_tween = create_tween()
	_chip_tween.tween_interval(GameBalance.healthbar_chip_delay)
	_chip_tween.tween_property(chip, "size:x", fill.size.x,
		GameBalance.healthbar_chip_time).set_ease(Tween.EASE_OUT)


func die(killed_by: String = "bullet", depth: int = 0) -> void:
	AudioManager.play(death_audio_event, global_position)
	enemy_died.emit(enemy_type, global_position, killed_by, depth)
	queue_free()
