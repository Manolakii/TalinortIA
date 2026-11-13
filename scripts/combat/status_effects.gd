class_name StatusEffects
extends Node
## Estados con duración: aturdido, ciego, asustado, agotado, ralentizado...

const STUN: StringName = &"stun"
const BLIND: StringName = &"blind"
const FEAR: StringName = &"fear"
const EXHAUSTED: StringName = &"exhausted"
const SLOW: StringName = &"slow"
## Más rápido (rastro del Croco). El multiplicador está en CombatConfig.
const HASTE: StringName = &"haste"

signal effect_started(effect: StringName)
signal effect_ended(effect: StringName)

var _timers: Dictionary[StringName, float] = {}


## Aplica un efecto. Si ya estaba, se queda con la duración más larga.
func apply(effect: StringName, duration: float) -> void:
	if duration <= 0.0:
		return
	var was_active: bool = has(effect)
	_timers[effect] = maxf(_timers.get(effect, 0.0), duration)
	if not was_active:
		effect_started.emit(effect)


func has(effect: StringName) -> bool:
	return _timers.get(effect, 0.0) > 0.0


func remaining(effect: StringName) -> float:
	return _timers.get(effect, 0.0)


func clear(effect: StringName) -> void:
	if _timers.erase(effect):
		effect_ended.emit(effect)


func clear_all() -> void:
	for effect: StringName in _timers.keys():
		clear(effect)


## Lo llama el dueño en su _physics_process (así respeta el hitstop).
func tick(delta: float) -> void:
	for effect: StringName in _timers.keys():
		_timers[effect] -= delta
		if _timers[effect] <= 0.0:
			_timers.erase(effect)
			effect_ended.emit(effect)
