extends EnemyBase

# Musuh besar merah tua: lambat, HP tebal, tabrakan sakit.
# Ledakan besar saat mati (bom chain reaction) menyusul di Phase 4.


func _setup_stats() -> void:
	enemy_type = "heavy"
	body_radius = GameBalance.heavy_body_radius
	max_hp = GameBalance.heavy_hp
	speed = GameBalance.heavy_speed
	contact_damage = GameBalance.heavy_contact_damage
	contact_range = 50
	death_audio_event = "heavy_death"
