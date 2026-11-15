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
## Acelerado por el Chamán de la Sombra.
const SHADOW_HASTE: StringName = &"shadow_haste"
## Golpe Guía del Maestro: recibe más daño de Stewie y los aliados.
const MARKED: StringName = &"marked"
## Dentro de la Niebla de los Valles: sus ataques fallan más.
const FOGGED: StringName = &"fogged"
## Oculto en la nube de la Garrocha de Niebla: los enemigos no lo ven.
const HIDDEN: StringName = &"hidden"
## Bombito de Birig Bamba: +15% de velocidad.
const BOMBITO: StringName = &"bombito"
## Botas de Cartero: +25% de velocidad después de esquivar.
const MAILMAN: StringName = &"mailman"
## Esporas de la Floración: el enemigo se confunde y les pega a los suyos.
const CONFUSED: StringName = &"confused"

signal effect_started(effect: StringName)
signal effect_ended(effect: StringName)

var _timers: Dictionary[StringName, float] = {}
## Efectos que no le entran (el Gronk Gigante no se deja aturdir por los jugadores).
## `forced` los aplica igual (el boss se aturde solo contra una columna).
var immune: Array[StringName] = []


## Aplica un efecto. Si ya estaba, se queda con la duración más larga.
func apply(effect: StringName, duration: float, forced: bool = false) -> void:
	if duration <= 0.0:
		return
	if not forced and immune.has(effect):
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
