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
	_player = get_tree().get_first_node_in_group("player")
	_sep_frame_offset = randi() % maxi(GameBalance.separation_update_interval, 1)


func _setup_stats() -> void:
	pass  # diisi subclass


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
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


# Dorong keluar kalau tumpang tindih dengan badan Heavy. Heavy jumlahnya
# dibatasi (heavy_max_on_screen), jadi loop ini murah.
func _push_out_of_heavies() -> void:
	for h in get_tree().get_nodes_in_group("heavies"):
		var heavy := h as EnemyBase
		if heavy == null or heavy == self:
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


# Satu loop untuk dua hal (hemat CPU):
# - separation: dorong-menjauh dari tetangga terdekat, makin dekat makin kuat
# - cohesion: tarikan lembut ke pusat (centroid) anggota cluster sendiri
func _update_separation() -> void:
	_separation = Vector2.ZERO
	_cohesion = Vector2.ZERO
	var centroid := Vector2.ZERO
	var members := 0
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var node := other as EnemyBase
		if node == null:
			continue
		if cluster_id >= 0 and node.cluster_id == cluster_id:
			centroid += node.global_position
			members += 1

		# Heavy tidak terdorong oleh swarm — dia menerjang, swarm yang
		# mengalir menghindarinya. Antar-Heavy tetap saling mendorong.
		if enemy_type == "heavy" and node.enemy_type != "heavy":
			continue

		# Jarak minimal dihitung dari ukuran badan KEDUANYA, jadi
		# swarm berhenti di luar badan Heavy tanpa merenggangkan
		# jarak antar sesama swarm.
		var min_dist := body_radius + node.body_radius + GameBalance.separation_padding
		var diff := global_position - node.global_position
		var dist := diff.length()
		if dist >= min_dist:
			continue
		if dist < 1.0:
			# Persis bertumpuk: dorong ke arah acak supaya bisa terpisah.
			_separation += Vector2.RIGHT.rotated(randf() * TAU)
		else:
			_separation += diff.normalized() * (1.0 - dist / min_dist)
	if members > 0:
		_cohesion = (centroid / float(members) - global_position).normalized()


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
	# Feedback kena hit (hanya kalau masih hidup).
	Juice.flash(visual, Color(6, 6, 6), GameBalance.hit_flash_duration)
	Juice.punch_scale(visual, GameBalance.hit_punch_amount, GameBalance.hit_punch_duration)


func die(killed_by: String = "bullet", depth: int = 0) -> void:
	AudioManager.play(death_audio_event, global_position)
	enemy_died.emit(enemy_type, global_position, killed_by, depth)
	queue_free()
