class_name PlayerInput
extends RefCounted
## Lee el input de UN dispositivo (el teclado y mouse, o un joystick puntual).
## El InputMap de Godot mezcla todos los joysticks, así que acá se lee cada uno por su id.
##
## PlayerManager llama a update() una vez por frame de física, antes que el resto de la escena.
## Por eso la lógica que use just_pressed() tiene que correr en _physics_process.

enum Action {
	ATTACK,     ## Golpe común: clic izquierdo / RT. Mantener = continuo.
	ABILITY,    ## Habilidad fuerte: clic derecho / LT.
	DODGE,      ## Esquiva: Espacio / A.
	ULTIMATE,   ## Definitiva: Q / RB.
	RELAY,      ## Relevo Total del Maestro: R / Y + RB.
	INTERACT,   ## Interactuar y revivir: E / X.
	PAUSE,      ## Esc / Start.
	CONFIRM,    ## Menús: Enter / A.
	BACK,       ## Menús: Esc / B.
	LEFT,       ## Menús: A o flecha izquierda / cruceta o stick.
	RIGHT,      ## Menús: D o flecha derecha / cruceta o stick.
	UP,         ## Menús: W o flecha arriba / cruceta o stick.
	DOWN,       ## Menús: S o flecha abajo / cruceta o stick.
}

const MOVE_DEADZONE := 0.2
const AIM_DEADZONE := 0.35
const TRIGGER_THRESHOLD := 0.4
## Cuánto hay que inclinar el stick para que cuente como izquierda o derecha en un menú.
const MENU_STICK_THRESHOLD := 0.6

var is_keyboard: bool = false
var joy_device: int = -1

## Movimiento en pantalla: x a la derecha, y hacia abajo (sur). Largo de 0 a 1.
var move: Vector2 = Vector2.ZERO
## Stick derecho (solo joystick). Vector2.ZERO si no se usa.
var aim_stick: Vector2 = Vector2.ZERO
## Posición del mouse en el viewport (solo teclado y mouse).
var mouse_position: Vector2 = Vector2.ZERO

var _held: Array[bool] = []
var _prev: Array[bool] = []


func _init(keyboard: bool, joy_id: int) -> void:
	is_keyboard = keyboard
	joy_device = joy_id
	_held.resize(Action.size())
	_prev.resize(Action.size())
	_held.fill(false)
	_prev.fill(false)


func update(viewport: Viewport) -> void:
	for i: int in Action.size():
		_prev[i] = _held[i]
	if is_keyboard:
		_read_keyboard(viewport)
	else:
		_read_joypad()


func is_held(action: Action) -> bool:
	return _held[action]


func just_pressed(action: Action) -> bool:
	return _held[action] and not _prev[action]


func just_released(action: Action) -> bool:
	return _prev[action] and not _held[action]


## Olvida lo apretado hasta ahora, para que un botón que sigue apretado
## (por ejemplo, el que confirmó un menú) no dispare algo en la escena siguiente.
func consume_all() -> void:
	for i: int in Action.size():
		_prev[i] = true
		_held[i] = true


func has_aim_stick() -> bool:
	return aim_stick != Vector2.ZERO


func _read_keyboard(viewport: Viewport) -> void:
	var x: float = _key(KEY_D) - _key(KEY_A)
	var y: float = _key(KEY_S) - _key(KEY_W)
	move = Vector2(x, y).limit_length(1.0)
	aim_stick = Vector2.ZERO
	if viewport != null:
		mouse_position = viewport.get_mouse_position()

	_held[Action.ATTACK] = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_held[Action.ABILITY] = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	_held[Action.DODGE] = Input.is_physical_key_pressed(KEY_SPACE)
	_held[Action.ULTIMATE] = Input.is_physical_key_pressed(KEY_Q)
	_held[Action.RELAY] = Input.is_physical_key_pressed(KEY_R)
	_held[Action.INTERACT] = Input.is_physical_key_pressed(KEY_E)
	_held[Action.PAUSE] = Input.is_physical_key_pressed(KEY_ESCAPE)
	_held[Action.CONFIRM] = Input.is_physical_key_pressed(KEY_ENTER) \
			or Input.is_physical_key_pressed(KEY_KP_ENTER)
	_held[Action.BACK] = Input.is_physical_key_pressed(KEY_ESCAPE)
	_held[Action.LEFT] = Input.is_physical_key_pressed(KEY_A) \
			or Input.is_physical_key_pressed(KEY_LEFT)
	_held[Action.RIGHT] = Input.is_physical_key_pressed(KEY_D) \
			or Input.is_physical_key_pressed(KEY_RIGHT)
	_held[Action.UP] = Input.is_physical_key_pressed(KEY_W) \
			or Input.is_physical_key_pressed(KEY_UP)
	_held[Action.DOWN] = Input.is_physical_key_pressed(KEY_S) \
			or Input.is_physical_key_pressed(KEY_DOWN)


func _read_joypad() -> void:
	var raw_move := Vector2(
			Input.get_joy_axis(joy_device, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(joy_device, JOY_AXIS_LEFT_Y))
	move = apply_radial_deadzone(raw_move, MOVE_DEADZONE)
	aim_stick = apply_radial_deadzone(Vector2(
			Input.get_joy_axis(joy_device, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(joy_device, JOY_AXIS_RIGHT_Y)), AIM_DEADZONE)

	var rb: bool = _button(JOY_BUTTON_RIGHT_SHOULDER)
	var y_button: bool = _button(JOY_BUTTON_Y)
	_held[Action.ATTACK] = Input.get_joy_axis(joy_device, JOY_AXIS_TRIGGER_RIGHT) > TRIGGER_THRESHOLD
	_held[Action.ABILITY] = Input.get_joy_axis(joy_device, JOY_AXIS_TRIGGER_LEFT) > TRIGGER_THRESHOLD
	_held[Action.DODGE] = _button(JOY_BUTTON_A)
	_held[Action.ULTIMATE] = rb
	_held[Action.RELAY] = rb and y_button
	_held[Action.INTERACT] = _button(JOY_BUTTON_X)
	_held[Action.PAUSE] = _button(JOY_BUTTON_START)
	_held[Action.CONFIRM] = _button(JOY_BUTTON_A)
	_held[Action.BACK] = _button(JOY_BUTTON_B)
	_held[Action.LEFT] = _button(JOY_BUTTON_DPAD_LEFT) or raw_move.x < -MENU_STICK_THRESHOLD
	_held[Action.RIGHT] = _button(JOY_BUTTON_DPAD_RIGHT) or raw_move.x > MENU_STICK_THRESHOLD
	_held[Action.UP] = _button(JOY_BUTTON_DPAD_UP) or raw_move.y < -MENU_STICK_THRESHOLD
	_held[Action.DOWN] = _button(JOY_BUTTON_DPAD_DOWN) or raw_move.y > MENU_STICK_THRESHOLD


func _key(key: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(key) else 0.0


func _button(button: JoyButton) -> bool:
	return Input.is_joy_button_pressed(joy_device, button)


## Zona muerta radial con reescalado, para que el stick no salte de 0 a 0,2 de golpe.
static func apply_radial_deadzone(value: Vector2, deadzone: float) -> Vector2:
	var length: float = value.length()
	if length < deadzone:
		return Vector2.ZERO
	var scaled: float = minf((length - deadzone) / (1.0 - deadzone), 1.0)
	return value / length * scaled
