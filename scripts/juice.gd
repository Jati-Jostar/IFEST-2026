extends Node

# =====================================================================
#  JUICE (autoload) — screen shake, hitstop, flash, ring, floating text.
#  Semua script gameplay cukup memanggil satu baris, misal:
#      Juice.shake(6.0, 0.15)
#  Intensitas efek diatur lewat GameBalance (bagian JUICE).
# =====================================================================

const RING_SCENE := preload("res://scenes/fx/explosion_fx.tscn")
const SPARK_SCENE := preload("res://scenes/fx/spark_fx.tscn")
const TEXT_SCENE := preload("res://scenes/fx/floating_text.tscn")

const BASE_SHAKE_DECAY := 10.0   # peluruhan shake (intensitas/detik) saat idle
const HITSTOP_TIME_SCALE := 0.05

var _shake_strength: float = 0.0
var _shake_decay: float = BASE_SHAKE_DECAY
var _hitstop_end_ms: int = 0
var _hitstop_active: bool = false
var _active_fx: int = 0

var _flash_rect: ColorRect


func _ready() -> void:
	# Overlay untuk full-screen flash (di atas gameplay, di bawah tidak ada UI penting).
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash_rect)
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		if _shake_strength > 0.01:
			var s := _shake_strength * GameBalance.shake_global_multiplier
			cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * s
		else:
			cam.offset = Vector2.ZERO
	if _shake_strength > 0.0:
		_shake_strength = move_toward(_shake_strength, 0.0, _shake_decay * delta)
		if _shake_strength <= 0.0:
			_shake_decay = BASE_SHAKE_DECAY


# ---------------- SCREEN SHAKE (aditif + meluruh, di-clamp) ----------------

func shake(intensity: float, duration: float) -> void:
	_shake_strength = minf(_shake_strength + intensity, GameBalance.shake_max)
	_shake_decay = maxf(_shake_decay, intensity / maxf(duration, 0.05))


# ---------------- HITSTOP (tidak pernah menumpuk — ambil yang terpanjang) ----------------

func hitstop(duration: float) -> void:
	var end_ms := Time.get_ticks_msec() + int(duration * 1000.0)
	_hitstop_end_ms = maxi(_hitstop_end_ms, end_ms)
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = HITSTOP_TIME_SCALE
	while true:
		var remaining_ms := _hitstop_end_ms - Time.get_ticks_msec()
		if remaining_ms <= 0:
			break
		# Timer real-time (abaikan time_scale) supaya hitstop bisa berakhir.
		await get_tree().create_timer(remaining_ms / 1000.0, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


# ---------------- FLASH & PUNCH (pada $Visual sebuah entity) ----------------

func flash(node: CanvasItem, color: Color, duration: float) -> void:
	# Untuk kedip putih terang, kirim warna overbright, misal Color(6,6,6).
	if node == null or not is_instance_valid(node):
		return
	node.modulate = color
	var tw := node.create_tween()
	tw.tween_property(node, "modulate", Color.WHITE, duration)


func punch_scale(node: CanvasItem, amount: float, duration: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.scale = Vector2.ONE * amount
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK)


# ---------------- CAMERA ZOOM PUNCH ----------------

func punch_zoom(amount: float, duration: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	cam.zoom = Vector2.ONE * amount
	var tw := cam.create_tween()
	tw.tween_property(cam, "zoom", Vector2.ONE, duration)


# ---------------- FULL-SCREEN FLASH ----------------

func screen_flash(color: Color, strength: float, duration: float) -> void:
	_flash_rect.color = Color(color.r, color.g, color.b, strength)
	var tw := _flash_rect.create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, duration)


# ---------------- EFEK DUNIA (ring, spark, floating text) ----------------

func spawn_ring(position: Vector2, radius: float, color: Color, duration: float) -> void:
	if not _fx_slot_free():
		return
	var ring := RING_SCENE.instantiate()
	_track_fx(ring)
	ring.position = position
	get_tree().current_scene.add_child(ring)
	ring.reset_physics_interpolation()  # cegah muncul 1 frame di posisi salah
	ring.setup(radius, color, duration)


func spawn_sparks(position: Vector2, direction: Vector2) -> void:
	if not _fx_slot_free():
		return
	var spark := SPARK_SCENE.instantiate()
	_track_fx(spark)
	spark.position = position
	get_tree().current_scene.add_child(spark)
	spark.reset_physics_interpolation()
	spark.setup(direction)


func floating_text(position: Vector2, text: String, color: Color, size: float) -> void:
	if not _fx_slot_free():
		return
	var ft := TEXT_SCENE.instantiate()
	_track_fx(ft)
	ft.position = position
	get_tree().current_scene.add_child(ft)
	ft.reset_physics_interpolation()
	ft.setup(text, color, int(size))


func _fx_slot_free() -> bool:
	return _active_fx < GameBalance.max_fx_nodes and get_tree().current_scene != null


func _track_fx(fx: Node) -> void:
	_active_fx += 1
	fx.tree_exited.connect(func() -> void: _active_fx -= 1)
