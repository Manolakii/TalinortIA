class_name RoomKind
extends RefCounted
## Tipos de sala (GDD, Tipos de sala) y premios de las puertas.
## Pedido del grupo: se avanza de sala en sala por salas de COMBATE (normal, élite o aguante).
## Las puertas muestran el PREMIO (mejora u oro) y el tipo de combate es sorpresa. Los eventos son
## DESAFÍOS: una puerta que aparece cada tanto, se entra, se juega y se vuelve a la misma sala
## (como una grieta). Tesoro y Cabaña de Pipo son salas extra escondidas.

enum Type { COMBAT, ELITE, TREASURE, MIMICS, PRISONERS, PIPO_CABIN, ESCORT, MAZE, STAMPEDE, BOSS, SURVIVAL }
enum Reward { NONE, UPGRADE, GOLD, CHALLENGE }

const NAMES: Dictionary = {
	Type.COMBAT: "Combate",
	Type.ELITE: "Élite",
	Type.TREASURE: "Tesoro escondido",
	Type.MIMICS: "Evento: cofres sospechosos",
	Type.PRISONERS: "Evento: colonia de presos",
	Type.PIPO_CABIN: "Cabaña del General Pipo",
	Type.ESCORT: "Evento: escoltá la carreta",
	Type.MAZE: "Evento: laberinto de los Gronks",
	Type.STAMPEDE: "Evento: la estampida",
	Type.BOSS: "Boss: Gronk Gigante",
	Type.SURVIVAL: "Aguante",
}
## Los eventos: ahora son los desafíos de ida y vuelta (no se repite el mismo seguido).
const EVENTS: Array[int] = [Type.MIMICS, Type.PRISONERS, Type.ESCORT, Type.MAZE, Type.STAMPEDE]
const REWARD_NAMES: Dictionary = {
	Reward.NONE: "",
	Reward.UPGRADE: "Mejora",
	Reward.GOLD: "Oro",
	Reward.CHALLENGE: "Desafío",
}


static func display_name(type: int) -> String:
	return NAMES.get(type, "Sala")


static func reward_name(reward: int) -> String:
	return REWARD_NAMES.get(reward, "")


static func has_combat(type: int) -> bool:
	return type in [Type.COMBAT, Type.ELITE, Type.PRISONERS, Type.SURVIVAL]


## Salas extra: no cuentan como sala del escenario.
static func is_bonus(type: int) -> bool:
	return type in [Type.TREASURE, Type.PIPO_CABIN]


## Mejora asegurada (GDD: siempre en las de élite). Igual hay una sola mejora por sala.
static func gives_upgrade(type: int) -> bool:
	return type == Type.ELITE
