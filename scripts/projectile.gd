extends Area2D

# Peluru player: lurus, umur terbatas, kena 1 target lalu hilang (tidak menembus).
# Kecepatan/damage/umur diatur di GameBalance (bagian PROJECTILE).

var direction: Vector2 = Vector2.RIGHT

var _life_left: float = 0.0
var _has_hit: bool = false

@onready var visual: Node2D = $Visual


func _ready() -> void:
	_life_left = GameBalance.projectile_lifetime
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * GameBalance.projectile_speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_hit(area)


func _hit(target: Node2D) -> void:
	# Hanya boleh kena SATU target (tidak menembus).
	if _has_hit:
		return
	_has_hit = true
	if target.has_method("take_damage"):
		target.take_damage(GameBalance.projectile_damage, "bullet")
		Juice.spawn_sparks(global_position, direction)
	queue_free()
