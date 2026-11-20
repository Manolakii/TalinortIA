class_name HealthComponent
extends Node
## Vida, invulnerabilidad y resistencia al daño.

signal damaged(info: DamageInfo)
signal died(info: DamageInfo)
signal healed(amount: float)
signal changed(current: float, maximum: float)
## El escudo cambió (para dibujarlo). `maximum` es lo que tenía al ponérselo.
signal shield_changed(amount: float, maximum: float)
signal shield_broken

var max_health: float = 100.0
var current: float = 100.0
## 0.7 = recibe 30% menos de daño.
var damage_taken_multiplier: float = 1.0
var is_dead: bool = false
## Escudo: absorbe daño antes que la vida (Bendición, Garrocha al Rescate).
var shield: float = 0.0
var shield_max: float = 0.0
## Si es mayor que 0, el escudo se va solo cuando se termina este tiempo.
var _shield_time_left: float = 0.0
## Cuánto escudo se pierde por segundo (0 = no se gasta solo).
var _shield_decay: float = 0.0
var _invulnerable_left: float = 0.0


func setup(maximum: float) -> void:
	max_health = maximum
	current = maximum
	is_dead = false
	changed.emit(current, max_health)


## Lo llama el dueño en su _physics_process (así respeta el hitstop).
func tick(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	if _shield_decay > 0.0 and shield > 0.0:
		shield = maxf(shield - _shield_decay * delta, 0.0)
		shield_changed.emit(shield, shield_max)
		if shield <= 0.0:
			_shield_decay = 0.0
	if _shield_time_left > 0.0:
		_shield_time_left -= delta
		if _shield_time_left <= 0.0:
			clear_shield()


func make_invulnerable(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Descuenta vida. Devuelve el daño real aplicado.
func apply_damage(info: DamageInfo) -> float:
	if is_dead:
		return 0.0
	var final_amount: float = maxf(info.amount * damage_taken_multiplier, 0.0)
	if shield > 0.0:
		var absorbed: float = minf(shield, final_amount)
		shield -= absorbed
		final_amount -= absorbed
		shield_changed.emit(shield, shield_max)
		if shield <= 0.0:
			shield = 0.0
			shield_broken.emit()
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


## `duration`: si es mayor que 0, el escudo dura ese tiempo (cada vez que se suma, se renueva).
func add_shield(amount: float, duration: float = 0.0) -> void:
	if duration > 0.0:
		_shield_time_left = duration
	if amount <= shield:
		return
	shield = amount
	shield_max = amount
	shield_changed.emit(shield, shield_max)


## Escudo que se va gastando solo a lo largo de `seconds` (Revoleo blindado de Tali).
func add_decaying_shield(amount: float, seconds: float) -> void:
	add_shield(amount)
	_shield_decay = amount / maxf(seconds, 0.1)


func clear_shield() -> void:
	if shield <= 0.0:
		return
	shield = 0.0
	_shield_time_left = 0.0
	shield_changed.emit(0.0, shield_max)


func shield_ratio() -> float:
	return clampf(shield / shield_max, 0.0, 1.0) if shield_max > 0.0 else 0.0


func restore_full() -> void:
	is_dead = false
	current = max_health
	changed.emit(current, max_health)


func ratio() -> float:
	return current / max_health if max_health > 0.0 else 0.0
