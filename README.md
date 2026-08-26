# [Nama Game]

Game jam entry — IFEST 2026
Tema: **Chain Reaction**

2D top-down arena shooter. Kumpulkan musuh dengan Singularity,
picu ledakan berantai dengan Nuke, kejar chain setinggi mungkin.

## Kontrol
| Aksi | Tombol |
|---|---|
| Gerak | WASD |
| Tembak | Mouse kiri / Space |
| Singularity | Q |
| Nuke | E |
| Restart | R |

## Menjalankan
Godot 4.7, renderer Compatibility. Buka `project.godot`, tekan Play.

## Tim
- [nama] — programming
- [nama] — art

## Dokumen
- `CLAUDE.md` — spec teknis
- `ASSET_GUIDE.md` — panduan pembuatan asset
## Daftar asset lengkap

**Player (3 item)**
- Ship — 32×32 px, hadap ke atas, warna dominan cyan/putih. Nanti dirotasi lewat kode buat ngarah ke kursor, jadi gambar cuma satu arah aja
- Thruster/api belakang — 16×16, 2-3 frame animasi (loop)
- Projectile — 8×8 atau 4×12, putih terang

**Enemy (3 item)**
- Swarm — 16×16, merah, siluet tajam/agresif. Ini yang paling sering muncul di layar, jadi harus gampang dibedain walau banyak
- Heavy — 48×48, merah gelap, bentuknya berat/tebal. Harus **langsung kelihatan beda** dari swarm dari jauh — ini penting buat gameplay, karena pemain harus bisa spot Heavy dalam sekejap
- Asteroid — 32×32, abu-abu, bentuk nggak beraturan. Bikin 2-3 variasi biar nggak monoton

**Pecahan & efek (5 item)**
- Asteroid fragment — 8×8 atau 12×12, abu-abu, 2-3 variasi bentuk
- Ledakan kecil (swarm death) — 32×32, 4-5 frame
- Ledakan besar (heavy death) — 96×96, 5-6 frame
- Ring expansion — bisa digambar atau di-generate kode. **Bilang ke temanmu: skip aja dulu**, ini paling gampang dibikin lewat kode
- Muzzle flash — 12×12, 2 frame

**Ability (4 item)**
- Singularity — 96×96, ungu, idealnya 4-6 frame animasi berputar (loop). Ini asset yang paling worth diberi waktu ekstra karena tampil besar dan lama di layar
- Nuke blast — bisa pakai ring + flash dari kode, tapi kalau mau digambar: 128×128, 5-6 frame
- Pickup Singularity — 16×16, biru, ada indikator kecil biar beda
- Pickup Nuke — 16×16, kuning/oranye

**Environment (2 item)**
- Background — tile 256×256 yang bisa di-repeat, biru sangat gelap/hitam
- Bintang parallax — beberapa titik kecil, 2 layer (dekat & jauh) buat efek kedalaman

**UI (opsional, 2 item)**
- Font pixel — **jangan bikin sendiri**, ambil yang berlisensi bebas (Google Fonts punya beberapa pixel font, atau itch.io banyak yang CC0). Bikin font itu makan waktu berhari-hari
- Frame HUD sederhana — kalau ada waktu sisa

---

## Prioritas kalau waktu mepet

**Wajib:** ship, swarm, heavy, asteroid, projectile, ledakan kecil, ledakan besar, singularity, 2 pickup, background

**Nice to have:** thruster, fragment variasi, muzzle flash, nuke frames, bintang parallax

**Skip dulu:** frame HUD, variasi asteroid ke-3, ring (biarin kode yang handle)

Totalnya sekitar **11 asset wajib** — realistis buat 2-3 hari kerja seorang artist.

---

## Detail Info

**Ukuran pixel harus konsisten.** Kalau ship digambar di kanvas 32×32 dengan pixel 1:1, semua asset lain harus pakai skala yang sama. Jangan ada yang digambar di 64×64 terus di-scale down — hasilnya blur dan merusak konsistensi.

**Semua sprite hadap ke ATAS.** Rotasi diurus kode. Kalau digambar hadap kanan, nanti semua arahnya meleset 90°.

**Titik tengah harus pas di tengah kanvas.** Kalau ship-nya agak ke kiri di kanvas, rotasinya bakal goyang aneh saat mengikuti kursor.

**Palet dibatasi.** Sarankan maksimal 16-24 warna total untuk seluruh game. Ini bikin visual terasa menyatu, dan justru mempercepat kerja karena nggak perlu mikir warna tiap kali.

**Format PNG dengan transparansi**, bukan JPG.

**Kontras dengan background gelap.** Semua entity harus kebaca jelas di atas biru-gelap. Warna gelap di atas background gelap = pemain nggak lihat musuh = frustasi.

---

## Cara serah-terima

Temanmu taruh file di `assets/sprites/` dengan nama yang persis sesuai entity-nya:
```
player_ship.png
enemy_swarm.png
enemy_heavy.png
asteroid_01.png
projectile.png
fx_explosion_small.png
fx_explosion_large.png
ability_singularity.png
pickup_singularity.png
pickup_nuke.png
bg_space.png
```


