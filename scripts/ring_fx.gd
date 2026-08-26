extends Node2D

# Ring ledakan yang mengembang lalu memudar. Efek visual murni (bukan
# entity gameplay), jadi boleh digambar lewat _draw().

var _radius: float = 50.0
var _color: Color = Color.WHITE
var _duration: float = 0.25
var _t: float = 0.0


func setup(radius: float, color: Color, duration: float) -> void:
	_radius = radius
	_color = color
	_duration = maxf(duration, 0.05)


func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p := clampf(_t / _duration, 0.0, 1.0)
	var ease_out := 1.0 - (1.0 - p) * (1.0 - p)   # cepat di awal, melambat di akhir
	var r := maxf(_radius * ease_out, 1.0)
	var alpha := 1.0 - p
	var width := lerpf(6.0, 1.5, p)               # garis menipis saat membesar
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(_color.r, _color.g, _color.b, alpha), width)
