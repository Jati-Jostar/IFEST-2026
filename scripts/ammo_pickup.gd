extends PickupBase

# Pickup amunisi (ikon peluru). Jauh lebih sering muncul daripada
# pickup ability — ini bagian dari ritme normal permainan, bukan
# senjata langka. Selalu berhasil diambil dan langsung mengisi magasin.


func _setup() -> void:
	pickup_group = "ammo_pickups"
	# Ikon sudah berwarna sendiri — tidak perlu tint dari PickupBase.
	pickup_color = Color.WHITE


func _on_collected(player: Node2D) -> bool:
	player.refill_ammo(GameBalance.ammo_restore_amount)
	return true
