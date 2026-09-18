extends Node

# =====================================================================
#  SAVE DATA (autoload)
#
#  Menyimpan rekor pemain: skor tertinggi & chain terbaik. Hanya dua
#  angka di user://save.cfg — di browser otomatis tersimpan di
#  IndexedDB, jadi tetap ada walau tab ditutup.
# =====================================================================

const SAVE_PATH := "user://save.cfg"

var high_score: int = 0
var best_chain: int = 0

# Hasil run terakhir — dipakai layar game over untuk menandai rekor baru.
var last_new_high_score: bool = false
var last_new_best_chain: bool = false


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		high_score = int(cfg.get_value("records", "high_score", 0))
		best_chain = int(cfg.get_value("records", "best_chain", 0))


# Pemain pertama kali = belum pernah mencetak skor.
func has_records() -> bool:
	return high_score > 0


# Dipanggil sekali saat player mati. Mengembalikan true kalau ada rekor baru.
func submit_run(score: int, chain: int) -> bool:
	last_new_high_score = score > high_score
	last_new_best_chain = chain > best_chain
	if not (last_new_high_score or last_new_best_chain):
		return false
	high_score = maxi(high_score, score)
	best_chain = maxi(best_chain, chain)
	_save()
	return true


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "high_score", high_score)
	cfg.set_value("records", "best_chain", best_chain)
	cfg.save(SAVE_PATH)


# 128400 -> "128,400" (dipakai menu & layar game over).
static func format_thousands(value: int) -> String:
	var s := str(value)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
