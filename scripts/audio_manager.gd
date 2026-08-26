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
	"player_shoot": null,
	"player_hit": null,
	"player_death": null,
	"swarm_death": null,
	"heavy_death": null,
	"asteroid_break": null,
	"fragment_hit": null,
	"pickup_collect": null,
	"singularity_activate": null,
	"singularity_loop": null,
	"nuke_activate": null,
	"chain_increment": null,
	"chain_end": null,
	"game_over": null,
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
	p.play()
