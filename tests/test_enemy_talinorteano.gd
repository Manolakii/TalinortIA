extends GutTest
## Talinorteano cegado: avisa, pega 10 y se lo puede esquivar.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player_character.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/talinorteano_cegado.tscn")
const DT := 1.0 / 60.0

var _player: PlayerCharacter
var _slot: PlayerSlot
var _enemy: TalinorteanoCegado


func before_each() -> void:
	_slot = PlayerSlot.new(0, false, 99)
	_slot.character = Balance.get_character(&"croco")
	_player = PLAYER_SCENE.instantiate()
	_player.setup(_slot)
	add_child_autofree(_player)
	_enemy = ENEMY_SCENE.instantiate()
	_enemy.position = Vector3(0, 0, 1.2)  # al sur del jugador, mirando al norte
	add_child_autofree(_enemy)


func _step(frames: int) -> void:
	for i: int in frames:
		_player._physics_process(DT)
		_enemy._physics_process(DT)


func test_uses_data_from_gdd() -> void:
	assert_eq(_enemy.health.max_health, 160.0)
	assert_eq(_enemy.data.damage, 10.0)
	assert_eq(_enemy.data.windup, 0.6)


func test_warns_then_hits() -> void:
	_step(2)
	assert_eq(_enemy.mode, TalinorteanoCegado.Mode.WINDUP)
	assert_true(_enemy.telegraph.visible, "Muestra el aviso naranja")
	_step(30)
	assert_eq(_player.health.current, _player.health.max_health, "Durante el aviso no pega")
	_step(10)
	assert_eq(_player.health.current, _player.health.max_health - 10.0, "Después de 0,6 s, pega 10")


func test_dodge_avoids_the_hit() -> void:
	_step(30)
	_slot.input._prev[PlayerInput.Action.DODGE] = false
	_slot.input._held[PlayerInput.Action.DODGE] = true
	_step(10)
	assert_eq(_player.health.current, _player.health.max_health, "La invulnerabilidad lo salva")


func test_walking_out_of_the_warning_avoids_the_hit() -> void:
	_step(2)
	_player.global_position = Vector3(6, 0, 0)
	_step(40)
	assert_eq(_player.health.current, _player.health.max_health)


func test_stun_cancels_the_attack() -> void:
	_step(10)
	_enemy.status.apply(StatusEffects.STUN, 1.0)
	assert_false(_enemy.telegraph.visible)
	_step(40)
	assert_eq(_player.health.current, _player.health.max_health)


func test_dies_and_leaves_the_enemies_group() -> void:
	var info := DamageInfo.new()
	info.amount = 500.0
	_enemy.receive_hit(info)
	assert_true(_enemy.health.is_dead)
	assert_false(_enemy.is_in_group(&"enemies"))
	assert_false(_enemy.is_targetable())
