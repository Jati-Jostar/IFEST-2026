extends Node2D

# Background parallax 5 layer (Layer1 = deep space paling jauh).
# Tiap anak adalah Parallax2D berisi satu Sprite2D 1600x1200 (= ukuran
# arena). Kecepatan geser tiap layer diambil dari
# GameBalance.parallax_scroll_scales supaya bisa disetel tanpa buka scene.
#
# Kenapa gambar selalu menutupi layar: posisi layer = posisi kamera x
# (1 - scroll_scale), jadi bagian yang terlihat bergeser sejauh
# (arena - layar) x scroll_scale <= arena - layar. Gambar seukuran arena
# selalu cukup, berapa pun scroll_scale di antara 0 dan 1.


func _ready() -> void:
	var scales := GameBalance.parallax_scroll_scales
	var i := 0
	for child in get_children():
		var layer := child as Parallax2D
		if layer == null:
			continue
		if i < scales.size():
			layer.scroll_scale = Vector2.ONE * scales[i]
		i += 1


# Dipakai demo main menu: kameranya diam & di-zoom out, sedangkan
# Parallax2D tidak memperhitungkan zoom (layer jauh jadi bergeser dan
# menyisakan celah di tepi). Kamera diam = parallax tidak terlihat, jadi
# cukup tempelkan semua layer ke dunia.
func set_static() -> void:
	for child in get_children():
		var layer := child as Parallax2D
		if layer != null:
			layer.scroll_scale = Vector2.ONE
