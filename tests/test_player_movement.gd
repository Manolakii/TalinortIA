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


# --- Esquiva ---

func _press(action: PlayerInput.Action) -> void:
	_slot.input._prev[action] = false
	_slot.input._held[action] = true


func _release(action: PlayerInput.Action) -> void:
	_slot.input._prev[action] = _slot.input._held[action]
	_slot.input._held[action] = false


func test_dodge_gives_short_invulnerability() -> void:
	_press(PlayerInput.Action.DODGE)
	_step(1)
	assert_true(_player.is_dodging())
	assert_true(_player.health.is_invulnerable(), "Invulnerable al inicio")
	_release(PlayerInput.Action.DODGE)
	_step(16)  # ~0,27 s
	assert_false(_player.health.is_invulnerable(), "Solo 0,25 s")


func test_dodge_travels_its_distance() -> void:
	# Se mide velocidad × duración: llamando a _physics_process a mano, move_and_slide
	# usa otro delta y la posición no sirve para medir.
	var character: CharacterData = _slot.character
	_slot.input.move = Vector2.RIGHT
	_press(PlayerInput.Action.DODGE)
	var frames_dodging: int = 0
	for i: int in 40:
		_step(1)
		if i == 0:
			_release(PlayerInput.Action.DODGE)
			_slot.input.move = Vector2.ZERO
		if _player.is_dodging():
			frames_dodging += 1
			assert_almost_eq(_player.velocity.x, character.dodge_distance / character.dodge_duration, 0.01)
	assert_almost_eq(frames_dodging * DT * character.dodge_distance / character.dodge_duration,
			character.dodge_distance, 0.25)


func test_dodge_uses_charges() -> void:
	for i: int in 3:
		_press(PlayerInput.Action.DODGE)
		_step(1)
		_release(PlayerInput.Action.DODGE)
		_step(20)
	assert_eq(_player.kit.dodge_cooldown.charges, 0, "Con 2 cargas, la tercera no sale")


func test_dodge_cancels_action() -> void:
	_player.start_action(1.0)
	_step(1)
	assert_true(_player.is_in_action())
	_press(PlayerInput.Action.DODGE)
	_step(1)
	assert_true(_player.is_dodging(), "La esquiva corta cualquier acción")


func test_dodge_is_buffered() -> void:
	_press(PlayerInput.Action.DODGE)
	_step(1)
	_release(PlayerInput.Action.DODGE)
	_step(12)  # todavía esquivando, pero ya en los últimos 0,15 s
	_press(PlayerInput.Action.DODGE)
	_step(1)
	_release(PlayerInput.Action.DODGE)
	_step(8)  # termina la primera esquiva: sale la segunda guardada
	assert_eq(_player.kit.dodge_cooldown.charges, 0, "La segunda esquiva salió por el buffer")


func test_frozen_player_does_not_move() -> void:
	_slot.input.move = Vector2.RIGHT
	_player.freeze(0.1)
	_step(3)
	assert_eq(_player.global_position.x, 0.0, "Durante el hitstop no se mueve")
