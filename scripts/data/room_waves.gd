class_name RoomWaves
extends Resource
## Oleadas de una sala de combate (GDD, Tipos de sala: 2 o 3 oleadas).
## Cada oleada es un texto fácil de editar: "id:cantidad" o "id:cantidad:élites", separados
## por coma. Ejemplo: "talinorteano_cegado:5, soldado_agucci:2:1" = 5 cegados y 2 soldados,
## de los cuales 1 es élite. Las cantidades son de 1 jugador en Normal; se escalan solas.

@export var room_name: String = "Sala de combate"
@export var waves: Array[String] = []
## Pausa antes de cada oleada.
@export var wave_delay: float = 1.5
## Zona donde aparecen los enemigos (centrada en la sala) y distancia mínima a los jugadores.
@export var spawn_area: Vector2 = Vector2(42.0, 26.0)
@export var min_spawn_distance: float = 9.0


class Entry:
	var enemy_id: StringName
	var count: int
	var elites: int


## Convierte una oleada de texto en entradas.
static func parse_wave(text: String) -> Array[Entry]:
	var result: Array[Entry] = []
	for part: String in text.split(",", false):
		var fields: PackedStringArray = part.strip_edges().split(":")
		if fields.size() < 2:
			continue
		var entry := Entry.new()
		entry.enemy_id = StringName(fields[0].strip_edges())
		entry.count = int(fields[1])
		entry.elites = clampi(int(fields[2]) if fields.size() > 2 else 0, 0, entry.count)
		result.append(entry)
	return result
