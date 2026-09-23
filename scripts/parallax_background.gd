extends Node2D

# Background parallax 5 layer (Layer1 = deep space paling jauh).
# Tiap anak berisi satu Sprite2D 1600x1200 (= ukuran arena).
# Kecepatan geser tiap layer diambil dari
# GameBalance.parallax_scroll_scales supaya bisa disetel tanpa buka scene.
#
# Posisi layer dihitung SENDIRI di sini, tidak memakai Parallax2D bawaan:
# Parallax2D mengira layar selalu seukuran viewport dan mengabaikan zoom
# kamera. Begitu kamera di-zoom out (camera_zoom 0.9), layer jauh meleset
# puluhan piksel dan tepi gambarnya terlihat — tampak seperti map terpotong
# di sisi kiri/atas.
#
# Rumusnya: layer_pos = sudut_kiri_atas_layar x (1 - scroll_scale).
# Bagian gambar yang terlihat lalu bergeser sejauh
# (arena - layar) x scroll_scale, yang selalu <= (arena - layar).
# Jadi gambar seukuran arena selalu cukup, berapa pun zoom dan scale-nya.

# Bintang kecil bergerak subpiksel; nearest membuatnya tampak meloncat.
# Matikan di Inspector jika ingin kembali ke tampilan pixel yang tajam.
@export var smooth_distant_stars: bool = true

var _layers: Array[Node2D] = []
var _scales: Array[float] = []


func _ready() -> void:
	var distant_stars := get_node_or_null("Layer2/Sprite") as Sprite2D
	if distant_stars != null and smooth_distant_stars:
		distant_stars.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# Posisi di-set di _physics_process, jadi biarkan interpolasi fisika aktif (default).

	var scales := GameBalance.parallax_scroll_scales
	var i := 0
	for child in get_children():
		var layer := child as Node2D
		if layer == null:
			continue
		_layers.append(layer)
		_scales.append(scales[i] if i < scales.size() else 1.0)
		i += 1


func _physics_process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	# Ukuran area yang BENAR-BENAR terlihat (viewport dibagi zoom).
	var view_size := get_viewport_rect().size / cam.zoom
	var top_left := cam.get_screen_center_position() - view_size * 0.5
	for i in _layers.size():
		_layers[i].position = top_left * (1.0 - _scales[i])


# Dipakai demo main menu: kameranya diam, jadi parallax tidak terlihat.
# Semua layer ditempelkan ke dunia supaya pasti tidak ada celah di tepi.
func set_static() -> void:
	for i in _scales.size():
		_scales[i] = 1.0
