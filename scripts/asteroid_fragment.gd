extends Area2D

# Pecahan asteroid: melesat keluar, berputar, umur pendek.
# Mengenai musuh -> musuh kena damage bersumber "fragment" (masuk chain).
# Mengenai player -> damage kecil penuh (tanpa multiplier — bukan ledakan).
# Hilang setelah kena 1 target atau umurnya habis.

var velocity: Vector2 = Vector2.ZERO

var _life_left: float = 1.0
var _has_hit: bool = false

@onready var visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("fragments")
	_life_left = GameBalance.fragment_lifetime
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Pilih satu varian tampilan secara acak, sembunyikan sisanya.
	var variants := visual.get_children()
	if variants.size() > 0:
		var pick := randi() % variants.size()
		for i in variants.size():
			variants[i].visible = (i == pick)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	visual.rotation += 8.0 * delta   # berputar jelas saat terbang
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _has_hit or not area.is_in_group("enemies"):
		return
	_has_hit = true
	AudioManager.play("fragment_hit", global_position)
	area.take_damage(GameBalance.fragment_damage, "fragment")
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _has_hit or not body.is_in_group("player"):
		return
	_has_hit = true
	AudioManager.play("fragment_hit", global_position)
	body.take_damage(GameBalance.fragment_damage)
	queue_free()
