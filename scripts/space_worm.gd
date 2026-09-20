extends Area2D
class_name SpaceWorm

# SPACE WORM — rintangan, BUKAN umpan chain.
# Badan BERUAS: satu kepala + beberapa ruas yang mengikuti JEJAK kepala
# (follow-the-leader). Saat berbelok badan melengkung mengikuti jalur,
# saat dash ruas-ruasnya tercambuk di belakang kepala.
#
# Cara kerjanya: node root selalu berada di posisi KEPALA dan tidak pernah
# diputar. Setiap frame, posisi kepala dicatat ke sebuah jejak (trail);
# ruas ke-i diletakkan sejauh i * worm_segment_spacing di sepanjang jejak
# itu. Visual tiap ruas ($Visual/SegmentN) dan collision-nya
# (SegmentShapeN) dipindah ke titik yang sama.
#
# Kenapa TIDAK extends EnemyBase / TIDAK masuk grup "enemies":
# grup "enemies" dipakai separation & cohesion cluster dan jarak spawn
# cluster — worm tidak ikut itu. Worm ada di grup "worms", dan Nuke,
# Singularity, ledakan chain (swarm/Heavy/worm lain), serta fragment
# asteroid semuanya ikut mengenai grup ini seperti entity lain. Peluru tetap
# mengenainya (ruas mana pun) karena peluru mengenai Area2D apa pun yang
# punya take_damage().
#
# Art-swap: ganti "Placeholder" di dalam $Visual/Head dan tiap
# $Visual/SegmentN. Ukuran sentuh/kena ada di HeadShape & SegmentShapeN.
#
# Siklus serangan (semua durasi di GameBalance):
#   DRIFT     -> melayang pelan, hitung mundur worm_attack_interval
#   TELEGRAPH -> berhenti, arah dash DIKUNCI, garis peringatan + badan
#                berkedip selama worm_telegraph_time
#   LUNGE     -> kepala dash lurus sejauh worm_lunge_distance (tepat
#                sepanjang garis peringatan), melukai player yang tersentuh
#   RECOVER   -> diam sebentar, lalu kembali DRIFT

# Dikirim ke ChainManager saat mati: posisi kepala + semua ruas (dunia).
# ChainManager yang meledakkan GARIS sepanjang titik-titik ini.
signal worm_died(body_points: Array[Vector2], killed_by: String)

enum State { DRIFT, TELEGRAPH, LUNGE, RECOVER }

var hp: int = 1

var _state: State = State.DRIFT
var _state_time: float = 0.0
var _attack_timer: float = 0.0
var _heading: float = 0.0                 # arah hadap kepala (radian)
var _lunge_dir: Vector2 = Vector2.RIGHT
var _lunge_travelled: float = 0.0
var _telegraph_tween: Tween

var _player: Node2D
var _wander_offset: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0

# Jejak posisi kepala, [0] = paling baru. Dipangkas sepanjang badan.
var _trail: Array[Vector2] = []
var _segments: Array[Node2D] = []               # $Visual/Segment1..N (urut dari kepala)
var _segment_shapes: Array[CollisionShape2D] = []  # SegmentShape1..N

@onready var visual: Node2D = $Visual
@onready var head: Node2D = $Visual/Head
@onready var head_shape: CollisionShape2D = $HeadShape
@onready var telegraph_line: Line2D = $TelegraphLine
# Bar HP kecil di atas kepala: muncul setelah kena hit pertama. "Fill"
# langsung turun, "Chip" (putih) menyusul sebentar kemudian — jadi
# beberapa ledakan beruntun terbaca sebagai damage yang MENUMPUK.
@onready var health_bar: Node2D = $HealthBar
@onready var health_fill: ColorRect = $HealthBar/Fill
@onready var health_chip: ColorRect = $HealthBar/Chip
var _bar_width: float = 0.0
var _chip_tween: Tween


func _ready() -> void:
	add_to_group("worms")
	hp = GameBalance.worm_hp
	_bar_width = health_fill.size.x
	_player = get_tree().get_first_node_in_group("player")
	_attack_timer = GameBalance.worm_attack_interval
	# Garis peringatan digambar di koordinat dunia.
	telegraph_line.top_level = true
	telegraph_line.visible = false

	var i := 1
	while visual.has_node("Segment%d" % i) and has_node("SegmentShape%d" % i):
		_segments.append(visual.get_node("Segment%d" % i))
		_segment_shapes.append(get_node("SegmentShape%d" % i))
		i += 1

	# Hadap awal ke tengah arena; badan dibentangkan lurus di belakang kepala.
	var center := Vector2(GameBalance.arena_width, GameBalance.arena_height) * 0.5
	_heading = (center - global_position).angle()
	var back := -Vector2.RIGHT.rotated(_heading)
	_trail = [global_position, global_position + back * _body_length()]
	_update_body()


func _physics_process(delta: float) -> void:
	_state_time += delta
	match _state:
		State.DRIFT:
			_drift(delta)
			_attack_timer -= delta
			if _attack_timer <= 0.0 and _player_in_attack_range():
				_start_telegraph()
		State.TELEGRAPH:
			# Kepala berbelok cepat ke arah yang SUDAH dikunci — garis
			# peringatan tidak ikut bergeser, jadi selalu jujur.
			_heading = rotate_toward(_heading, _lunge_dir.angle(),
				GameBalance.worm_telegraph_turn_rate * delta)
			if _state_time >= GameBalance.worm_telegraph_time:
				_start_lunge()
		State.LUNGE:
			_lunge(delta)
		State.RECOVER:
			if _state_time >= GameBalance.worm_recover_time:
				_set_state(State.DRIFT)
				_attack_timer = GameBalance.worm_attack_interval
	_update_body()


func _set_state(s: State) -> void:
	_state = s
	_state_time = 0.0


# ---------------- BADAN BERUAS ----------------

func _body_length() -> float:
	return GameBalance.worm_segment_spacing * _segments.size()


# Catat posisi kepala ke jejak, lalu letakkan tiap ruas di sepanjang jejak.
func _update_body() -> void:
	var head_pos := global_position
	if _trail.is_empty() or _trail[0].distance_to(head_pos) >= GameBalance.worm_trail_resolution:
		_trail.push_front(head_pos)
	_trim_trail()

	head.rotation = _heading
	var ahead := head_pos
	for i in _segments.size():
		var pos := _point_on_trail(head_pos, GameBalance.worm_segment_spacing * (i + 1))
		var local := pos - head_pos
		_segments[i].position = local
		_segment_shapes[i].position = local
		# Ruas menghadap ke ruas di depannya -> badan melengkung mulus.
		if ahead.distance_squared_to(pos) > 0.01:
			_segments[i].rotation = (ahead - pos).angle()
		ahead = pos


# Titik sejauh `dist` di belakang kepala, diukur menyusuri jejak.
func _point_on_trail(head_pos: Vector2, dist: float) -> Vector2:
	var prev := head_pos
	var remaining := dist
	for p in _trail:
		var seg_len := prev.distance_to(p)
		if seg_len >= remaining and seg_len > 0.0:
			return prev.lerp(p, remaining / seg_len)
		remaining -= seg_len
		prev = p
	# Jejak belum cukup panjang: lanjutkan lurus ke arah belakang kepala.
	var back := -Vector2.RIGHT.rotated(_heading)
	if _trail.size() >= 2:
		back = (_trail[-1] - _trail[-2]).normalized()
	return prev + back * remaining


# Buang titik jejak yang sudah lebih jauh dari ekor.
func _trim_trail() -> void:
	var limit := _body_length() + GameBalance.worm_segment_spacing
	var total := 0.0
	var prev := global_position
	for i in _trail.size():
		total += prev.distance_to(_trail[i])
		prev = _trail[i]
		if total > limit and i + 1 < _trail.size():
			_trail.resize(i + 1)
			return


# Posisi dunia semua bagian badan, kepala dulu — dipakai cek sentuh
# dan ledakan garis saat mati.
func get_body_points() -> Array[Vector2]:
	var pts: Array[Vector2] = [global_position]
	for s in _segments:
		pts.append(s.global_position)
	return pts


# Jarak dari titik p ke TEPI bagian badan terdekat (kepala atau ruas),
# minimal 0. Dipakai Nuke supaya worm kena begitu gelombang menyentuh
# bagian badan mana pun, bukan hanya kepalanya.
func distance_to_body(p: Vector2) -> float:
	var best := maxf(p.distance_to(global_position) - _shape_radius(head_shape), 0.0)
	for s in _segment_shapes:
		best = minf(best, maxf(p.distance_to(s.global_position) - _shape_radius(s), 0.0))
	return best


# Jarak dari segmen a-b (mis. beam laser) ke TEPI bagian badan terdekat.
func distance_to_segment(a: Vector2, b: Vector2) -> float:
	var c := Geometry2D.get_closest_point_to_segment(global_position, a, b)
	var best := maxf(c.distance_to(global_position) - _shape_radius(head_shape), 0.0)
	for s in _segment_shapes:
		c = Geometry2D.get_closest_point_to_segment(s.global_position, a, b)
		best = minf(best, maxf(c.distance_to(s.global_position) - _shape_radius(s), 0.0))
	return best


# ---------------- DRIFT ----------------

# Melayang pelan: kepala berbelok bertahap (worm_turn_rate) ke arah target,
# lalu maju lurus sesuai arah hadap. Target = player + offset acak yang
# diganti berkala, supaya worm mendekat tapi tidak menempel agresif.
func _drift(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = GameBalance.worm_wander_interval
		_wander_offset = Vector2.RIGHT.rotated(randf() * TAU) \
			* randf_range(0.0, GameBalance.worm_wander_radius)

	var target := _drift_target()
	var desired_angle := (target - global_position).angle()
	_heading = rotate_toward(_heading, desired_angle, GameBalance.worm_turn_rate * delta)
	global_position += Vector2.RIGHT.rotated(_heading) * GameBalance.worm_drift_speed * delta


func _drift_target() -> Vector2:
	var arena := Vector2(GameBalance.arena_width, GameBalance.arena_height)
	var base := arena * 0.5
	if _has_player():
		base = _player.global_position
	# Target dijaga di dalam arena supaya worm tidak berkeliaran keluar.
	var m := GameBalance.worm_edge_margin
	var t := base + _wander_offset
	return Vector2(clampf(t.x, m, arena.x - m), clampf(t.y, m, arena.y - m))


# Serang hanya kalau player cukup dekat — supaya worm tidak menerjang
# dari luar layar tanpa peringatan yang terlihat.
func _player_in_attack_range() -> bool:
	return _has_player() \
		and global_position.distance_to(_player.global_position) <= GameBalance.worm_attack_range


func _has_player() -> bool:
	return _player != null and is_instance_valid(_player)


# ---------------- TELEGRAPH ----------------

func _start_telegraph() -> void:
	_set_state(State.TELEGRAPH)
	# Arah dikunci ke posisi player SAAT INI. Player yang bergerak keluar
	# dari garis selama telegraph pasti selamat.
	_lunge_dir = (_player.global_position - global_position).normalized()
	if _lunge_dir == Vector2.ZERO:
		_lunge_dir = Vector2.RIGHT.rotated(_heading)

	# Garis dari kepala sampai titik akhir dash — persis jalur kepala.
	var start := global_position
	var end := start + _lunge_dir * GameBalance.worm_lunge_distance
	telegraph_line.points = PackedVector2Array([start, end])
	telegraph_line.width = GameBalance.worm_telegraph_line_width
	telegraph_line.visible = true

	# Garis & badan berkedip — terasa "siap menerjang".
	_kill_telegraph_tween()
	var blink := GameBalance.worm_telegraph_blink_time
	_telegraph_tween = create_tween()
	_telegraph_tween.set_loops()
	_telegraph_tween.tween_property(telegraph_line, "modulate:a", 0.25, blink)
	_telegraph_tween.parallel().tween_property(visual, "modulate", Color(2.2, 2.2, 2.2), blink)
	_telegraph_tween.tween_property(telegraph_line, "modulate:a", 1.0, blink)
	_telegraph_tween.parallel().tween_property(visual, "modulate", Color.WHITE, blink)
	AudioManager.play("worm_telegraph", global_position)


func _kill_telegraph_tween() -> void:
	if _telegraph_tween != null and _telegraph_tween.is_valid():
		_telegraph_tween.kill()
	visual.modulate = Color.WHITE


# ---------------- LUNGE ----------------

func _start_lunge() -> void:
	_set_state(State.LUNGE)
	_kill_telegraph_tween()
	telegraph_line.visible = false
	_heading = _lunge_dir.angle()
	_lunge_travelled = 0.0
	Juice.shake(GameBalance.worm_lunge_shake_intensity, GameBalance.worm_lunge_shake_duration)
	AudioManager.play("worm_lunge", global_position)


func _lunge(delta: float) -> void:
	var step := minf(GameBalance.worm_lunge_speed * delta,
		GameBalance.worm_lunge_distance - _lunge_travelled)
	global_position += _lunge_dir * step
	_lunge_travelled += step

	# Jangan menembus keluar arena: berhenti di tepi.
	var arena := Vector2(GameBalance.arena_width, GameBalance.arena_height)
	var clamped := global_position.clamp(Vector2.ZERO, arena)
	var hit_edge := clamped != global_position
	global_position = clamped

	_check_lunge_hit()

	if hit_edge or _lunge_travelled >= GameBalance.worm_lunge_distance:
		_set_state(State.RECOVER)


# Player tersentuh kalau menyentuh kepala atau ruas mana pun (lingkaran
# collision + padding). take_damage() player sudah punya invuln window,
# jadi tidak ada damage beruntun tiap frame.
func _check_lunge_hit() -> void:
	if not _has_player() or not _player.has_method("take_damage"):
		return
	var pp := _player.global_position
	var pad := GameBalance.worm_contact_padding
	if pp.distance_to(global_position) <= _shape_radius(head_shape) + pad:
		_player.take_damage(GameBalance.worm_contact_damage)
		return
	for s in _segment_shapes:
		if pp.distance_to(s.global_position) <= _shape_radius(s) + pad:
			_player.take_damage(GameBalance.worm_contact_damage)
			return


func _shape_radius(shape_node: CollisionShape2D) -> float:
	var c := shape_node.shape as CircleShape2D
	return c.radius if c != null else 0.0


# ---------------- DAMAGE & MATI ----------------

# Kena ruas mana pun = kena worm. Hanya kedip (tanpa punch scale — skala
# $Visual akan ikut meregangkan jarak antar ruas).
func take_damage(amount: int, source: String = "bullet", _depth: int = 0) -> void:
	if hp <= 0:
		return
	hp -= amount
	if hp <= 0:
		die(source)
		return
	_update_health_bar()
	Juice.flash(visual, Color(6, 6, 6), GameBalance.hit_flash_duration)


func _update_health_bar() -> void:
	health_bar.visible = true
	var ratio := clampf(float(hp) / float(GameBalance.worm_hp), 0.0, 1.0)
	health_fill.size.x = _bar_width * ratio
	if _chip_tween != null and _chip_tween.is_valid():
		_chip_tween.kill()
	_chip_tween = create_tween()
	_chip_tween.tween_interval(GameBalance.healthbar_chip_delay)
	_chip_tween.tween_property(health_chip, "size:x", health_fill.size.x,
		GameBalance.healthbar_chip_time).set_ease(Tween.EASE_OUT)


# Mati: kirim bentuk badan TERAKHIR ke ChainManager, yang meledakkan garis
# sepanjang badan (mengikuti lengkungannya) memakai sistem chain yang sama
# dengan Heavy. Worm tidak mengurus chain/ledakan sendiri.
func die(killed_by: String = "bullet") -> void:
	telegraph_line.visible = false
	AudioManager.play("heavy_death", global_position)
	worm_died.emit(get_body_points(), killed_by)
	queue_free()
