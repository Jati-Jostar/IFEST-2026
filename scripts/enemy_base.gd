extends Area2D
class_name EnemyBase

# Dasar semua musuh: HP, mengejar player, contact damage, mati.
# Subclass (swarm/heavy) mengisi stat dari GameBalance lewat _setup_stats().
# Musuh sengaja pakai Area2D + gerak langsung (bukan physics body) demi
# performa di browser — cukup untuk gameplay arcade ini.
#
# Kematian TIDAK diproses di sini — musuh hanya emit signal enemy_died;
# ChainManager yang mengurus chain, skor, dan ledakan berantai.

signal enemy_died(enemy_type: String, pos: Vector2, killed_by: String)

# Override cepat per-scene saat playtest (0 = pakai nilai GameBalance).
@export var hp_override: int = 0
@export var speed_override: float = 0.0

var enemy_type: String = "swarm"
var max_hp: int = 10
var speed: float = 100.0
var contact_damage: int = 5
var contact_range: float = 26.0          # jarak pusat-ke-pusat yang dihitung "menyentuh player"
var death_audio_event: String = "swarm_death"

var hp: int = 1
var _player: Node2D
var _separation: Vector2 = Vector2.ZERO   # cache gaya dorong-menjauh dari tetangga
var _sep_frame_offset: int = 0            # sebar beban update antar frame

@onready var visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("enemies")
	_setup_stats()
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

	var final_dir := (chase_dir + _separation * GameBalance.separation_weight).normalized()
	global_position += final_dir * speed * delta
	# Visual tetap menghadap player (arah niat), bukan arah geser separation.
	visual.rotation = chase_dir.angle() + PI / 2.0

	# Contact damage pakai cek jarak sederhana; invuln window player
	# yang mencegah damage beruntun tiap frame.
	if to_player.length() < contact_range and _player.has_method("take_damage"):
		_player.take_damage(contact_damage)


# Gaya dorong-menjauh dari tetangga terdekat: makin dekat makin kuat.
func _update_separation() -> void:
	_separation = Vector2.ZERO
	var radius: float = GameBalance.separation_radius
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var node := other as Node2D
		if node == null:
			continue
		var diff := global_position - node.global_position
		var dist := diff.length()
		if dist >= radius:
			continue
		if dist < 1.0:
			# Persis bertumpuk: dorong ke arah acak supaya bisa terpisah.
			_separation += Vector2.RIGHT.rotated(randf() * TAU)
		else:
			_separation += diff.normalized() * (1.0 - dist / radius)


func take_damage(amount: int, source: String = "bullet") -> void:
	if hp <= 0:
		return
	hp -= amount
	if hp <= 0:
		die(source)
		return
	# Feedback kena hit (hanya kalau masih hidup).
	Juice.flash(visual, Color(6, 6, 6), GameBalance.hit_flash_duration)
	Juice.punch_scale(visual, GameBalance.hit_punch_amount, GameBalance.hit_punch_duration)


func die(killed_by: String = "bullet") -> void:
	AudioManager.play(death_audio_event, global_position)
	enemy_died.emit(enemy_type, global_position, killed_by)
	queue_free()
