extends Node

# MAIN MENU — scene pertama saat game dibuka.
# Satu tombol (Space / tombol apa pun) langsung masuk ke game.
# Tata letak:
#   - 3 langkah inti (tembak → giring → ledakkan) SELALU tampil di tengah:
#     di itch.io / laptop pameran banyak orang main di browser yang sama,
#     jadi pemain berikutnya tetap harus melihat onboarding-nya.
#   - rekor (skor tertinggi & chain terbaik) tampil kecil di pojok kanan
#     atas, hanya kalau sudah ada rekor.

const GAME_SCENE := "res://scenes/main.tscn"

@onready var first_time_block: Control = %FirstTimeBlock
@onready var records_block: Control = %RecordsBlock
@onready var high_score_value: Label = %HighScoreValue
@onready var best_chain_value: Label = %BestChainValue
@onready var prompt: Label = %Prompt

var _input_delay: float = 0.0
var _starting: bool = false


func _ready() -> void:
	# Jaga-jaga kalau datang dari game over yang masih slow-motion.
	Engine.time_scale = 1.0
	Juice.base_time_scale = 1.0
	_input_delay = GameBalance.menu_input_delay

	# Musik sudah jalan dari AudioManager; panggilan ini tidak me-restart
	# lagu yang sama, hanya memastikan volumenya naik kalau sempat di-fade.
	AudioManager.play_music()

	# Demo gameplay di belakang: diredupkan oleh Background (warna menu
	# semi-transparan) dan SFX-nya dipelankan.
	var bg: ColorRect = $MenuUI/Background
	bg.color.a = 1.0 - GameBalance.menu_demo_dim
	AudioManager.set_sfx_volume_db(GameBalance.menu_demo_sfx_volume_db)

	# Masuk dengan fade dari gelap (pasangan fade-out di layar game over).
	var fader: ColorRect = $MenuUI/Fader
	var tw := fader.create_tween()
	tw.tween_property(fader, "color:a", 0.0, GameBalance.gameover_fade_time)
	tw.tween_callback(fader.hide)

	_refresh_records()
	_pulse_prompt()


func _process(delta: float) -> void:
	_input_delay -= delta


func _refresh_records() -> void:
	var returning := SaveData.has_records()
	first_time_block.visible = true
	records_block.visible = returning
	if returning:
		high_score_value.text = SaveData.format_thousands(SaveData.high_score)
		best_chain_value.text = "x%d" % SaveData.best_chain


func _pulse_prompt() -> void:
	var half := GameBalance.menu_prompt_pulse_time * 0.5
	var tw := prompt.create_tween()
	tw.set_loops()
	tw.tween_property(prompt, "modulate:a", 0.35, half).set_trans(Tween.TRANS_SINE)
	tw.tween_property(prompt, "modulate:a", 1.0, half).set_trans(Tween.TRANS_SINE)


func _unhandled_input(event: InputEvent) -> void:
	if _starting or _input_delay > 0.0:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	_starting = true
	get_viewport().set_input_as_handled()
	get_tree().change_scene_to_file(GAME_SCENE)


func _exit_tree() -> void:
	# Keluar dari menu -> volume SFX kembali normal untuk gameplay.
	AudioManager.apply_bus_volumes()
