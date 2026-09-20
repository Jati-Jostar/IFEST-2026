extends Node

# MAIN MENU — scene pertama saat game dibuka.
# Tata letak:
#   - 3 langkah inti (tembak → giring → ledakkan) SELALU tampil di tengah:
#     di itch.io / laptop pameran banyak orang main di browser yang sama,
#     jadi pemain berikutnya tetap harus melihat onboarding-nya.
#   - rekor (skor tertinggi & chain terbaik) tampil kecil di pojok kanan
#     atas, hanya kalau sudah ada rekor.
#   - tombol MULAI & OPTIONS. Options berisi volume musik & efek suara,
#     tersimpan lewat SaveData (ikut tersimpan di browser).

const GAME_SCENE := "res://scenes/main.tscn"

@onready var first_time_block: Control = %FirstTimeBlock
@onready var records_block: Control = %RecordsBlock
@onready var high_score_value: Label = %HighScoreValue
@onready var best_chain_value: Label = %BestChainValue
@onready var main_buttons: Control = %MainButtons
@onready var start_button: Button = %StartButton
@onready var options_button: Button = %OptionsButton
@onready var options_panel: Control = %OptionsPanel
@onready var back_button: Button = %BackButton
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_value: Label = %SfxValue

var _starting: bool = false


func _ready() -> void:
	# Jaga-jaga kalau datang dari game over yang masih slow-motion.
	Engine.time_scale = 1.0
	Juice.base_time_scale = 1.0
	get_tree().paused = false

	# Musik sudah jalan dari AudioManager; panggilan ini tidak me-restart
	# lagu yang sama, hanya memastikan volumenya naik kalau sempat di-fade.
	AudioManager.play_music()

	# Demo gameplay di belakang: diredupkan oleh Background (warna menu
	# semi-transparan) dan SFX-nya dipelankan.
	var bg: ColorRect = $MenuUI/Background
	bg.color.a = 1.0 - GameBalance.menu_demo_dim
	AudioManager.apply_bus_volumes(GameBalance.menu_demo_sfx_volume_db)

	# Masuk dengan fade dari gelap (pasangan fade-out di layar game over).
	var fader: ColorRect = $MenuUI/Fader
	var tw := fader.create_tween()
	tw.tween_property(fader, "color:a", 0.0, GameBalance.gameover_fade_time)
	tw.tween_callback(fader.hide)

	start_button.pressed.connect(_on_start)
	options_button.pressed.connect(_show_options.bind(true))
	back_button.pressed.connect(_show_options.bind(false))
	music_slider.value_changed.connect(_on_volume_changed)
	sfx_slider.value_changed.connect(_on_volume_changed)
	music_slider.value = SaveData.music_volume
	sfx_slider.value = SaveData.sfx_volume
	_update_volume_labels()

	_refresh_records()
	start_button.grab_focus()


func _refresh_records() -> void:
	var returning := SaveData.has_records()
	first_time_block.visible = true
	records_block.visible = returning
	if returning:
		high_score_value.text = SaveData.format_thousands(SaveData.high_score)
		best_chain_value.text = "x%d" % SaveData.best_chain


func _on_start() -> void:
	if _starting:
		return
	_starting = true
	get_tree().change_scene_to_file(GAME_SCENE)


func _show_options(show_it: bool) -> void:
	options_panel.visible = show_it
	main_buttons.visible = not show_it
	if show_it:
		music_slider.grab_focus()
	else:
		options_button.grab_focus()


# Slider digeser: langsung terdengar, langsung tersimpan.
func _on_volume_changed(_value: float) -> void:
	SaveData.set_volumes(music_slider.value, sfx_slider.value)
	# Selama di menu, SFX tetap dipelankan untuk demo latar.
	AudioManager.apply_bus_volumes(GameBalance.menu_demo_sfx_volume_db)
	_update_volume_labels()


func _update_volume_labels() -> void:
	music_value.text = "%d%%" % int(round(music_slider.value * 100.0))
	sfx_value.text = "%d%%" % int(round(sfx_slider.value * 100.0))


# ESC menutup Options (tombol KEMBALI tetap ada untuk mouse).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("back_to_menu") and options_panel.visible:
		_show_options(false)
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	# Keluar dari menu -> volume SFX kembali normal untuk gameplay.
	AudioManager.apply_bus_volumes()
