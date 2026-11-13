class_name AbilityCooldown
extends RefCounted
## Cooldown con cargas. Con 1 carga es un cooldown común; con 2, como la esquiva,
## cada carga se recarga por separado (una detrás de la otra).

var max_charges: int = 1
var charges: int = 1
## Segundos para recargar UNA carga.
var recharge_time: float = 1.0
var _progress: float = 0.0


func _init(cooldown: float = 1.0, charge_count: int = 1) -> void:
	recharge_time = cooldown
	max_charges = maxi(charge_count, 1)
	charges = max_charges


func tick(delta: float) -> void:
	if charges >= max_charges:
		_progress = 0.0
		return
	_progress += delta
	while _progress >= recharge_time and charges < max_charges:
		_progress -= recharge_time
		charges += 1
	if charges >= max_charges:
		_progress = 0.0


func is_ready() -> bool:
	return charges > 0


## Gasta una carga. Devuelve false si no había.
func use() -> bool:
	if charges <= 0:
		return false
	charges -= 1
	return true


## Segundos hasta tener al menos una carga (0 si ya hay).
func time_until_ready() -> float:
	return 0.0 if charges > 0 else recharge_time - _progress


## Adelanta la recarga (por ejemplo, "recupera la mitad del cooldown").
func reduce(seconds: float) -> void:
	if charges < max_charges:
		tick(seconds)


func refill() -> void:
	charges = max_charges
	_progress = 0.0
