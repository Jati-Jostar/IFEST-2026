extends Node

# =====================================================================
#  AUDIO MANAGER (autoload)
#
#  Semua event audio game lewat satu fungsi: AudioManager.play("nama_event")
#  Saat ini SEMUA slot masih null = tidak ada suara, dan itu normal.
#  Nanti file .ogg tinggal dipasang ke dictionary `streams` di bawah
#  tanpa mengubah kode gameplay sama sekali.
#
#  MUSIK: autoload ini sekarang berupa SCENE (scenes/audio_manager.tscn).
#  Buka scene itu, klik node AudioManager, lalu seret file .ogg musik ke
#  slot "Music Stream" di Inspector. Kosong = diam, tanpa error.
#  Musik diputar oleh player khusus di bus "Music" (bukan lewat pool SFX),
#  dan karena autoload tidak pernah dihapus, musik tetap jalan terus saat
#  pindah menu -> game -> game over -> menu tanpa mulai ulang.
# =====================================================================

const POOL_SIZE := 8
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const SILENT_DB := -80.0

# Slot musik latar. Seret file .ogg ke sini lewat Inspector.
@export var music_stream: AudioStream

# Slot audio per event. Isi dengan preload("res://assets/audio/nama.ogg")
# saat file audio sudah ada. Selama null, play() diam tanpa error.
var streams: Dictionary = {
	"player_shoot": preload("res://assets/audio/kenney_sci-fi-sounds/laserSmall_000.ogg"),
	"player_hit": preload("res://assets/audio/kenney_impact-sounds/impactPlate_light_003.ogg"),
	"player_death": preload("res://assets/audio/kenney_sci-fi-sounds/laserLarge_001.ogg"),
	"swarm_death": preload("res://assets/audio/kenney_sci-fi-sounds/explosionCrunch_002.ogg"),
	"heavy_death": preload("res://assets/audio/kenney_sci-fi-sounds/explosionCrunch_003.ogg"),
	"asteroid_break": preload("res://assets/audio/kenney_sci-fi-sounds/lowFrequency_explosion_000.ogg"),
	"fragment_hit": preload("res://assets/audio/kenney_sci-fi-sounds/lowFrequency_explosion_001.ogg"),
	"pickup_collect": preload("res://assets/audio/kenney_interface-sounds/select_007.ogg"),
	"singularity_activate": preload("res://assets/audio/kenney_sci-fi-sounds/spaceEngine_001.ogg"),
	"singularity_loop": preload("res://assets/audio/kenney_sci-fi-sounds/spaceEngine_001.ogg"),
	"nuke_activate": preload("res://assets/audio/kenney_sci-fi-sounds/explosionCrunch_000.ogg"),
	"chain_increment": preload("res://assets/audio/kenney_interface-sounds/maximize_007.ogg"),
	"chain_end": preload("res://assets/audio/kenney_interface-sounds/minimize_006.ogg"),
	# Space Worm — slot kosong, silakan isi (aman selama null).
	# PLACEHOLDER: file dipakai bersama event lain, tapi pitch-nya diturunkan
	# lewat `pitches` di bawah supaya terdengar khas worm.
	"worm_telegraph": null,
	"worm_lunge": preload("res://assets/audio/kenney_sci-fi-sounds/lowFrequency_explosion_000.ogg"),
	# Charged Laser — slot kosong, silakan isi dari pack Kenney.
	"laser_ready": null,       # cue singkat saat charge siap
	"laser_charge": preload("res://assets/audio/kenney_sci-fi-sounds/thrusterFire_003.ogg"),  # PLACEHOLDER wind-up
	"laser_fire_start": null,  # awal beam
	"laser_fire_loop": preload("res://assets/audio/kenney_sci-fi-sounds/spaceEngine_001.ogg"),  # PLACEHOLDER dengung beam (play_loop, pitch dinaikkan)
	"laser_fire_end": null,    # beam selesai
	# SENGAJA dibiarkan kosong: "player_death" sudah berbunyi di frame yang
	# sama saat player mati, dan dua suara sekaligus malah saling menutupi.
	"game_over": null,
}

# Volume per event: 1.0 = penuh, 0.6 = 60 persen. Event yang tidak
# terdaftar di sini otomatis 1.0. Berguna untuk suara yang terdengar
# sangat sering (kematian swarm bisa puluhan kali per detik saat chain
# panjang) supaya tidak menenggelamkan ledakan besar.
var volumes: Dictionary = {
	"worm_telegraph": 0.5,
	"worm_lunge": 0.8,
	"swarm_death": 0.1,
	"pickup_collect": 0.3,
	"chain_increment": 0.07,
}

# Pitch tetap per event: dipakai untuk membedakan suara PLACEHOLDER yang
# filenya sama dengan event lain. 1.0 = nada asli, <1 lebih berat/rendah.
var pitches: Dictionary = {
	"worm_telegraph": 0.55,   # nada turun jadi peringatan berat
	"worm_lunge": 0.65,      # semburan jadi terjangan berat
}

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _music_player: AudioStreamPlayer
var _music_tween: Tween
# Player khusus untuk suara loop (mis. laser_fire_loop): bisa dihentikan
# tepat waktu, tidak seperti pool yang dipakai bergantian.
var _loop_players: Dictionary = {}
var _last_play_ms: Dictionary = {}   # event -> waktu terakhir diputar (ms)


func _ready() -> void:
	# Pool kecil supaya beberapa suara bisa overlap.
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_players.append(p)

	apply_bus_volumes()

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	# Musik mulai sekali saat game dibuka, lalu jalan terus.
	play_music()


func play(event_name: String, _position: Vector2 = Vector2.ZERO, pitch: float = 1.0) -> void:
	# Aman dipanggil kapan saja: diam saja jika slot kosong / nama tidak dikenal.
	var stream: AudioStream = streams.get(event_name)
	if stream == null:
		return
	# Batasi event yang sama agar tidak diputar puluhan kali per frame.
	var now := Time.get_ticks_msec()
	if now - int(_last_play_ms.get(event_name, -100000)) < int(GameBalance.audio_same_event_min_interval * 1000.0):
		return
	_last_play_ms[event_name] = now
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = pitch * float(pitches.get(event_name, 1.0))
	# Volume di-set ulang tiap kali: player di pool dipakai bergantian
	# antar event, jadi jangan sampai volume event sebelumnya terbawa.
	p.volume_db = linear_to_db(volumes.get(event_name, 1.0))
	p.play()
	
func stop(event_name: String) -> void:
	# Hentikan semua player yang sedang memutar stream event ini.
	var stream: AudioStream = streams.get(event_name)
	if stream == null:
		return
	for p in _players:
		if p.playing and p.stream == stream:
			p.stop()


# Putar event sebagai LOOP di player khususnya sendiri. Aman kalau slot kosong.
func play_loop(event_name: String, pitch: float = 1.0) -> void:
	var stream: AudioStream = streams.get(event_name)
	if stream == null:
		return
	var p: AudioStreamPlayer = _loop_players.get(event_name)
	if p == null:
		p = AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_loop_players[event_name] = p
	if "loop" in stream:
		stream.set("loop", true)
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(volumes.get(event_name, 1.0))
	p.play()


func stop_loop(event_name: String) -> void:
	var p: AudioStreamPlayer = _loop_players.get(event_name)
	if p != null:
		p.stop()


# ------------------------------------------------------------ BUS VOLUME

# sfx_offset_db: peredam tambahan sementara (dipakai demo di main menu).
func apply_bus_volumes(sfx_offset_db: float = 0.0) -> void:
	var music_idx := AudioServer.get_bus_index(MUSIC_BUS)
	var sfx_idx := AudioServer.get_bus_index(SFX_BUS)
	# Volume akhir = nilai dasar GameBalance + setelan player dari menu
	# Options (0..1). Slider di 0 = bus dimatikan total.
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx,
			GameBalance.music_volume_db + _slider_db(SaveData.music_volume))
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx,
			GameBalance.sfx_volume_db + _slider_db(SaveData.sfx_volume) + sfx_offset_db)


# 0..1 dari slider -> dB (0 = diam total).
func _slider_db(v: float) -> float:
	return SILENT_DB if v <= 0.001 else linear_to_db(v)


# ------------------------------------------------------------ MUSIK

# Putar musik dengan fade-in. Kalau lagu yang sama sudah jalan, tidak
# diulang dari awal (penting supaya pindah scene tidak me-restart musik).
func play_music(stream: AudioStream = null, fade_time: float = -1.0) -> void:
	if stream != null:
		music_stream = stream
	if music_stream == null:
		return
	if _music_player.playing and _music_player.stream == music_stream:
		fade_music(0.0, fade_time if fade_time >= 0.0 else GameBalance.music_fade_in_time)
		return
	# Pastikan loop untuk format yang mendukungnya (ogg/mp3).
	if "loop" in music_stream:
		music_stream.set("loop", true)
	_music_player.stream = music_stream
	_music_player.volume_db = SILENT_DB
	_music_player.play()
	fade_music(0.0, fade_time if fade_time >= 0.0 else GameBalance.music_fade_in_time)


# Hentikan musik dengan fade-out.
func stop_music(fade_time: float = -1.0) -> void:
	if not _music_player.playing:
		return
	fade_music(SILENT_DB, fade_time if fade_time >= 0.0 else GameBalance.music_fade_out_time, true)


# Geser volume musik ke target_db dalam `time` detik. Tidak terpengaruh
# slow-motion / hitstop (Engine.time_scale).
func fade_music(target_db: float, time: float, stop_after: bool = false) -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	if time <= 0.0:
		_music_player.volume_db = target_db
		if stop_after:
			_music_player.stop()
		return
	_music_tween = create_tween()
	_music_tween.set_ignore_time_scale(true)
	_music_tween.tween_property(_music_player, "volume_db", target_db, time)
	if stop_after:
		_music_tween.tween_callback(_music_player.stop)


# Cadangan untuk format tanpa properti loop (mis. wav tanpa loop point).
func _on_music_finished() -> void:
	if _music_player.volume_db > SILENT_DB + 1.0:
		_music_player.play()
