class_name GenericItem
extends Resource
## Objeto genérico (GDD, "Objeto al terminar un escenario: elegir 1 de 3"): se apila y sube
## estadísticas. Cada copia suma `amount` a la estadística `stat`.

## Estadísticas posibles (las mismas que suma StatModifiers).
const STATS: Array[StringName] = [&"damage", &"attack_speed", &"max_health", &"crit_chance",
		&"crit_damage", &"move_speed", &"cooldown_reduction", &"ult_charge", &"heal_per_wave",
		&"damage_reduction", &"gold", &"lifesteal"]

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""
@export var stat: StringName = &"damage"
## Por copia. Porcentajes como fracción (0,08 = 8%); vida y curación en puntos.
@export var amount: float = 0.08
