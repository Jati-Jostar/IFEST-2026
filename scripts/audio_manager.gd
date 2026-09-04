extends Node

# =====================================================================
#  AUDIO MANAGER (autoload)
#
#  Semua event audio game lewat satu fungsi: AudioManager.play("nama_event")
#  Saat ini SEMUA slot masih null = tidak ada suara, dan itu normal.
#  Nanti file .ogg tinggal dipasang ke dictionary `streams` di bawah
#  tanpa mengubah kode gameplay sama sekali.
# =====================================================================

const POOL_SIZE := 8

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
	# SENGAJA dibiarkan kosong: "player_death" sudah berbunyi di frame yang
	# sama saat player mati, dan dua suara sekaligus malah saling menutupi.
	"game_over": null,
}

# Volume per event: 1.0 = penuh, 0.6 = 60 persen. Event yang tidak
# terdaftar di sini otomatis 1.0. Berguna untuk suara yang terdengar
# sangat sering (kematian swarm bisa puluhan kali per detik saat chain
# panjang) supaya tidak menenggelamkan ledakan besar.
var volumes: Dictionary = {
	"swarm_death": 0.1,
	"pickup_collect": 0.3,
	"chain_increment": 0.07,
}

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0


func _ready() -> void:
	# Pool kecil supaya beberapa suara bisa overlap.
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(event_name: String, _position: Vector2 = Vector2.ZERO, pitch: float = 1.0) -> void:
	# Aman dipanggil kapan saja: diam saja jika slot kosong / nama tidak dikenal.
	var stream: AudioStream = streams.get(event_name)
	if stream == null:
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = pitch
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
