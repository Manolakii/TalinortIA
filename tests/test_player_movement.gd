extends GutTest
## Movimiento del personaje: respuesta inmediata, velocidad del GDD y limitador de la cámara.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player_character.tscn")
const DT := 1.0 / 60.0

var _player: PlayerCharacter
var _slot: PlayerSlot


func before_each() -> void:
	# Un slot suelto (fuera de PlayerManager) para controlar el input a mano.
	_slot = PlayerSlot.new(0, false, 99)
	_slot.color = Color.BLUE
	_slot.character = Balance.get_character(&"croco")
	_player = PLAYER_SCENE.instantiate()
	_player.setup(_slot)
	add_child_autofree(_player)


func _step(frames: int) -> void:
	for i: int in frames:
		_player._physics_process(DT)


func test_reaches_full_speed_fast() -> void:
	_slot.input.move = Vector2.RIGHT
	_step(6)  # 0,1 s
	assert_almost_eq(_player.velocity.length(), _slot.character.move_speed, 0.01,
			"A los 0,1 s ya va a velocidad máxima")


func test_stops_fast() -> void:
	_slot.input.move = Vector2.RIGHT
	_step(10)
	_slot.input.move = Vector2.ZERO
	_step(4)
	assert_almost_eq(_player.velocity.length(), 0.0, 0.01, "Frena en menos de 0,07 s")


func test_switches_states() -> void:
	assert_eq(_player.state_machine.current_name(), &"Idle")
	_slot.input.move = Vector2.UP
	_step(1)
	assert_eq(_player.state_machine.current_name(), &"Move")
	_slot.input.move = Vector2.ZERO
	_step(1)
	assert_eq(_player.state_machine.current_name(), &"Idle")


func test_screen_up_moves_north() -> void:
	_slot.input.move = Vector2.UP
	_step(10)
	assert_lt(_player.global_position.z, 0.0, "Arriba en pantalla es -Z (norte)")


func test_velocity_limiter_is_applied() -> void:
	_player.velocity_limiter = func(_pos: Vector3, vel: Vector3, _dt: float) -> Vector3:
		return Vector3(0.0, 0.0, vel.z)
	_slot.input.move = Vector2.RIGHT
	_step(10)
	assert_almost_eq(_player.global_position.x, 0.0, 0.001, "El limitador frena en X")


func test_aims_where_it_walks_without_right_stick() -> void:
	_slot.input.move = Vector2.RIGHT
	_step(2)
	assert_almost_eq(_player.aim_direction, Vector3.RIGHT, Vector3.ONE * 0.001)
