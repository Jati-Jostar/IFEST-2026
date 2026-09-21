extends Control

# PENANDA ANCAMAN — panah kecil di tepi layar yang menunjuk ke bahaya
# di LUAR pandangan. Arena (1600x1200) lebih besar dari layar, jadi tanpa
# ini pemain sering mati oleh sesuatu yang tidak pernah terlihat datang.
#
# Yang ditandai:
#   - tiap Heavy          (bom chain, harus dicari pemain)
#   - tiap Space Worm     (bahaya besar)
#   - tiap CLUSTER swarm  (satu panah per cluster, bukan per swarm —
#                          kalau per swarm, layar penuh panah)
#
# Digambar lewat kode di koordinat layar. Posisi target dihitung ulang
# tiap threat_indicator_update_frames frame supaya murah walau musuh banyak.

const COLOR_HEAVY := Color(1.0, 0.45, 0.3)
const COLOR_WORM := Color(0.55, 0.9, 0.3)
const COLOR_SWARM := Color(0.95, 0.3, 0.3)

# [posisi dunia, warna] untuk tiap target di luar layar.
var _targets: Array = []
var _frame: int = 0


func _process(_delta: float) -> void:
	_frame += 1
	if _frame % maxi(GameBalance.threat_indicator_update_frames, 1) == 0:
		_collect_targets()
		queue_redraw()


func _collect_targets() -> void:
	_targets.clear()
	for h in get_tree().get_nodes_in_group("heavies"):
		var node := h as Node2D
		if node != null:
			_targets.append([node.global_position, COLOR_HEAVY])
	for w in get_tree().get_nodes_in_group("worms"):
		var node := w as Node2D
		if node != null:
			_targets.append([node.global_position, COLOR_WORM])

	# Swarm dikelompokkan per cluster_id -> satu panah per kerumunan.
	var sums: Dictionary = {}
	var counts: Dictionary = {}
	for s in get_tree().get_nodes_in_group("swarms"):
		var node := s as Node2D
		if node == null:
			continue
		var cid: int = node.get("cluster_id")
		sums[cid] = sums.get(cid, Vector2.ZERO) + node.global_position
		counts[cid] = int(counts.get(cid, 0)) + 1
	for cid in sums:
		_targets.append([sums[cid] / float(counts[cid]), COLOR_SWARM])


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var screen := size
	var center := screen * 0.5
	var cam_center := cam.get_screen_center_position()
	var zoom := cam.zoom.x
	var m := GameBalance.threat_indicator_margin
	var m_top := GameBalance.threat_indicator_margin_top
	# Sisi atas lebih longgar supaya panah tidak menabrak SCORE & CHAIN.
	var rect := Rect2(Vector2(m, m_top), Vector2(screen.x - m * 2.0, screen.y - m_top - m))

	for t in _targets:
		var world: Vector2 = t[0]
		# Dunia -> layar (kamera selalu di tengah layar).
		var pos := (world - cam_center) * zoom + center
		if rect.has_point(pos):
			continue  # masih terlihat, tidak perlu panah
		var dir := (pos - center)
		if dir.length() < GameBalance.threat_indicator_min_distance:
			continue
		dir = dir.normalized()
		_draw_arrow(_clamp_to_rect(rect.get_center(), dir, rect), dir, t[1])


# Titik potong sinar dari tengah layar ke tepi kotak penanda.
func _clamp_to_rect(center: Vector2, dir: Vector2, rect: Rect2) -> Vector2:
	var half := rect.size * 0.5
	var scale_x := half.x / maxf(absf(dir.x), 0.0001)
	var scale_y := half.y / maxf(absf(dir.y), 0.0001)
	return center + dir * minf(scale_x, scale_y)


# Segitiga menunjuk ke arah `dir`, dengan ekor sedikit memudar.
func _draw_arrow(at: Vector2, dir: Vector2, color: Color) -> void:
	var s := GameBalance.threat_indicator_size
	var side := dir.orthogonal()
	var tip := at + dir * s
	var a := at - dir * s * 0.6 + side * s * 0.7
	var b := at - dir * s * 0.6 - side * s * 0.7
	draw_colored_polygon(PackedVector2Array([tip, a, b]), color)
	draw_line(at - dir * s * 0.6, at - dir * s * 1.7, Color(color.r, color.g, color.b, 0.4), 3.0)
