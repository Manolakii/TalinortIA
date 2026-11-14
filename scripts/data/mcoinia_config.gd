class_name McoiniaConfig
extends Resource
## McoinIA (GDD, Progresión entre partidas): cómo se gana y qué se compra.

## Cuánto da cada cosa al terminar una partida (GDD, propuesta).
@export var per_scenario: int = 1
@export var per_elite: int = 2
@export var per_boss: int = 8
@export var win_bonus: int = 15
## Multiplicador por dificultad: Fácil, Normal, Difícil.
@export var difficulty_multipliers: Array[float] = [1.0, 1.5, 2.0]
@export var upgrades: Array[McoiniaUpgrade] = []


func get_upgrade(id: StringName) -> McoiniaUpgrade:
	for upgrade: McoiniaUpgrade in upgrades:
		if upgrade.id == id:
			return upgrade
	return null


## Las de una columna: generales (character = "") o las de Héroe de un personaje.
func column(character: StringName) -> Array[McoiniaUpgrade]:
	var result: Array[McoiniaUpgrade] = []
	for upgrade: McoiniaUpgrade in upgrades:
		if upgrade.character == character:
			result.append(upgrade)
	return result
