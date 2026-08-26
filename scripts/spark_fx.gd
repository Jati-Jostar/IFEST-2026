extends Node2D

# 3 garis percikan kecil yang terbang keluar dari titik impact peluru.
# Efek visual murni (bukan entity gameplay).

const DURATION := 0.15
const SPARK_COUNT := 3

var _dirs: Array[Vector2] = []
var _t: float = 0.0


func setup(direction: Vector2) -> void:
	# Percikan memantul menjauh dari arah datang peluru.
	var back := -direction.normalized()
	for i in SPARK_COUNT:
		_dirs.append(back.rotated(randf_range(-0.8, 0.8)))


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := clampf(_t / DURATION, 0.0, 1.0)
	var dist := 4.0 + 34.0 * p
	var col := Color(1, 1, 0.8, 1.0 - p)
	for d in _dirs:
		draw_line(d * dist, d * (dist + 7.0), col, 2.0)
