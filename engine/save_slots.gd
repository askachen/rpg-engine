class_name SaveSlots
extends RefCounted
## Slot 0 is automatic; 1–6 are manual. Legacy slot1 keeps its original filename.
const COUNT := 6
var core
var directory: String

func _init(game_core, base_directory: String = "user://") -> void:
	core = game_core
	directory = base_directory

func path(slot: int) -> String:
	if slot < 0 or slot > COUNT: return ""
	return directory.path_join(str(core.content.id) + ("_auto.json" if slot == 0 else "_slot%d.json" % slot))

func save(slot: int) -> bool:
	if path(slot).is_empty(): return false
	return core.save_game(path(slot))

func load_slot(slot: int) -> bool:
	if path(slot).is_empty(): return false
	return core.load_game(path(slot))

func details(slot: int) -> Dictionary:
	var filename := path(slot)
	var exists := not filename.is_empty() and FileAccess.file_exists(filename)
	var data: Dictionary = core.read_save(filename) if exists else {}
	var reason: String = core.save_error
	var backup: Dictionary = core.read_save(filename+".bak") if filename != "" else {}
	var stamp = data.get("saved_at", 0)
	if not (stamp is float or stamp is int) or stamp <= 0:
		stamp = FileAccess.get_modified_time(filename) if exists else 0
	return {"slot": slot, "exists": exists, "valid": not data.is_empty(), "data": data,
		"saved_at": stamp, "reason":reason, "recoverable":not backup.is_empty(), "backup":backup, "backup_exists":FileAccess.file_exists(filename+".bak")}

func latest() -> int:
	var chosen := -1
	var newest := -1.0
	for slot in range(COUNT + 1):
		var info := details(slot)
		if info.valid and float(info.saved_at) > newest:
			chosen = slot
			newest = float(info.saved_at)
	return chosen

func restore(slot: int) -> bool:
	if path(slot).is_empty() or core.active_event != "" or core.replay_mode: return false
	var writer = preload("res://engine/atomic_save.gd").new()
	var ok: bool = writer.restore(core,path(slot))
	core.save_error = writer.error
	return ok

func delete_slot(slot: int) -> bool:
	if path(slot).is_empty() or core.active_event != "" or core.replay_mode: return false
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var filename: String = path(slot)+suffix
		if FileAccess.file_exists(filename) and DirAccess.remove_absolute(filename) != OK: return false
	return true
