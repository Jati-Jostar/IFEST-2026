extends Node2D

# NUKE — senjata pamungkas langka sekaligus pemicu chain terbesar.
# Ledakan lingkaran yang mengembang dari 0 ke radius penuh dan MENGHAPUS
# TOTAL semua yang dilewatinya: swarm, Heavy, dan asteroid. Tanpa
# falloff, tanpa penyintas di dalam radius.
#
# Damage diterapkan saat gelombang ring MELEWATI objek (bukan sekaligus),
# jadi penghapusan terbaca menjalar keluar dari pusat.
#
# Yang tetap menjalar KELUAR radius:
# - Heavy yang mati tetap meledak sendiri (reset chain depth ke 0)
# - Asteroid yang hancur tetap memuntahkan fragment
# Semua kill oleh Nuke dihitung sebagai chain event.
#
# Player ikut kena, tapi memakai nuke_self_damage terpisah (dikali
# player_self_damage_multiplier) supaya Nuke tidak one-shot player.

const EXPLOSION_NUKE := preload("res://scenes/fx/explosion_nuke.tscn")

var _t: float = 0.0
var _prev_radius: float = 0.0
var _player_hit: bool = false


func _ready() -> void:
	AudioManager.play("nuke_activate", global_position)
	Juice.hitstop(GameBalance.hitstop_nuke)
	Juice.shake(GameBalance.shake_nuke_intensity, GameBalance.shake_nuke_duration)
	Juice.screen_flash(Color(1, 1, 1, 1),
		GameBalance.nuke_flash_strength, GameBalance.nuke_flash_duration)
	Juice.punch_zoom(GameBalance.nuke_zoom_punch, 0.3)
	Juice.spawn_fx(EXPLOSION_NUKE, global_position)


func _physics_process(delta: float) -> void:
	_t += delta
	var duration := GameBalance.nuke_duration
	var p := clampf(_t / duration, 0.0, 1.0)
	var radius := GameBalance.nuke_radius * p

	_damage_band(_prev_radius, radius)
	_prev_radius = radius
	queue_redraw()

	# Sisakan sedikit waktu untuk ring memudar setelah mengembang penuh.
	if _t >= duration + 0.2:
		queue_free()


# Hapus semua objek yang baru saja tersapu gelombang ring.
# Jarak diukur sampai TEPI badan target (di-clamp minimal 0), bukan titik
# pusatnya — objek besar seperti Heavy tetap tersapu begitu gelombang
# menyentuh badannya, dan yang badannya menyelimuti titik ledak kena di
# gelombang pertama. Kill oleh Nuke selalu depth 0.
func _damage_band(from_r: float, to_r: float) -> void:
	if to_r <= from_r:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var e := enemy as EnemyBase
		if e != null:
			var d := maxf(global_position.distance_to(e.global_position) - e.body_radius, 0.0)
			if d >= from_r and d <= to_r:
				e.take_damage(GameBalance.nuke_damage, "nuke", 0)
	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		var a := asteroid as Node2D
		if a != null:
			var d := maxf(global_position.distance_to(a.global_position) - a.body_radius, 0.0)
			if d >= from_r and d <= to_r:
				a.take_damage(GameBalance.nuke_damage, "nuke", 0)
	if not _player_hit:
		var player: Node2D = get_tree().get_first_node_in_group("player")
		if player != null and is_instance_valid(player) and player.has_method("take_damage"):
			if global_position.distance_to(player.global_position) <= to_r:
				_player_hit = true
				player.take_damage(int(ceil(
					GameBalance.nuke_self_damage * GameBalance.player_self_damage_multiplier)))


func _draw() -> void:
	var duration := GameBalance.nuke_duration
	var p := clampf(_t / duration, 0.0, 1.0)
	var radius := maxf(GameBalance.nuke_radius * p, 2.0)
	# Setelah penuh, ring memudar.
	var fade := 1.0 if _t <= duration else clampf(1.0 - (_t - duration) / 0.2, 0.0, 1.0)
	var width := lerpf(18.0, 3.0, p)   # garis menipis saat membesar
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.75, 0.2, fade), width)
	# Kilatan inti di awal ledakan.
	if p < 0.35:
		draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 0.9, 0.5, (0.35 - p) * 1.6))
