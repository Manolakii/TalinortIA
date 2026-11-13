class_name RoomKind
extends RefCounted
## Tipos de sala del recorrido (GDD, Tipos de sala) y sus nombres para puertas y HUD.

enum Type { COMBAT, COMBAT_UPGRADE, ELITE, TREASURE, MIMICS, PRISONERS, PIPO_CABIN }

const NAMES: Dictionary = {
	Type.COMBAT: "Combate",
	Type.COMBAT_UPGRADE: "Combate + mejora",
	Type.ELITE: "Élite",
	Type.TREASURE: "Tesoro",
	Type.MIMICS: "Evento: cofres sospechosos",
	Type.PRISONERS: "Evento: colonia de presos",
	Type.PIPO_CABIN: "Cabaña del General Pipo",
}


static func display_name(type: int) -> String:
	return NAMES.get(type, "Sala")


static func has_combat(type: int) -> bool:
	return type in [Type.COMBAT, Type.COMBAT_UPGRADE, Type.ELITE, Type.PRISONERS]


## Mejora de personaje asegurada al terminar (GDD: algunas de combate y siempre las de élite).
static func gives_upgrade(type: int) -> bool:
	return type in [Type.COMBAT_UPGRADE, Type.ELITE]
