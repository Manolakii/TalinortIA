class_name StatModifiers
extends RefCounted
## Suma de lo que dan los objetos y mejoras de un jugador. Los porcentajes se suman
## (no se multiplican) y algunos tienen tope (GDD): cooldowns hasta -40%, daño recibido
## hasta -30% y robo de vida hasta 10%.

const COOLDOWN_CAP := 0.4
const DAMAGE_REDUCTION_CAP := 0.3
const LIFESTEAL_CAP := 0.1

var totals: Dictionary[StringName, float] = {}


func add(stat: StringName, amount: float) -> void:
	totals[stat] = totals.get(stat, 0.0) + amount


func get_total(stat: StringName) -> float:
	return totals.get(stat, 0.0)


func clear() -> void:
	totals.clear()


func damage_multiplier() -> float:
	return 1.0 + get_total(&"damage")


func attack_speed_multiplier() -> float:
	return 1.0 + get_total(&"attack_speed")


func move_speed_multiplier() -> float:
	return 1.0 + get_total(&"move_speed")


func max_health_bonus() -> float:
	return get_total(&"max_health")


func crit_chance_bonus() -> float:
	return get_total(&"crit_chance")


func crit_damage_bonus() -> float:
	return get_total(&"crit_damage")


## Reducción de cooldowns de habilidades, con tope.
func cooldown_reduction() -> float:
	return clampf(get_total(&"cooldown_reduction"), 0.0, COOLDOWN_CAP)


func ult_charge_multiplier() -> float:
	return 1.0 + get_total(&"ult_charge")


func heal_per_wave() -> float:
	return get_total(&"heal_per_wave")


## Daño recibido: 0,96 con una Escama. Con tope.
func damage_taken_multiplier() -> float:
	return 1.0 - clampf(get_total(&"damage_reduction"), 0.0, DAMAGE_REDUCTION_CAP)


func gold_multiplier() -> float:
	return 1.0 + get_total(&"gold")


func lifesteal() -> float:
	return clampf(get_total(&"lifesteal"), 0.0, LIFESTEAL_CAP)
