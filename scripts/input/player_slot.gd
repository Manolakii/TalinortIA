class_name PlayerSlot
extends RefCounted
## Un lugar de jugador (P1 a P4): su dispositivo, su color y su personaje.

var index: int = 0
var is_keyboard: bool = false
## Id del joystick. -1 si juega con teclado y mouse.
var joy_device: int = -1
var color: Color = Color.WHITE
var label: String = ""
var character: CharacterData
var is_ready: bool = false
var connected: bool = true
var input: PlayerInput


func _init(slot_index: int, keyboard: bool, joy_id: int) -> void:
	index = slot_index
	is_keyboard = keyboard
	joy_device = joy_id
	input = PlayerInput.new(keyboard, joy_id)


func device_name() -> String:
	return "Teclado y mouse" if is_keyboard else "Joystick %d" % (joy_device + 1)
