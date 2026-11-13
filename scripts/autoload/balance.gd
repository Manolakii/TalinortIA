extends Node
## Carga los datos de balance desde data/. Ningún número del GDD vive en el código:
## se leen de acá.

const ROSTER_PATH := "res://data/character_roster.tres"
const PLAYER_SLOTS_PATH := "res://data/player_slots.tres"
const CAMERA_PATH := "res://data/camera_config.tres"
const ECONOMY_PATH := "res://data/economy.tres"

var roster: CharacterRoster
var player_slots: PlayerSlotsConfig
var camera: CameraConfig
var economy: EconomyConfig


func _enter_tree() -> void:
	# Se carga en _enter_tree para que los demás autoloads ya lo tengan en su _ready.
	roster = _load_required(ROSTER_PATH) as CharacterRoster
	player_slots = _load_required(PLAYER_SLOTS_PATH) as PlayerSlotsConfig
	camera = _load_required(CAMERA_PATH) as CameraConfig
	economy = _load_required(ECONOMY_PATH) as EconomyConfig


func get_character(id: StringName) -> CharacterData:
	for character: CharacterData in roster.characters:
		if character.id == id:
			return character
	push_error("Balance: no existe el personaje '%s'" % id)
	return null


func _load_required(path: String) -> Resource:
	var res: Resource = load(path)
	if res == null:
		push_error("Balance: no se pudo cargar %s" % path)
	return res
