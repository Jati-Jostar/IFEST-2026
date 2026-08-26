extends Node2D

# Background bintang sederhana supaya gerakan kamera/player selalu terlihat.
# Ini BUKAN entity gameplay — hanya latar. Artist nanti boleh menghapus
# node ini dan menggantinya dengan art background sungguhan.

const STAR_COUNT := 140
const STAR_SEED := 12345  # seed tetap supaya posisi bintang konsisten

var _stars: Array = []  # tiap item: [posisi, radius, alpha]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	for i in STAR_COUNT:
		_stars.append([
			Vector2(
				rng.randf_range(0.0, GameBalance.arena_width),
				rng.randf_range(0.0, GameBalance.arena_height)
			),
			rng.randf_range(1.0, 2.5),
			rng.randf_range(0.15, 0.55),
		])
	queue_redraw()


func _draw() -> void:
	for s in _stars:
		draw_circle(s[0], s[1], Color(0.7, 0.75, 0.9, s[2]))
