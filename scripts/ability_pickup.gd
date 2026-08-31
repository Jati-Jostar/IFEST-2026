extends PickupBase

# Pickup ability: biru = Singularity, kuning = Nuke.
# Kalau slot player untuk ability itu masih terisi, pickup dibiarkan
# di lapangan (tidak hilang, tidak hangus).

const COLOR_SINGULARITY := Color(0.3, 0.55, 1.0)
const COLOR_NUKE := Color(1.0, 0.85, 0.2)

@export_enum("singularity", "nuke") var ability_type: String = "singularity"


func _setup() -> void:
	pickup_group = "pickups"
	pickup_color = COLOR_SINGULARITY if ability_type == "singularity" else COLOR_NUKE


func _on_collected(player: Node2D) -> bool:
	return player.collect_ability(ability_type)
