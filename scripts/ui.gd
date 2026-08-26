extends CanvasLayer

# HUD: HP kiri-atas, score tengah-atas, chain di bawah score.
# Indikator ability menyusul di Phase 6, layar game over di Phase 7.

@onready var hp_label: Label = $HPLabel
@onready var score_label: Label = $ScoreLabel
@onready var chain_label: Label = $ChainLabel

var _chain_fade_tween: Tween


func set_hp(hp: int) -> void:
	hp_label.text = "HP: %d" % maxi(hp, 0)


func set_score(score: int) -> void:
	score_label.text = "SCORE: %06d" % score


func set_chain(count: int) -> void:
	if count <= 0:
		return
	# Batalkan fade-out yang mungkin masih jalan dari chain sebelumnya.
	if _chain_fade_tween != null and _chain_fade_tween.is_valid():
		_chain_fade_tween.kill()
	chain_label.visible = true
	chain_label.modulate = Color.WHITE
	chain_label.text = "CHAIN x%d" % count

	# Warna dan ukuran naik seiring chain (di-cap supaya tidak menutupi layar).
	chain_label.add_theme_color_override("font_color", _chain_color(count))
	chain_label.add_theme_font_size_override("font_size", 20 + mini(count, 24))

	# Punch kecil tiap increment.
	chain_label.pivot_offset = chain_label.size / 2.0
	Juice.punch_scale(chain_label, 1.2, 0.15)


func on_chain_ended(_final_count: int, _highest: int) -> void:
	if not chain_label.visible:
		return
	_chain_fade_tween = chain_label.create_tween()
	_chain_fade_tween.tween_property(chain_label, "modulate:a", 0.0, 0.4)
	_chain_fade_tween.tween_callback(func() -> void:
		chain_label.visible = false
		chain_label.modulate = Color.WHITE
	)


func _chain_color(count: int) -> Color:
	if count < 5:
		return Color.WHITE
	if count < 10:
		return Color(1.0, 0.9, 0.3)
	if count < 20:
		return Color(1.0, 0.6, 0.15)
	return Color(1.0, 0.25, 0.2)
