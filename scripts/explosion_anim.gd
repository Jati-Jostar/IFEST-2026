extends Node2D

# Animasi ledakan berbasis AnimatedSprite2D.
#
# UNTUK ARTIST: yang perlu diganti HANYA resource SpriteFrames pada node
# "Anim". Nama animasinya harus tetap "explode" dan Loop harus MATI.
# Script ini tidak perlu disentuh sama sekali.

# Jumlah frame CADANGAN, hanya dipakai kalau SpriteFrames tidak terbaca.
# Normalnya jumlah frame dibaca langsung dari SpriteFrames, jadi mengubah
# jumlah frame di editor tidak akan bikin angka ini basi.
@export var frame_count: int = 5
@export var fps: float = 20.0            # kecepatan animasi (frame per detik)
@export var visual_scale: float = 1.0    # perbesar/perkecil tanpa mengubah art

@onready var anim: AnimatedSprite2D = $Anim


func _ready() -> void:
	anim.scale = Vector2.ONE * visual_scale
	var frames: int = frame_count

	if anim.sprite_frames != null and anim.sprite_frames.has_animation("explode"):
		anim.sprite_frames.set_animation_speed("explode", fps)
		frames = anim.sprite_frames.get_frame_count("explode")
		# WAJIB mulai dari frame 0. Kalau scene kebetulan tersimpan saat
		# editor sedang preview di frame terakhir, play() akan langsung
		# dianggap selesai dan ledakan tidak pernah terlihat sama sekali.
		anim.frame = 0
		anim.frame_progress = 0.0
		anim.play("explode")

	anim.animation_finished.connect(queue_free)

	# Pengaman: hapus diri walau animasi tidak pernah selesai
	# (misal SpriteFrames dari artist ternyata di-loop).
	var fallback: float = float(maxi(frames, 1)) / maxf(fps, 1.0) + 0.2
	await get_tree().create_timer(fallback).timeout
	queue_free()
