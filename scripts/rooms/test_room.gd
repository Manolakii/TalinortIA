extends Node3D
## Sala de prueba de Talinorthland: crea a los jugadores en sus puntos de aparición
## y aplica el preset de calidad al entorno.
##
## Si se abre directo desde el editor (F6) sin pasar por la pantalla de unión,
## se une sola: teclado y mouse más todos los joysticks conectados.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player_character.tscn")

@onready var _environment: WorldEnvironment = $WorldEnvironment
@onready var _spawn_points: Node3D = $SpawnPoints
@onready var _players_root: Node3D = $Players

var players: Array[PlayerCharacter] = []


func _ready() -> void:
	GameSettings.apply_to_environment(_environment.environment)
	Events.quality_changed.connect(_on_quality_changed)
	if PlayerManager.player_count() == 0:
		_auto_join_for_testing()
	_spawn_players()


func _spawn_players() -> void:
	for slot: PlayerSlot in PlayerManager.active_slots():
		var player: PlayerCharacter = PLAYER_SCENE.instantiate()
		player.setup(slot)
		var spawn: Node3D = _spawn_points.get_child(slot.index) as Node3D
		player.position = spawn.position if spawn != null else Vector3.ZERO
		_players_root.add_child(player)
		players.append(player)


func _auto_join_for_testing() -> void:
	PlayerManager.reset()
	PlayerManager.join(true)
	for device: int in Input.get_connected_joypads():
		PlayerManager.join(false, device)
	PlayerManager.joining_open = false
	RunState.start_run()


func _on_quality_changed(_preset: QualityPreset) -> void:
	GameSettings.apply_to_environment(_environment.environment)
