extends Area2D
class_name PickupBase

# Dasar SEMUA pickup (ability & amunisi): diam di arena, berdenyut pelan,
# diambil dengan cara disentuh player. Subclass hanya mengisi warna,
# nama grup, dan apa yang terjadi saat diambil — logikanya satu tempat.
#
# Warna diterapkan lewat modulate pada $Visual (bukan placeholder-nya
# langsung), jadi tetap bekerja setelah art di-swap.

var pickup_group: String = "pickups"    # diisi subclass di _setup()
var pickup_color: Color = Color.WHITE   # diisi subclass di _setup()

@onready var visual: Node2D = $Visual


func _ready() -> void:
	_setup()
	add_to_group(pickup_group)
	visual.modulate = pickup_color
	body_entered.connect(_on_body_entered)

	# Denyut pelan supaya menarik perhatian.
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(visual, "scale", Vector2.ONE * 1.2, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(visual, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


# Subclass mengisi pickup_group dan pickup_color di sini.
func _setup() -> void:
	pass


# Kembalikan true kalau pickup boleh hilang (berhasil diambil).
func _on_collected(_player: Node2D) -> bool:
	return false


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if _on_collected(body):
		AudioManager.play("pickup_collect", global_position)
		queue_free()
