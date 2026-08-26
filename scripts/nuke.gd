extends Node2D

# NUKE — pemicu chain reaction. Ledakan lingkaran besar yang mengembang
# dari 0 ke radius penuh. Damage diterapkan saat gelombang ring MELEWATI
# objek, jadi kaskade terbaca menjalar keluar. Player ikut kena
# (dikali self-damage multiplier), sekali saja.

var _t: float = 0.0
var _prev_radius: float = 0.0
var _player_hit: bool = false


func _ready() -> void:
	AudioManager.play("nuke_activate", global_position)
	Juice.hitstop(GameBalance.hitstop_nuke)
	Juice.shake(GameBalance.shake_nuke_intensity, GameBalance.shake_nuke_duration)
	Juice.screen_flash(Color(1, 1, 1, 1), 0.35, 0.2)
	Juice.punch_zoom(GameBalance.nuke_zoom_punch, 0.3)


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


# Damage semua objek yang jaraknya baru saja dilewati gelombang ring.
func _damage_band(from_r: float, to_r: float) -> void:
	if to_r <= from_r:
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var d := global_position.distance_to(enemy.global_position)
			if d > from_r and d <= to_r:
				enemy.take_damage(GameBalance.nuke_damage, "nuke")
	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		if is_instance_valid(asteroid):
			var d := global_position.distance_to(asteroid.global_position)
			if d > from_r and d <= to_r:
				asteroid.take_damage(GameBalance.nuke_damage, "nuke")
	if not _player_hit:
		var player: Node2D = get_tree().get_first_node_in_group("player")
		if player != null and is_instance_valid(player) and player.has_method("take_damage"):
			if global_position.distance_to(player.global_position) <= to_r:
				_player_hit = true
				player.take_damage(int(ceil(
					GameBalance.nuke_damage * GameBalance.player_self_damage_multiplier)))


func _draw() -> void:
	var duration := GameBalance.nuke_duration
	var p := clampf(_t / duration, 0.0, 1.0)
	var radius := maxf(GameBalance.nuke_radius * p, 2.0)
	# Setelah penuh, ring memudar.
	var fade := 1.0 if _t <= duration else clampf(1.0 - (_t - duration) / 0.2, 0.0, 1.0)
	var width := lerpf(14.0, 3.0, p)   # garis menipis saat membesar
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.75, 0.2, fade), width)
	# Kilatan inti di awal ledakan.
	if p < 0.35:
		draw_circle(Vector2.ZERO, radius * 0.5, Color(1.0, 0.9, 0.5, (0.35 - p) * 1.6))
