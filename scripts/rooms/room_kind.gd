class_name RoomKind
extends RefCounted
## Tipos de sala (GDD, Tipos de sala) y premios de las puertas.
## Las puertas muestran el PREMIO (mejora, oro o desafío) y lo que hay adentro es sorpresa
## (pedido del grupo). Tesoro y Cabaña de Pipo son salas extra escondidas.

enum Type { COMBAT, ELITE, TREASURE, MIMICS, PRISONERS, PIPO_CABIN, ESCORT, MAZE, CHASM }
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
	Type.CHASM: "Evento: el barranco",
}
## Los eventos (no se repite el mismo seguido).
const EVENTS: Array[int] = [Type.MIMICS, Type.PRISONERS, Type.ESCORT, Type.MAZE, Type.CHASM]
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
	return type in [Type.COMBAT, Type.ELITE, Type.PRISONERS]


## Salas extra: no cuentan como sala del escenario.
static func is_bonus(type: int) -> bool:
	return type in [Type.TREASURE, Type.PIPO_CABIN]


## Mejora asegurada (GDD: siempre en las de élite). Igual hay una sola mejora por sala.
static func gives_upgrade(type: int) -> bool:
	return type == Type.ELITE
