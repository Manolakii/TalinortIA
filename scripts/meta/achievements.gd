class_name Achievements
extends RefCounted
## Logros (pedido del grupo, 2026-11-16). Son del grupo, como la McoinIA: se guardan en la compu
## (user://logros.cfg). Los textos están en data/texts/logros.json. Al desbloquear uno avisa
## por Events.achievement_unlocked (el HUD muestra el cartelito).

const PATH := "user://logros.cfg"
const TEXTS := "res://data/texts/logros.json"

static var _loaded: bool = false
static var _unlocked: Array = []
static var _texts: Dictionary = {}
## Para los tests: no tocar el archivo de verdad.
static var save_enabled: bool = true


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	# Corriendo los tests (GUT) nunca se toca el archivo de verdad.
	for arg: String in OS.get_cmdline_args():
		if arg.contains("gut_cmdln"):
			save_enabled = false
	var file := FileAccess.open(TEXTS, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_texts = parsed
			_texts.erase("_nota")
	if not save_enabled:
		return
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		_unlocked = config.get_value("logros", "desbloqueados", [])


## Todos los ids, en el orden del archivo.
static func all_ids() -> Array:
	_ensure()
	return _texts.keys()


static func title(id: String) -> String:
	_ensure()
	return _texts.get(id, {}).get("nombre", id)


static func how(id: String) -> String:
	_ensure()
	return _texts.get(id, {}).get("como", "")


static func is_unlocked(id: String) -> bool:
	_ensure()
	return _unlocked.has(id)


static func unlocked_count() -> int:
	_ensure()
	return _unlocked.size()


## Desbloquea un logro (si no lo tenían). Devuelve true si es nuevo.
static func unlock(id: String) -> bool:
	_ensure()
	if _unlocked.has(id) or not _texts.has(id):
		return false
	_unlocked.append(id)
	if save_enabled:
		var config := ConfigFile.new()
		config.set_value("logros", "desbloqueados", _unlocked)
		config.save(PATH)
	Events.achievement_unlocked.emit(title(id), how(id))
	Sound.play("chest", -6.0, 0.0)
	return true


static func reset_for_tests() -> void:
	save_enabled = false
	_loaded = false
	_unlocked = []
	_ensure()
