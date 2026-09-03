extends Node2D

# SINGULARITY — alat PENGUMPUL. Menarik swarm, heavy, asteroid, dan
# fragment ke pusatnya. TIDAK men-damage apa pun, TIDAK menarik player.
# Saat habis: objek berhenti ditarik, tetap di posisinya, tanpa ledakan.
# Tarikan makin kuat makin dekat ke pusat (tanpa fisika rumit).
#
# Seluruh tampilannya sekarang berasal dari animasi sprite di $Visual —
# tidak ada lagi lingkaran/garis yang digambar lewat kode.

const PULL_GROUPS: Array[String] = ["enemies", "asteroids", "fragments"]

var _time_left: float = 2.5
var _shake_timer: float = 0.0

@onready var visual: Node2D = $Visual


func _ready() -> void:
	_time_left = GameBalance.singularity_duration
	AudioManager.play("singularity_activate", global_position)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		AudioManager.stop("singularity_activate")
		queue_free()
		return

	# Visual: pulsing + rotasi pelan (diterapkan ke $Visual, siap art-swap).
	visual.rotation += 1.2 * delta
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() / 1000.0 * 9.0)
	visual.scale = Vector2.ONE * pulse

	# Getaran halus terus-menerus selama aktif — menjual rasa "gravitasi".
	_shake_timer -= delta
	if _shake_timer <= 0.0:
		_shake_timer = 0.15
		Juice.shake(1.0, 0.15)

	_pull_objects(delta)


func _pull_objects(delta: float) -> void:
	var radius: float = GameBalance.singularity_radius
	for group in PULL_GROUPS:
		for obj in get_tree().get_nodes_in_group(group):
			var node := obj as Node2D
			if node == null or not is_instance_valid(node):
				continue
			var to_center := global_position - node.global_position
			var dist := to_center.length()
			if dist > radius or dist < 6.0:
				continue
			# Makin dekat pusat, makin kencang tarikannya.
			var pull_speed: float = lerpf(
				GameBalance.singularity_pull_max,
				GameBalance.singularity_pull_min,
				dist / radius)
			node.global_position += to_center.normalized() * pull_speed * delta
