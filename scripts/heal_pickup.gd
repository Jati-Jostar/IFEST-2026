extends PickupBase

# Pickup HEAL (tanda plus hijau): memulihkan heal_amount HP saat disentuh.
# Hanya bisa diambil kalau HP belum penuh — kalau penuh, pickup dibiarkan
# di lapangan untuk nanti (sama seperti pickup ability saat slot penuh).


func _setup() -> void:
	pickup_group = "heal_pickups"
	# Placeholder sudah berwarna sendiri — tidak perlu tint dari PickupBase.
	pickup_color = Color.WHITE


func _on_collected(player: Node2D) -> bool:
	return player.heal(GameBalance.heal_amount)
