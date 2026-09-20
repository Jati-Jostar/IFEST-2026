extends Node2D

# CHARGED LASER — senjata ketiga, didapat dari SKOR (lihat player.gd).
# Dipasang sebagai anak Player, jadi ikut bergerak bersama kapal.
#
# Tahapan (tidak bisa dibatalkan sejak wind-up dimulai):
#   CHARGE -> ring biru menyusut ke kapal (laser_charge_time). Player tetap
#             bisa bergerak & tetap bisa terluka — aktivasi = keputusan timing.
#   FIRE   -> beam dari hidung kapal, mengikuti arah hadap (kursor) real-time,
#             menembus semuanya. Damage per tick (laser_tick_interval), bukan
#             per frame, supaya rate-nya stabil di berbagai FPS.
#   FADE   -> beam memudar singkat tanpa damage, lalu node ini dihapus.
#
# Kill dari beam = event chain dengan depth 0 (seperti ledakan Heavy):
# musuh dipanggil take_damage(..., "laser", 0), ChainManager yang mengurus
# chain & burst lanjutannya. Tidak ada sistem chain terpisah di sini.
#
# Semua gambar (ring & beam) digambar lewat kode ke node $Visual, jadi
# artist bisa menggantinya nanti tanpa menyentuh logika.

signal finished

enum Phase { CHARGE, FIRE, FADE }

const MUZZLE_OFFSET := 20.0   # sama dengan titik keluar peluru di player.gd

var _phase: Phase = Phase.CHARGE
var _t: float = 0.0
var _tick_acc: float = 0.0
var _shake_acc: float = 0.0
var _fade_alpha: float = 1.0
var _player: Node2D
var _player_visual: Node2D
var _cam_tween: Tween

@onready var visual: Node2D = $Visual


func _ready() -> void:
	_player = get_parent() as Node2D
	_player_visual = _player.get_node_or_null("Visual")
	visual.draw.connect(_draw_visual)
	AudioManager.play("laser_charge", global_position)


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		Phase.CHARGE:
			_process_charge(delta)
		Phase.FIRE:
			_process_fire(delta)
		Phase.FADE:
			_fade_alpha = 1.0 - _t / maxf(GameBalance.laser_fade_time, 0.01)
			if _fade_alpha <= 0.0:
				queue_free()
	visual.queue_redraw()


# Arah hadap kapal: sprite menghadap -Y, rotasinya diatur player._handle_aim.
func _dir() -> Vector2:
	if _player_visual != null:
		return Vector2.UP.rotated(_player_visual.rotation)
	return Vector2.UP


func _player_dead() -> bool:
	return _player == null or not is_instance_valid(_player) or _player.get("_is_dead") == true


# ---------------- CHARGE ----------------

func _process_charge(delta: float) -> void:
	var k := clampf(_t / GameBalance.laser_charge_time, 0.0, 1.0)
	# Kapal makin terang saat ring-ring tiba.
	if _player_visual != null:
		_player_visual.modulate = Color.WHITE.lerp(
			Color(1.0, 1.0, 1.0) * GameBalance.laser_charge_ship_glow, k * k)
	# Getaran halus yang membesar sepanjang wind-up.
	_shake_acc -= delta
	if _shake_acc <= 0.0:
		_shake_acc = 0.1
		Juice.shake(GameBalance.laser_charge_shake * k, 0.12)
	if _player_dead():
		_end()
		return
	if _t >= GameBalance.laser_charge_time:
		_start_fire()


func _start_fire() -> void:
	_phase = Phase.FIRE
	_t = 0.0
	_tick_acc = GameBalance.laser_tick_interval   # tick pertama langsung
	if _player_visual != null:
		_player_visual.modulate = Color.WHITE
	AudioManager.stop("laser_charge")   # potong suara charge kalau file-nya lebih panjang
	AudioManager.play("laser_fire_start", global_position)
	AudioManager.play_loop("laser_fire_loop", GameBalance.laser_fire_loop_pitch)
	_zoom_camera(GameBalance.laser_zoom)


# ---------------- FIRE ----------------

func _process_fire(delta: float) -> void:
	if _player_dead():
		_end()
		return
	_shake_acc -= delta
	if _shake_acc <= 0.0:
		_shake_acc = 0.1
		Juice.shake(GameBalance.laser_beam_shake, 0.12)
	_tick_acc += delta
	while _tick_acc >= GameBalance.laser_tick_interval:
		_tick_acc -= GameBalance.laser_tick_interval
		_apply_damage_tick()
	if _t >= GameBalance.laser_duration:
		_end()


# Semua yang tersentuh garis beam kena damage (menembus, tidak berhenti
# di target pertama). Jarak diukur ke TEPI badan target.
func _apply_damage_tick() -> void:
	var dmg := int(round(GameBalance.laser_damage_per_second * GameBalance.laser_tick_interval))
	var half := GameBalance.laser_width * 0.5
	var a := global_position + _dir() * MUZZLE_OFFSET
	var b := a + _dir() * GameBalance.laser_range

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var e := enemy as EnemyBase
		if e != null and _dist_to_beam(e.global_position, a, b) - e.body_radius <= half:
			e.take_damage(dmg, "laser", 0)
	for asteroid in get_tree().get_nodes_in_group("asteroids"):
		var ast := asteroid as Node2D
		if ast != null and _dist_to_beam(ast.global_position, a, b) - ast.body_radius <= half:
			ast.take_damage(dmg, "laser", 0)
	for worm in get_tree().get_nodes_in_group("worms"):
		var w := worm as SpaceWorm
		if w != null and w.distance_to_segment(a, b) <= half:
			w.take_damage(dmg, "laser", 0)


func _dist_to_beam(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


# Selesai: kilatan singkat, beam memudar (tanpa damage), kamera kembali.
func _end() -> void:
	if _phase == Phase.FADE:
		return
	var was_firing := _phase == Phase.FIRE
	_phase = Phase.FADE
	_t = 0.0
	if _player_visual != null and is_instance_valid(_player_visual):
		_player_visual.modulate = Color.WHITE
	AudioManager.stop_loop("laser_fire_loop")
	if was_firing:
		AudioManager.play("laser_fire_end", global_position)
		Juice.screen_flash(GameBalance.laser_charge_color,
			GameBalance.laser_end_flash_strength, GameBalance.laser_fade_time)
	_zoom_camera(1.0)
	finished.emit()


func _zoom_camera(target: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	# Tween dibuat di kamera supaya tetap selesai walau node ini sudah dihapus.
	_cam_tween = cam.create_tween()
	_cam_tween.tween_property(cam, "zoom", Vector2.ONE * target, GameBalance.laser_zoom_time) \
		.set_trans(Tween.TRANS_SINE)


# ---------------- GAMBAR (di $Visual) ----------------

func _draw_visual() -> void:
	var col := GameBalance.laser_charge_color
	match _phase:
		Phase.CHARGE:
			_draw_charge_rings(col)
		Phase.FIRE:
			_draw_beam(col, 1.0)
		Phase.FADE:
			_draw_beam(col, maxf(_fade_alpha, 0.0))


# Ring ke-i mulai berurutan dan menyusut dari start_radius ke kapal;
# makin dekat makin terang & tebal. Ring terakhir tiba tepat saat beam menembak.
func _draw_charge_rings(col: Color) -> void:
	var n: int = maxi(GameBalance.laser_charge_ring_count, 1)
	var total := GameBalance.laser_charge_time
	var life := total * 0.6
	var gap := (total - life) / maxf(n - 1, 1)
	for i in n:
		var start := i * gap
		var k := (_t - start) / life
		if k < 0.0 or k > 1.0:
			continue
		var r := lerpf(GameBalance.laser_charge_ring_start_radius, 6.0, k * k)
		var c := col.lerp(Color.WHITE, k * 0.6)
		c.a = lerpf(0.25, 1.0, k)
		visual.draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c,
			GameBalance.laser_charge_ring_width * lerpf(1.0, 2.0, k))


# Beam: glow luar lebar & lembut + badan biru + inti terang, plus muzzle flash.
func _draw_beam(col: Color, alpha: float) -> void:
	var dir := _dir()
	var a := dir * MUZZLE_OFFSET
	var b := a + dir * GameBalance.laser_range
	var w := GameBalance.laser_width
	var flicker := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.05)
	var glow := Color(col.r, col.g, col.b, 0.22 * alpha)
	var body := Color(col.r, col.g, col.b, 0.75 * alpha)
	var core := Color(0.85, 0.95, 1.0, alpha)
	visual.draw_line(a, b, glow, w * 2.2 * flicker)
	visual.draw_line(a, b, body, w * flicker)
	visual.draw_line(a, b, core, w * 0.35)
	# Muzzle flash di hidung kapal selama beam aktif.
	visual.draw_circle(a, w * 0.9 * flicker, Color(col.r, col.g, col.b, 0.5 * alpha))
	visual.draw_circle(a, w * 0.5, core)
