extends Area2D

# Pickup ability: biru = Singularity, kuning = Nuke.
# Player menyentuh untuk mengambil. Kalau slot player untuk ability itu
# masih terisi, pickup dibiarkan (tidak hilang).
# Warna diterapkan lewat modulate pada $Visual (bukan placeholder-nya
# langsung), jadi tetap bekerja setelah art di-swap.

const COLOR_SINGULARITY := Color(0.3, 0.55, 1.0)
const COLOR_NUKE := Color(1.0, 0.85, 0.2)

@export_enum("singularity", "nuke") var ability_type: String = "singularity"

@onready var visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("pickups")
	visual.modulate = COLOR_SINGULARITY if ability_type == "singularity" else COLOR_NUKE
	body_entered.connect(_on_body_entered)

	# Denyut pelan supaya menarik perhatian.
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(visual, "scale", Vector2.ONE * 1.2, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(visual, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body.collect_ability(ability_type):
		AudioManager.play("pickup_collect", global_position)
		queue_free()
