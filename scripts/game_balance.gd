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
# Ukuran arena permainan dalam pixel. Layar = 960x720, arena = ukuran
# background parallax (assets/sprites/Background-Paralax, 1600x1200),
# arena sedikit lebih besar supaya kamera bisa bergeser.
var arena_width: float = 1600.0
var arena_height: float = 1200.0

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
# Batas SWARM hidup NAIK BERTAHAP, tidak langsung di angka maksimal.
# Terpisah dari kuota Heavy & asteroid — kuota mereka penuh tidak boleh
# memperlambat spawn swarm sedikit pun.
# Awal 80: chain masih terbaca & performa aman saat pemain belajar.
# Akhir 400: arena benar-benar penuh, chain melompat ke mana-mana.
# Patokannya SKOR saja, bukan waktu bertahan: kepadatan naik karena
# pemain bermain bagus, bukan karena sekadar bertahan lama.
var max_swarms_start: int = 80               # batas saat skor 0
var max_swarms_end: int = 400                # batas tertinggi (mentok di sini)
var max_swarms_ramp_score: float = 5000000.0 # skor untuk mencapai batas penuh

# ============ GAME OVER ============
var game_over_slowmo_scale: float = 0.25     # slow-motion saat player mati
var game_over_slowmo_time: float = 1.0       # lama slow-motion (detik real)
var gameover_fade_time: float = 0.4          # fade layar saat pindah game over -> menu

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
var fragment_arm_time: float = 0.5       # pecahan belum bisa mengenai apa pun selama ini.
										 # Tanpa jeda ini, asteroid yang hancur di tengah
										 # kerumunan langsung "memakan" pecahannya sendiri
										 # di frame pertama dan pecahan tidak terlihat.

# ============ ABILITY PICKUP ============
# LANGKA — inilah yang menyeimbangkan Nuke yang menghapus total.
# Player harus sesekali memegang Nuke dan sengaja MENAHANNYA, menunggu
# kerumunan yang lebih besar. Keputusan itu cuma ada kalau pickup langka.
var ability_spawn_interval_min: float = 25.0  # jeda spawn pickup ability (acak min..max)
var ability_spawn_interval_max: float = 40.0
var ability_max_on_field: int = 1             # hanya 1 pickup ability belum diambil sekaligus
# Pickup pertama sengaja cepat & dipastikan NUKE: saat demo/penilaian,
# skill langsung bisa ditunjukkan tanpa menunggu lama.
var ability_first_spawn_delay: float = 10.0
var ability_first_is_nuke: bool = true

# ============ AMMO PICKUP (kotak abu-abu) ============
# JAUH lebih sering daripada pickup ability: ini ritme normal permainan.
# Player boleh sengaja menunda mengambilnya karena sedang menyiapkan chain.
var ammo_spawn_interval: float = 12.0    # jeda spawn pickup amunisi (detik). Dari 6 -> 12:
										 # amunisi 2x lebih langka supaya tidak bisa spam tembak
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

# --- Feedback saat MENEMBAK (aksi paling sering dilakukan pemain) ---
# Sengaja tanpa screen shake: fire rate tinggi, shake per peluru bikin pusing.
var muzzle_flash_time: float = 0.09       # lama kilatan di moncong (detik)
var muzzle_flash_radius: float = 7.0      # besar bola kilatan
var muzzle_flash_length: float = 22.0     # panjang garis kilatan ke arah tembak
var muzzle_flash_color: Color = Color(1.0, 0.95, 0.72)
var shoot_recoil_distance: float = 3.5    # mundurnya badan kapal saat menembak (px)
var shoot_recoil_recover: float = 38.0    # kecepatan kembali ke posisi semula (px/detik)

# ============ AUDIO (volume bus) ============
# Musik & SFX punya bus terpisah (lihat panel Audio di bawah editor).
# Musik HARUS jauh lebih pelan dari SFX — ledakan chain adalah bintangnya,
# musik hanya suasana. 0 dB = volume asli, -6 dB ≈ setengah terasa.
var music_volume_db: float = -16.5   # = 75% dari -14 dB (linear_to_db(0.75) = -2.5)
var sfx_volume_db: float = 0.0
var music_fade_in_time: float = 1.5      # detik musik naik perlahan saat mulai
var music_fade_out_time: float = 1.0     # detik musik turun saat stop_music()

# ============ MAIN MENU ============
var menu_prompt_pulse_time: float = 0.8  # detik satu denyut "TEKAN SPACE UNTUK MULAI"
var menu_input_delay: float = 0.3        # jeda awal sebelum menu menerima tombol
										 # (cegah tombol R/ESC dari game over ikut
										 # langsung memulai game lagi)

# ============ MAIN MENU — DEMO LATAR ============
# Di belakang menu, game berjalan sendiri tanpa player (mode demo).
var menu_demo_dim: float = 0.45           # 0 = demo tak terlihat, 1 = terang penuh
var menu_demo_chain_interval: float = 4.0 # detik antar chain otomatis
var menu_demo_camera_zoom: float = 0.8    # < 1 = zoom out (lihat arena lebih luas)
var menu_demo_wander_radius: float = 260.0 # seberapa jauh titik kumpul musuh berkeliling
var menu_demo_wander_speed: float = 60.0  # kecepatan titik kumpul (px/detik)
var menu_demo_sfx_volume_db: float = -10.0 # SFX demo lebih pelan dari saat bermain

# ============ SPACE WORM (rintangan panjang hijau) ============
# Bukan umpan chain: tidak ditarik Singularity, tidak kena burst chain.
# Badan beruas: kepala + ruas-ruas ($Visual/SegmentN) yang mengikuti jejak kepala.
var worm_hp: int = 200
var worm_drift_speed: float = 60.0
var worm_turn_rate: float = 2.0           # rad/detik — seberapa cepat berbelok ke target
var worm_wander_radius: float = 220.0     # target = player + offset acak sejauh ini
var worm_wander_interval: float = 3.0     # detik antar ganti offset acak
var worm_edge_margin: float = 80.0        # target drift dijaga sejauh ini dari tepi arena
var worm_segment_spacing: float = 20.0    # jarak antar ruas di sepanjang jejak kepala
										  # (panjang badan = spacing x jumlah ruas)
var worm_trail_resolution: float = 3.0    # kepala dicatat ke jejak tiap bergeser sejauh ini (px)

# Serangan lunge: berhenti -> telegraph (garis peringatan) -> dash lurus.
var worm_attack_interval: float = 4.0     # detik melayang antar lunge
var worm_attack_range: float = 650.0      # hanya menyerang kalau player sedekat ini
										  # (cegah lunge dari luar layar tanpa terlihat)
var worm_telegraph_time: float = 0.6      # jendela peringatan sebelum dash — waktu menghindar
var worm_telegraph_turn_rate: float = 10.0 # rad/detik badan berbelok ke arah dash saat telegraph
var worm_telegraph_blink_time: float = 0.1 # setengah siklus kedip garis & badan
var worm_telegraph_line_width: float = 6.0
var worm_lunge_speed: float = 900.0         # dinaikkan dari 700 supaya dash panjang tetap ~1 detik
var worm_lunge_distance: float = 900.0    # panjang dash = panjang garis peringatan (dari 500)
var worm_recover_time: float = 0.5        # diam sesaat setelah dash, lalu melayang lagi
var worm_contact_damage: int = 25         # kalau badan saat dash menyentuh player
var worm_contact_padding: float = 14.0    # tambahan jarak sentuh (kira-kira jari-jari player)
var worm_lunge_shake_intensity: float = 3.0
var worm_lunge_shake_duration: float = 0.15

# Ledakan saat mati: GARIS sepanjang badan (ikut lengkungannya), bukan
# lingkaran. Kill dari ledakan ini = event chain dengan depth 0 (seperti Heavy).
var worm_explosion_damage: int = 40
var worm_explosion_width: float = 170.0   # tebal garis ledakan = 2 x jangkauan. 170 -> jangkauan
										  # 85 px dari badan (burst swarm 70 px, jadi ~1.2x swarm)
var worm_explosion_flash_time: float = 0.35 # lama kilatan garis memudar
var worm_explosion_flash_alpha: float = 0.45 # kepekatan kilatan garis (1 = menutupi semua)
var worm_ring_duration: float = 0.3       # lama ring ledakan di tiap ruas
var shake_worm_intensity: float = 16.0
var shake_worm_duration: float = 0.4
var hitstop_worm: float = 0.1
var score_worm: int = 400                 # skor membunuh worm (dikali chain aktif, min x1)

# Spawn berdasarkan skor, terpisah total dari spawn swarm/heavy/asteroid.
var worm_first_score: int = 1500          # skor saat worm pertama muncul
var worm_score_step: int = 1000000        # tiap 1 juta skor, batas worm +1 (dari 3000)
var worm_max_cap: int = 4                 # batas keras worm bersamaan
var worm_spawn_cooldown: float = 6.0      # jeda minimal antar spawn worm (juga setelah worm mati)
var worm_spawn_min_player_distance: float = 500.0 # worm muncul di tepi, sejauh ini dari player

# ============ BACKGROUND PARALLAX ============
# Seberapa ikut tiap layer bergerak bersama kamera: 1.0 = menempel dunia
# (seperti musuh), 0.0 = diam menempel layar. Makin kecil = terasa makin jauh.
# Urutan = Layer 1 (deep space, paling jauh) ... Layer 5 (paling dekat).
var parallax_scroll_scales: Array[float] = [0.05, 0.15, 0.3, 0.5, 0.75]

# Worm vs ledakan chain: damage burst swarm biasanya mengecil tiap langkah
# chain (chain_damage_decay). Untuk worm, damage dari ledakan chain apa pun
# minimal sebesar ini — jadi SETIAP ledakan yang menimpanya terasa, dan
# kaskade besar di sekitar worm benar-benar bisa membunuhnya.
var worm_min_chain_damage: int = 10

# ============ CHARGED LASER (didapat dari SKOR, bukan pickup) ============
# Laser READY tiap kali skor melewati ambang berikutnya. Ambang makin mahal.
# Maksimal 1 charge dipegang. Setelah ambang di daftar habis, ambang
# berikutnya = ambang terakhir + laser_threshold_step, dst.
var laser_score_thresholds: Array[int] = [100000, 5000000, 9000000]
var laser_threshold_step: int = 5000000
var laser_charge_color: Color = Color("#4DA6FF")   # biru laser (bar READY, ring, beam)
var laser_gauge_pulse_time: float = 0.9            # satu denyut bar saat READY
# --- Wind-up (charge-up): ring biru menyusut ke kapal, lalu beam menembak.
var laser_charge_time: float = 0.7
var laser_charge_ring_count: int = 3
var laser_charge_ring_start_radius: float = 140.0
var laser_charge_ring_width: float = 2.0
var laser_charge_shake: float = 2.0       # getaran yang membesar selama wind-up
var laser_charge_ship_glow: float = 1.7   # kapal makin terang saat ring tiba (1 = normal)
# --- Beam
var laser_duration: float = 3.5           # detik tembakan terus-menerus
var laser_width: float = 26.0
var laser_range: float = 1200.0           # praktis sampai luar layar
var laser_damage_per_second: float = 400.0
var laser_tick_interval: float = 0.05     # damage diberikan tiap interval ini (bukan tiap frame)
var laser_move_speed_mult: float = 0.55   # kecepatan gerak player saat menembak laser
var laser_beam_shake: float = 5.0         # getaran selama beam aktif
var laser_zoom: float = 0.97              # kamera sedikit zoom-out saat beam aktif
var laser_zoom_time: float = 0.25
var laser_fade_time: float = 0.2          # beam memudar saat selesai (tanpa damage)
var laser_end_flash_strength: float = 0.25
var laser_no_charge_flash_time: float = 0.35 # gauge berkedip kalau F ditekan tanpa charge
var laser_fire_loop_pitch: float = 1.6     # pitch suara loop beam (placeholder = suara Singularity, dinaikkan supaya beda)

# ============ AUDIO — PERFORMA ============
# Event suara yang SAMA tidak diputar ulang lebih cepat dari ini (detik).
# Saat kaskade besar puluhan musuh mati di frame yang sama; memutar
# puluhan suara identik sekaligus tidak terdengar bedanya tapi sangat
# berat (tiap play me-restart decoder OGG), terutama di browser.
var audio_same_event_min_interval: float = 0.03

# ============ HEAL PICKUP (tanda plus hijau) ============
# Memulihkan HP. Hanya muncul saat HP player belum penuh, dan hanya bisa
# diambil kalau masih kurang dari maksimal — jadi tidak pernah terbuang.
var heal_amount: int = 30
var heal_spawn_interval_min: float = 20.0
var heal_spawn_interval_max: float = 32.0
var heal_max_on_field: int = 1

# ============ BAR HP MUSUH (Heavy & Space Worm) ============
# Bar kecil di atas musuh bernyawa tebal: muncul setelah kena hit pertama.
# Bagian putih ("chip") menyusul turun sedikit terlambat, jadi beberapa
# ledakan beruntun terbaca sebagai damage yang MENUMPUK.
var healthbar_chip_delay: float = 0.25
var healthbar_chip_time: float = 0.3

# ============ KECEPATAN GAME (chaos ramp) ============
# Tiap kelipatan skor ini, SELURUH game berjalan lebih cepat (Engine
# time scale): musuh, spawn, peluru, animasi — semuanya. Makin jauh
# bertahan = makin kacau.
var game_speed_score_step: int = 2000000
var game_speed_increment: float = 0.25   # +25% tiap tangga
var game_speed_max: float = 2.0          # mentok 2x kecepatan normal

# ============ KAMERA & PENANDA ANCAMAN ============
# Arena (1600x1200) lebih besar dari layar (960x720), jadi ada musuh yang
# datang dari luar pandangan. Dua penangkalnya:
#   1) kamera sedikit di-zoom out  2) panah kecil di tepi layar
var camera_zoom: float = 0.9              # < 1 = lihat lebih luas (0.9 -> 1067x800)
var threat_indicator_margin: float = 26.0 # jarak panah dari tepi layar
var threat_indicator_margin_top: float = 62.0 # lebih longgar di atas: ada SCORE & CHAIN di sana
var threat_indicator_size: float = 13.0   # besar panah
var threat_indicator_update_frames: int = 3  # hitung ulang tiap N frame (hemat CPU)
var threat_indicator_min_distance: float = 60.0 # abaikan target yang nyaris di layar
