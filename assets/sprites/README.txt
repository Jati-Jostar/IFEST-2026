FOLDER SPRITE — UNTUK ARTIST
============================

Taruh semua file pixel art (.png) di folder ini.

Cara pasang sprite ke game (tanpa menyentuh kode):
1. Buka scene entity-nya (misal scenes/player.tscn).
2. Di dalam node "Visual" ada node "Placeholder" (bentuk warna polos).
3. Hapus "Placeholder", lalu tambahkan Sprite2D / AnimatedSprite2D
   sebagai child dari "Visual", dan drag file .png-mu ke situ.
4. Pastikan sprite tetap berpusat di titik (0,0) node Visual.

Jangan sentuh node CollisionShape2D atau node lain di luar "Visual".

Ukuran sprite yang disarankan menyusul di dokumen akhir
(kira-kira samakan dengan ukuran placeholder-nya).
