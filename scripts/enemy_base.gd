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


func _setup_stats() -> void:
	pass  # diisi subclass


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var to_player := _player.global_position - global_position
	var dir := to_player.normalized()
	global_position += dir * speed * delta
	visual.rotation = dir.angle() + PI / 2.0
	# Contact damage pakai cek jarak sederhana; invuln window player
	# yang mencegah damage beruntun tiap frame.
	if to_player.length() < contact_range and _player.has_method("take_damage"):
		_player.take_damage(contact_damage)


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
