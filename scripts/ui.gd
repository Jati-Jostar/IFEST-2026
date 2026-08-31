extends CanvasLayer

# HUD: HP kiri-atas, score tengah-atas, chain di bawah score.
# Indikator ability menyusul di Phase 6, layar game over di Phase 7.

@onready var hp_label: Label = $HPLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var score_label: Label = $ScoreLabel
@onready var chain_label: Label = $ChainLabel
@onready var singularity_label: Label = $SingularityLabel
@onready var nuke_label: Label = $NukeLabel
@onready var game_over_panel: Control = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/Center/VBox/FinalScore
@onready var best_chain_label: Label = $GameOverPanel/Center/VBox/BestChain

const COLOR_READY_SINGULARITY := Color(0.45, 0.65, 1.0)
const COLOR_READY_NUKE := Color(1.0, 0.85, 0.3)
const COLOR_EMPTY := Color(0.45, 0.45, 0.5)
const COLOR_AMMO_OK := Color(0.85, 0.9, 1.0)
const COLOR_AMMO_LOW := Color(1.0, 0.75, 0.25)
const COLOR_AMMO_EMPTY := Color(1.0, 0.3, 0.25)

var _chain_fade_tween: Tween
var _ammo_blink_tween: Tween
var _sing_pulse: Tween
var _nuke_pulse: Tween


func set_hp(hp: int) -> void:
	hp_label.text = "HP: %d" % maxi(hp, 0)


# Amunisi harus terbaca sekilas tanpa mengalihkan mata dari aksi:
# putih = aman, kuning = tinggal sedikit, merah berkedip = habis.
func set_ammo(ammo: int, max_ammo: int) -> void:
	if _ammo_blink_tween != null and _ammo_blink_tween.is_valid():
		_ammo_blink_tween.kill()
	ammo_label.modulate = Color.WHITE

	if ammo <= 0:
		ammo_label.text = "AMMO: EMPTY"
		ammo_label.add_theme_color_override("font_color", COLOR_AMMO_EMPTY)
		# Berkedip terus selama kosong.
		_ammo_blink_tween = ammo_label.create_tween()
		_ammo_blink_tween.set_loops()
		_ammo_blink_tween.tween_property(ammo_label, "modulate:a", 0.25, 0.35)
		_ammo_blink_tween.tween_property(ammo_label, "modulate:a", 1.0, 0.35)
		return

	ammo_label.text = "AMMO: %d / %d" % [ammo, max_ammo]
	ammo_label.add_theme_color_override(
		"font_color", COLOR_AMMO_LOW if ammo <= 2 else COLOR_AMMO_OK)
	ammo_label.pivot_offset = ammo_label.size / 2.0
	Juice.punch_scale(ammo_label, 1.1, 0.12)


func set_score(score: int) -> void:
	score_label.text = "SCORE: %06d" % score


# Ability sangat langka, jadi statusnya TIDAK BOLEH bisa salah baca.
# Dipegang  : teks terang + penanda ● + berdenyut pelan + punch saat berubah.
# Kosong    : redup, cuma tanda "—", diam total.
func set_abilities(has_singularity: bool, has_nuke: bool) -> void:
	_sing_pulse = _style_ability_label(
		singularity_label, "[Q] SINGULARITY", has_singularity,
		COLOR_READY_SINGULARITY, _sing_pulse)
	_nuke_pulse = _style_ability_label(
		nuke_label, "[E] NUKE", has_nuke, COLOR_READY_NUKE, _nuke_pulse)


func _style_ability_label(label: Label, prefix: String, held: bool,
		ready_color: Color, pulse: Tween) -> Tween:
	if pulse != null and pulse.is_valid():
		pulse.kill()
	label.modulate = Color.WHITE

	if not held:
		label.text = "%s: —" % prefix
		label.add_theme_color_override("font_color", COLOR_EMPTY)
		return null

	label.text = "%s: READY ●" % prefix
	label.add_theme_color_override("font_color", ready_color)
	label.pivot_offset = label.size / 2.0
	Juice.punch_scale(label, 1.18, 0.18)
	# Denyut halus selama masih dipegang — mustahil terlewat sudut mata.
	var tw := label.create_tween()
	tw.set_loops()
	tw.tween_property(label, "modulate:a", 0.5, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	return tw


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


# Layar game over: fade in, bukan muncul mendadak.
func show_game_over(score: int, best_chain: int) -> void:
	final_score_label.text = "SCORE: %06d" % score
	best_chain_label.text = "BEST CHAIN: x%d" % best_chain
	game_over_panel.visible = true
	game_over_panel.modulate = Color(1, 1, 1, 0)
	var tw := game_over_panel.create_tween()
	tw.tween_property(game_over_panel, "modulate:a", 1.0, 0.6)


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
