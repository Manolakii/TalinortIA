extends GutTest
## Base para testear kits: crea un jugador con el personaje pedido, sin críticos,
## y da ayudas para apretar botones y avanzar frames.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player_character.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/talinorteano_cegado.tscn")
const DT := 1.0 / 60.0

var _player: PlayerCharacter
var _slot: PlayerSlot


func make_player(character_id: StringName, index: int = 0) -> PlayerCharacter:
	var slot := PlayerSlot.new(index, false, 90 + index)
	slot.color = Balance.player_slots.colors[index]
	slot.label = Balance.player_slots.labels[index]
	slot.character = Balance.get_character(character_id).duplicate()
	slot.character.crit_chance = 0.0
	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	player.setup(slot)
	add_child_autofree(player)
	if index == 0:
		_player = player
		_slot = slot
	return player


func enemy_at(pos: Vector3, max_health: float = 160.0) -> TalinorteanoCegado:
	var enemy: TalinorteanoCegado = ENEMY_SCENE.instantiate()
	enemy.position = pos
	add_child_autofree(enemy)
	enemy.health.setup(max_health)
	# Mirando al jugador (en el origen), para que los golpes no sean "por la espalda".
	var to_origin := Vector3(-pos.x, 0.0, -pos.z)
	if to_origin.length_squared() > 0.001:
		enemy.facing = to_origin.normalized()
	return enemy


## Avanza frames del jugador (y de lo que se pase en `extra`, que tenga _physics_process).
func step(frames: int, extra: Array = []) -> void:
	for i: int in frames:
		_player._physics_process(DT)
		for node: Variant in extra:
			if is_instance_valid(node):
				node._physics_process(DT)


func press(action: PlayerInput.Action) -> void:
	_slot.input._prev[action] = false
	_slot.input._held[action] = true


func hold(action: PlayerInput.Action) -> void:
	_slot.input._prev[action] = true
	_slot.input._held[action] = true


func release(action: PlayerInput.Action) -> void:
	_slot.input._prev[action] = true
	_slot.input._held[action] = false
