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
var player_fire_rate: float = 0.3      # jeda antar tembakan (detik). Sengaja lambat:
									   # senjata utama harus terasa lemah lawan gerombolan
									   # supaya player bergantung pada chain reaction
var player_invuln_time: float = 0.6    # kebal sesaat setelah kena hit (detik)
var player_max_ammo: int = 6           # peluru yang dibawa. Habis peluru = berhenti menembak
									   # dan mulai MENGGIRING musuh — bukan hukuman, tapi
									   # aba-aba ganti mode. Isi ulang hanya lewat pickup amunisi.

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
var heavy_hp: int = 50                 # tebal: beberapa burst swarm tidak menjatuhkannya,
									   # tapi chain besar yang panjang akhirnya BISA membunuhnya
									   # -> Heavy meledak -> chain menyala lagi
var heavy_speed: float = 80.0          # lambat
var heavy_contact_damage: int = 15     # sakit kalau kena tabrak
# (ledakan besar saat mati menyusul di Phase 4)

# ============ CLUSTER SPAWNING & DIFFICULTY RAMP ============
# Musuh spawn sebagai CLUSTER: gerombolan swarm mengelilingi Heavy-nya.
# Ramp kesulitan utama = jarak antar cluster yang makin RAPAT seiring
# waktu bertahan (dipercepat oleh skor). Awal: chain terkurung di satu
# cluster. Late game: chain bisa melompat antar cluster.
var cluster_spawn_interval: float = 3.0     # jeda spawn cluster di awal (detik)
var cluster_spawn_interval_min: float = 1.2 # jeda tercepat saat kesulitan penuh (ramp)
var initial_spawn_delay: float = 1.0        # cluster PERTAMA muncul ~1 detik: player tidak
											# pernah menunggu sasaran di awal permainan
var cluster_swarm_min: int = 5              # jumlah swarm per cluster (acak min..max)
var cluster_swarm_max: int = 18
var cluster_heavy_max: int = 1              # Heavy per cluster. Dibatasi 1 karena heavy_min_distance
											# (250) melarang dua Heavy berdekatan — 2 Heavy dalam
											# satu cluster akan saling ditolak sendiri.
var cluster_heavy_chance: float = 0.5       # peluang sebuah cluster membawa Heavy (0-1).
											# Cluster tanpa Heavy = ancaman jenis lain.
var heavy_max_on_screen: int = 5            # Heavy hidup maksimal sekaligus
var heavy_min_distance: float = 250.0       # jarak minimal antar-Heavy saat spawn
var cluster_spawn_radius: float = 90.0      # sebaran anggota di sekitar pusat cluster saat spawn
var cluster_cohesion_weight: float = 0.4    # tarikan swarm ke pusat cluster-nya sendiri
											# (vs mengejar player) — menjaga cluster tetap utuh
var cluster_spacing_start: float = 400.0    # jarak minimal antar cluster di awal (HARUS > nuke_radius)
var cluster_spacing_end: float = 180.0      # jarak minimal saat kesulitan penuh (HARUS > nuke_radius/2)
var cluster_spacing_ramp: float = 60.0      # detik bertahan untuk mencapai spacing minimal.
											# Sengaja cepat: player harus SEGERA merasakan
											# arena mengetat dan chain mulai melompat cluster.
var score_ramp_full: float = 12000.0        # skor juga mempercepat ramp (main bagus = tekanan naik)
var heavy_start_time: float = 12.0          # Heavy baru ikut cluster setelah detik ini
var asteroid_start_time: float = 6.0        # asteroid baru muncul setelah detik ini
var max_swarms_on_screen: int = 80          # batas SWARM hidup. Terpisah dari kuota Heavy
											# & asteroid — kuota mereka penuh tidak boleh
											# memperlambat spawn swarm sedikit pun.

# ============ GAME OVER ============
var game_over_slowmo_scale: float = 0.25     # slow-motion saat player mati
var game_over_slowmo_time: float = 1.0       # lama slow-motion (detik real)

# ============ ASTEROID (objek netral abu-abu) ============
var asteroid_hp: int = 20                # 2 peluru
var asteroid_speed_min: float = 30.0     # melayang pelan
var asteroid_speed_max: float = 70.0
var asteroid_contact_damage: int = 10    # damage saat menabrak player
var asteroid_spawn_interval: float = 12.0 # jeda spawn asteroid (detik)
var asteroid_max_on_screen: int = 4       # asteroid = alat yang dicari player, bukan sampah
										 # layar. Kalau kuota penuh, spawn dilewati saja.

# ============ ASTEROID FRAGMENT (pecahan) ============
# Fragment = PEMBAWA chain antar cluster: terbang jauh, membunuh swarm
# sehat, dan MENGABAIKAN chain decay (kill oleh fragment = depth 0).
# Arah pecahan SELALU SAMA (tidak acak) supaya asteroid bisa
# direncanakan: player melihat asteroid dan sudah tahu ke mana
# pecahannya akan terbang, lalu memancing musuh ke garis-garis itu.
var fragment_count: int = 6              # 6 pecahan, jarak sudut merata = 60 derajat
var fragment_start_angle_deg: float = 0.0  # sudut pecahan pertama (0 = ke kanan), tetap
var fragment_speed: float = 320.0        # jangkauan = speed x lifetime ≈ 448 px,
var fragment_lifetime: float = 4       # cukup menjangkau cluster tetangga (spacing awal 400)
var fragment_damage: int = 12            # membunuh swarm sehat (HP 10) sekali kena

# ============ ABILITY PICKUP ============
# LANGKA — inilah yang menyeimbangkan Nuke yang menghapus total.
# Player harus sesekali memegang Nuke dan sengaja MENAHANNYA, menunggu
# kerumunan yang lebih besar. Keputusan itu cuma ada kalau pickup langka.
var ability_spawn_interval_min: float = 25.0  # jeda spawn pickup ability (acak min..max)
var ability_spawn_interval_max: float = 40.0
var ability_max_on_field: int = 1             # hanya 1 pickup ability belum diambil sekaligus

# ============ AMMO PICKUP (kotak abu-abu) ============
# JAUH lebih sering daripada pickup ability: ini ritme normal permainan.
# Player boleh sengaja menunda mengambilnya karena sedang menyiapkan chain.
var ammo_spawn_interval: float = 6.0     # jeda spawn pickup amunisi (detik)
var ammo_max_on_field: int = 4           # pickup amunisi belum diambil, maksimal sekaligus
var ammo_restore_amount: int = 8         # isi ulang penuh (= player_max_ammo)
var pickup_edge_margin: float = 120.0    # jarak minimal pickup dari tepi arena

# ============ SINGULARITY (pengumpul — TIDAK membunuh) ============
var singularity_radius: float = 240.0     # jangkauan tarikan
var singularity_pull_min: float = 60.0    # kecepatan tarik di tepi radius (pixel/detik)
var singularity_pull_max: float = 480.0   # kecepatan tarik di dekat pusat
var singularity_duration: float = 1.5     # lama aktif (detik)

# ============ NUKE (detonator — pemicu chain) ============
var nuke_radius: float = 280.0
# Nuke = senjata pamungkas langka: HAPUS TOTAL semua yang ada di dalam
# radius (swarm, Heavy, asteroid) — tanpa falloff, tanpa penyintas.
# Singularity tetap penting: ia menentukan BERAPA BANYAK objek yang
# berada di dalam radius saat Nuke meledak.
var nuke_damage: int = 9999               # dijamin one-shot apa pun (musuh & asteroid)
var nuke_self_damage: int = 60            # damage ke player DIPISAH supaya Nuke tidak
										  # one-shot player; masih dikali
										  # player_self_damage_multiplier (60 x 0.35 = 21 HP)
var nuke_duration: float = 0.3            # waktu ring mengembang 0 -> radius penuh
# Bobot visual: Nuke harus terasa sebagai kejadian TERBESAR di game.
var shake_nuke_intensity: float = 30.0
var shake_nuke_duration: float = 0.7
var hitstop_nuke: float = 0.25            # freeze di momen detonasi (terlama di game)
var nuke_zoom_punch: float = 0.90         # kamera zoom-out sesaat lalu kembali
var nuke_flash_strength: float = 0.7      # kilat putih layar penuh saat detonasi (0-1)
var nuke_flash_duration: float = 0.35     # lama kilat memudar (detik)

# ============ ENEMY SEPARATION (anti-tumpuk) ============
# Musuh saling mendorong ringan supaya tidak menumpuk di 1 titik —
# kaskade jadi terbaca sebagai rentetan, bukan satu kilatan.
# Tanpa physics collision (terlalu mahal untuk build web).
# Jarak dorong dihitung dari UKURAN BADAN masing-masing, bukan satu angka
# global. Dengan begitu swarm otomatis berhenti di LUAR badan Heavy yang
# jauh lebih besar, bukan menempel di jarak yang sama seperti sesama swarm.
var swarm_body_radius: float = 14.0        # radius badan swarm (swarm-swarm jadi ~30 px: tetap rapat)
var heavy_body_radius: float = 60.0        # radius badan Heavy (sprite-nya ~74 px dari pusat)
var asteroid_body_radius: float = 40.0     # radius badan asteroid (untuk jangkauan ledakan)
var separation_padding: float = 2.0        # jarak renggang tambahan antar badan
var separation_weight: float = 3         # kekuatan dorong vs arah mengejar.
										   # Terlalu besar = gerombolan buyar dan
										   # tidak bisa dikumpulkan — biarkan rapat.
var separation_update_interval: int = 4    # hitung ulang tiap N frame physics (hemat CPU)

# ============ CHAIN REACTION ============
# Ledakan kematian swarm HARUS bisa menyambung sendiri: burst kematian
# pertama sudah mematikan bagi swarm sehat di sekitarnya. Yang menjaga
# chain tetap punya akhir bukan lagi burst yang lemah, melainkan DECAY:
# tiap generasi berikutnya damage-nya menyusut sampai cuma melukai.
# Heavy & fragment mengabaikan decay (reset depth ke 0) -> alat penyambung.
var chain_time_window: float = 2.0       # detik tanpa reaksi = chain berakhir
var chain_stagger: float = 0.05          # jeda antar generasi ledakan (anti-freeze + terlihat kaskade)
var swarm_death_burst_radius: float = 70.0
var swarm_death_burst_damage: int = 10   # = swarm_hp: satu burst membunuh swarm sehat
										 # -> 1 kill di kerumunan langsung memicu kaskade
var chain_damage_decay: float = 0.8      # tiap kedalaman chain, damage burst dikali ini (80%).
										 # depth0=10 (bunuh), depth1=8, depth2=6, depth3=5 ...
										 # -> kaskade melemah sendiri dan akhirnya berhenti
var chain_max_depth: int = 12            # batas keras kedalaman propagasi (pengaman)
var heavy_explosion_radius: float = 170.0
var heavy_explosion_damage: int = 25     # membunuh swarm sehat; ABAIKAN decay, reset depth ke 0
var player_self_damage_multiplier: float = 0.35  # damage ledakan sendiri/chain ke player dikali ini

# ============ SCORE ============
var score_swarm: int = 100
var score_heavy: int = 500
var score_asteroid: int = 50             # dipakai mulai Phase 5
# skor kill = nilai dasar x chain saat itu (minimal x1)

# ============ JUICE (game feel) ============
# Kalau shake bikin pusing, kecilkan shake_global_multiplier (0 = mati total).
var shake_global_multiplier: float = 0.5
var shake_max: float = 34.0              # batas shake saat banyak event bersamaan.
										 # Dinaikkan supaya shake Nuke (30) tidak
										 # ikut terpotong jadi selevel Heavy.
var max_fx_nodes: int = 100               # batas node efek visual aktif (jaga performa).
										 # Dinaikkan dari 60: tiap kematian swarm kini
										 # memakai 2 node (animasi + ring).

var hit_flash_duration: float = 0.06     # kedip putih saat musuh kena peluru
var hit_punch_amount: float = 1.15       # musuh membesar sesaat saat kena hit
var hit_punch_duration: float = 0.12

# (shake kematian swarm sengaja DIHAPUS — lihat komentar di chain_manager.gd)
var shake_heavy_intensity: float = 12.0  # shake saat heavy meledak
var shake_heavy_duration: float = 0.35
var hitstop_heavy: float = 0.08          # freeze sesaat saat heavy meledak

var shake_player_hit_intensity: float = 6.0
var shake_player_hit_duration: float = 0.15

var shake_asteroid_intensity: float = 5.0  # shake saat asteroid pecah
var shake_asteroid_duration: float = 0.2
