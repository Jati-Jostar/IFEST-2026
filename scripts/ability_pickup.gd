extends PickupBase

# Pickup ability: ikon Singularity atau ikon Nuke.
# Satu scene untuk dua tipe — spawner mengisi ability_type, lalu ikon
# yang sesuai ditampilkan dan yang lain disembunyikan.
# Kalau slot player untuk ability itu masih terisi, pickup dibiarkan
# di lapangan (tidak hilang, tidak hangus).

@export_enum("singularity", "nuke") var ability_type: String = "singularity"


func _setup() -> void:
	pickup_group = "pickups"
	# Ikon sudah berwarna sendiri — tidak perlu tint dari PickupBase.
	pickup_color = Color.WHITE
	_show_icon("IconSingularity", ability_type == "singularity")
	_show_icon("IconNuke", ability_type == "nuke")


# Dicari dengan aman: kalau artist menghapus/mengganti nama node ikon,
# pickup tetap berfungsi, cuma tanpa gambar itu.
func _show_icon(node_name: String, shown: bool) -> void:
	var icon := visual.get_node_or_null(node_name)
	if icon != null:
		icon.visible = shown


func _on_collected(player: Node2D) -> bool:
	return player.collect_ability(ability_type)
