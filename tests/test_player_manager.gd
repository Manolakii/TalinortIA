extends GutTest
## Lógica de la pantalla de unión: lugares, dispositivos y personajes sin repetir.


func before_each() -> void:
	PlayerManager.reset()


func after_all() -> void:
	PlayerManager.reset()


func test_join_assigns_slot_color_and_first_free_character() -> void:
	var p1: PlayerSlot = PlayerManager.join(true)
	assert_not_null(p1)
	assert_eq(p1.index, 0)
	assert_eq(p1.color, Balance.player_slots.colors[0])
	assert_eq(p1.character, Balance.roster.characters[0])


func test_only_one_keyboard_player() -> void:
	PlayerManager.join(true)
	assert_null(PlayerManager.join(true), "Un segundo teclado no se puede unir")


func test_same_joypad_cannot_join_twice() -> void:
	PlayerManager.join(false, 3)
	assert_null(PlayerManager.join(false, 3))


func test_max_four_players() -> void:
	PlayerManager.join(true)
	for device: int in 3:
		assert_not_null(PlayerManager.join(false, device))
	assert_null(PlayerManager.join(false, 9), "El quinto no entra")


func test_characters_never_repeat() -> void:
	var a: PlayerSlot = PlayerManager.join(true)
	var b: PlayerSlot = PlayerManager.join(false, 0)
	assert_ne(a.character, b.character)
	# Ciclar todas las veces que sea: nunca puede caer en el personaje del otro.
	for i: int in 10:
		PlayerManager.cycle_character(a, 1)
		assert_ne(a.character, b.character)
	for i: int in 10:
		PlayerManager.cycle_character(a, -1)
		assert_ne(a.character, b.character)


func test_ready_locks_character() -> void:
	var a: PlayerSlot = PlayerManager.join(true)
	var before: CharacterData = a.character
	PlayerManager.set_ready(a, true)
	PlayerManager.cycle_character(a, 1)
	assert_eq(a.character, before, "Con 'Listo' no se cambia de personaje")


func test_all_ready_needs_everyone() -> void:
	assert_false(PlayerManager.all_ready(), "Sin jugadores no se arranca")
	var a: PlayerSlot = PlayerManager.join(true)
	var b: PlayerSlot = PlayerManager.join(false, 0)
	PlayerManager.set_ready(a, true)
	assert_false(PlayerManager.all_ready())
	PlayerManager.set_ready(b, true)
	assert_true(PlayerManager.all_ready())


func test_leave_keeps_other_slots_in_place() -> void:
	PlayerManager.join(true)
	PlayerManager.join(false, 0)
	var p3: PlayerSlot = PlayerManager.join(false, 1)
	PlayerManager.leave(1)
	assert_eq(p3.index, 2, "P3 sigue siendo P3")
	var newcomer: PlayerSlot = PlayerManager.join(false, 5)
	assert_eq(newcomer.index, 1, "El que entra ocupa el lugar libre")


func test_joypad_disconnect_in_lobby_removes_player() -> void:
	PlayerManager.join(false, 2)
	PlayerManager._on_joy_connection_changed(2, false)
	assert_eq(PlayerManager.player_count(), 0)


func test_joypad_disconnect_in_run_marks_disconnected() -> void:
	var slot: PlayerSlot = PlayerManager.join(false, 2)
	PlayerManager.joining_open = false
	PlayerManager._on_joy_connection_changed(2, false)
	assert_false(slot.connected)
	assert_true(PlayerManager.any_disconnected())
	PlayerManager._on_joy_connection_changed(7, true)
	assert_true(slot.connected, "Un joystick que vuelve con otro id retoma el lugar")
	assert_eq(slot.joy_device, 7)
