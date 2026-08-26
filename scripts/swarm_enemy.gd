extends EnemyBase

# Musuh kecil merah: cepat, lemah, mengejar player.
# Death burst (ledakan berantai) menyusul di Phase 4.


func _setup_stats() -> void:
	enemy_type = "swarm"
	max_hp = GameBalance.swarm_hp
	speed = GameBalance.swarm_speed
	contact_damage = GameBalance.swarm_contact_damage
	contact_range = 25.0
	death_audio_event = "swarm_death"
