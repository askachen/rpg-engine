extends RefCounted
## Same-directory temp + rename; the last valid primary becomes the backup.
var error := ""

func write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: error = "write_open_failed"; return false
	file.store_string(text)
	file.flush()
	var code := file.get_error()
	file.close()
	if code != OK: error = "write_failed"; return false
	return true

func save(core, path: String, data: Dictionary) -> bool:
	var contract = preload("res://engine/save_contract.gd").new()
	if contract.validate(core,data).is_empty(): error = contract.error; return false
	if not write_text(path+".tmp",JSON.stringify(data)): return false
	if contract.read(core,path+".tmp").is_empty(): error = "temporary_validation_failed"; return false
	if not contract.read(core,path).is_empty():
		if not write_text(path+".bak.tmp",FileAccess.get_file_as_string(path)): return false
		if contract.read(core,path+".bak.tmp").is_empty(): error = "backup_validation_failed"; return false
		if DirAccess.rename_absolute(path+".bak.tmp",path+".bak") != OK: error = "backup_replace_failed"; return false
	if DirAccess.rename_absolute(path+".tmp",path) != OK: error = "primary_replace_failed"; return false
	return true

func restore(core, path: String) -> bool:
	var contract = preload("res://engine/save_contract.gd").new()
	if contract.read(core,path+".bak").is_empty(): error = contract.error; return false
	if not write_text(path+".tmp",FileAccess.get_file_as_string(path+".bak")): return false
	if contract.read(core,path+".tmp").is_empty(): error = "temporary_validation_failed"; return false
	if DirAccess.rename_absolute(path+".tmp",path) != OK: error = "restore_failed"; return false
	return true
