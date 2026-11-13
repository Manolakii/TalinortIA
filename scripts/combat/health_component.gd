class_name HealthComponent
extends Node
## Vida, invulnerabilidad y resistencia al daño.

signal damaged(info: DamageInfo)
signal died(info: DamageInfo)
signal healed(amount: float)
signal changed(current: float, maximum: float)

var max_health: float = 100.0
var current: float = 100.0
## 0.7 = recibe 30% menos de daño.
var damage_taken_multiplier: float = 1.0
var is_dead: bool = false
var _invulnerable_left: float = 0.0


func setup(maximum: float) -> void:
	max_health = maximum
	current = maximum
	is_dead = false
	changed.emit(current, max_health)


## Lo llama el dueño en su _physics_process (así respeta el hitstop).
func tick(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)


func make_invulnerable(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Descuenta vida. Devuelve el daño real aplicado.
func apply_damage(info: DamageInfo) -> float:
	if is_dead:
		return 0.0
	var final_amount: float = maxf(info.amount * damage_taken_multiplier, 0.0)
	current = maxf(current - final_amount, 0.0)
	info.final_amount = final_amount
	damaged.emit(info)
	changed.emit(current, max_health)
	if current <= 0.0:
		is_dead = true
		died.emit(info)
	return final_amount


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current = minf(current + amount, max_health)
	healed.emit(amount)
	changed.emit(current, max_health)


func restore_full() -> void:
	is_dead = false
	current = max_health
	changed.emit(current, max_health)


func ratio() -> float:
	return current / max_health if max_health > 0.0 else 0.0
