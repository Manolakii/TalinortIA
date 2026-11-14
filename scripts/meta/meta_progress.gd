class_name MetaProgress
extends RefCounted
## Progreso entre partidas: McoinIA y las mejoras compradas (GDD). Se guarda en la compu
## (user://mcoinia.cfg) y es del grupo: juegan todos en la misma.

const PATH := "user://mcoinia.cfg"

static var _loaded: bool = false
static var balance: int = 0
static var _levels: Dictionary = {}
## Para los tests: no tocar el archivo de verdad.
static var save_enabled: bool = true


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	balance = int(config.get_value("mcoinia", "balance", 0))
	_levels = config.get_value("mcoinia", "levels", {})


static func save() -> void:
	if not save_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("mcoinia", "balance", balance)
	config.set_value("mcoinia", "levels", _levels)
	config.save(PATH)


static func get_balance() -> int:
	_ensure()
	return balance


static func level(id: StringName) -> int:
	_ensure()
	return int(_levels.get(String(id), 0))


static func add(amount: int) -> void:
	_ensure()
	balance += amount
	save()


## Compra el siguiente nivel. Devuelve false si no alcanza o ya está al máximo.
static func buy(upgrade: McoiniaUpgrade) -> bool:
	_ensure()
	var current: int = level(upgrade.id)
	if current >= upgrade.max_level():
		return false
	var cost: int = upgrade.costs[current]
	if balance < cost:
		return false
	balance -= cost
	_levels[String(upgrade.id)] = current + 1
	save()
	return true


## Para los tests.
static func reset_for_tests() -> void:
	_loaded = true
	save_enabled = false
	balance = 0
	_levels = {}


## Suma de una mejora: nivel × cantidad por nivel.
static func bonus(id: StringName) -> float:
	var upgrade: McoiniaUpgrade = Balance.mcoinia.get_upgrade(id)
	return level(id) * upgrade.amount if upgrade != null else 0.0
