extends PickupBase

# Pickup amunisi: kotak ABU-ABU, sengaja dibedakan dari pickup ability
# (biru/kuning) lewat warna DAN bentuk (memanjang, bukan bujur sangkar).
# Jauh lebih sering muncul daripada ability — ini bagian dari ritme
# normal permainan, bukan senjata langka.
# Selalu berhasil diambil dan langsung mengisi magasin sampai penuh.

const COLOR_AMMO := Color(0.72, 0.74, 0.78)


func _setup() -> void:
	pickup_group = "ammo_pickups"
	pickup_color = COLOR_AMMO


func _on_collected(player: Node2D) -> bool:
	player.refill_ammo(GameBalance.ammo_restore_amount)
	return true
