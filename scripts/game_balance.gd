extends Node

# =====================================================================
#  GAME BALANCE — SEMUA ANGKA GAME ADA DI SINI
#
#  File ini berisi SEMUA angka yang mempengaruhi rasa permainan.
#  Ubah nilainya di sini, tekan Play, dan lihat hasilnya.
#  Kamu TIDAK perlu mengerti kode lain di project ini.
#
#  Catatan: bagian baru akan ditambahkan seiring phase development
#  (enemy, asteroid, ability, chain, juice, dst).
# =====================================================================

# ============ ARENA ============
# Ukuran arena permainan dalam pixel. Layar = 1280x720,
# arena sedikit lebih besar supaya kamera bisa bergeser.
var arena_width: float = 1600.0
var arena_height: float = 900.0

# ============ PLAYER ============
var player_speed: float = 320.0        # kecepatan gerak (pixel/detik)
var player_max_hp: int = 100           # nyawa maksimal
var player_fire_rate: float = 0.15     # jeda antar tembakan (detik) — dipakai mulai Phase 2
var player_invuln_time: float = 0.6    # kebal sesaat setelah kena hit (detik) — dipakai mulai Phase 3

# ============ PROJECTILE (peluru player) ============
var projectile_speed: float = 700.0    # kecepatan peluru (pixel/detik)
var projectile_damage: int = 10        # damage per peluru (1 target, tidak menembus)
var projectile_lifetime: float = 1.2   # umur peluru sebelum hilang sendiri (detik)

# ============ SWARM ENEMY (musuh kecil merah) ============
var swarm_hp: int = 10                 # mati oleh 1 peluru
var swarm_speed: float = 120.0         # kecepatan mengejar player
var swarm_contact_damage: int = 5      # damage saat menyentuh player
# (death burst / ledakan berantai menyusul di Phase 4)

# ============ HEAVY ENEMY (musuh besar merah tua) ============
var heavy_hp: int = 60                 # butuh 6 peluru
var heavy_speed: float = 55.0          # lambat
var heavy_contact_damage: int = 15     # sakit kalau kena tabrak
# (ledakan besar saat mati menyusul di Phase 4)

# ============ ENEMY SPAWNING ============
var enemy_spawn_interval: float = 2.5  # jeda antar gelombang spawn (detik) — ramp kesulitan di Phase 7
var heavy_spawn_every: int = 8         # setiap spawn ke-N adalah Heavy (sisanya grup Swarm)
var swarm_group_min: int = 2           # swarm muncul bergerombol supaya esensi chain terlihat
var swarm_group_max: int = 4
var swarm_group_spread: float = 45.0   # sebaran acak anggota grup dari titik spawn (pixel)
var max_enemies: int = 40              # batas musuh di layar (jaga performa browser)

# ============ ASTEROID (objek netral abu-abu) ============
var asteroid_hp: int = 20                # 2 peluru
var asteroid_speed_min: float = 30.0     # melayang pelan
var asteroid_speed_max: float = 70.0
var asteroid_contact_damage: int = 10    # damage saat menabrak player
var asteroid_spawn_interval: float = 6.0 # jeda spawn asteroid (detik)
var max_asteroids: int = 8               # batas asteroid di arena

# ============ ASTEROID FRAGMENT (pecahan) ============
var fragment_count_min: int = 3          # jumlah pecahan saat asteroid hancur
var fragment_count_max: int = 5
var fragment_speed: float = 260.0        # pecahan melesat keluar
var fragment_damage: int = 6             # damage ke musuh ATAU player (tanpa multiplier)
var fragment_lifetime: float = 1.1       # umur pecahan (detik)

# ============ CHAIN REACTION ============
var chain_time_window: float = 2.0       # detik tanpa reaksi = chain berakhir
var chain_stagger: float = 0.05          # jeda antar generasi ledakan (anti-freeze + terlihat kaskade)
var swarm_death_burst_radius: float = 70.0
var swarm_death_burst_damage: int = 12   # harus >= swarm_hp supaya kaskade swarm rapat bisa menular
var heavy_explosion_radius: float = 170.0
var heavy_explosion_damage: int = 35
var player_self_damage_multiplier: float = 0.35  # damage ledakan sendiri/chain ke player dikali ini

# ============ SCORE ============
var score_swarm: int = 100
var score_heavy: int = 500
var score_asteroid: int = 50             # dipakai mulai Phase 5
# skor kill = nilai dasar x chain saat itu (minimal x1)

# ============ JUICE (game feel) ============
# Kalau shake bikin pusing, kecilkan shake_global_multiplier (0 = mati total).
var shake_global_multiplier: float = 1.0
var shake_max: float = 20.0              # batas shake saat banyak event bersamaan
var max_fx_nodes: int = 60               # batas node efek visual aktif (jaga performa)

var hit_flash_duration: float = 0.06     # kedip putih saat musuh kena peluru
var hit_punch_amount: float = 1.15       # musuh membesar sesaat saat kena hit
var hit_punch_duration: float = 0.12

var shake_swarm_intensity: float = 2.0   # shake saat swarm mati
var shake_swarm_duration: float = 0.1
var shake_heavy_intensity: float = 12.0  # shake saat heavy meledak
var shake_heavy_duration: float = 0.35
var hitstop_heavy: float = 0.08          # freeze sesaat saat heavy meledak

var shake_player_hit_intensity: float = 6.0
var shake_player_hit_duration: float = 0.15

var shake_asteroid_intensity: float = 5.0  # shake saat asteroid pecah
var shake_asteroid_duration: float = 0.2
