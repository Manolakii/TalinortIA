class_name PlayerCharacter
extends Combatant
## Personaje controlado por un jugador. Por ahora es un placeholder: cápsula del color
## del jugador, contorno finito, aro bajo los pies y una "nariz" que marca hacia dónde apunta.
##
## El movimiento, la esquiva y los estados viven acá; qué hace cada botón lo decide
## el kit del personaje (CharacterKit).
##
## Convención de ejes: la cámara mira al norte (-Z). Arriba en pantalla = -Z, derecha = +X.

const OUTLINE_SHADER: Shader = preload("res://assets/shaders/outline.gdshader")
const RING_SHADER: Shader = preload("res://assets/shaders/player_ring.gdshader")
## El aro mide esto veces el radio del personaje.
const RING_SCALE := 3.4
## Botones que se guardan un ratito si no se pueden usar justo (buffer de input).
const BUFFERED_ACTIONS: Array[PlayerInput.Action] = [
	PlayerInput.Action.DODGE, PlayerInput.Action.ABILITY,
	PlayerInput.Action.ULTIMATE, PlayerInput.Action.RELAY,
]
## Modo prueba: tiempo hasta levantarse solo (hasta que exista revivir, Fase 4).
const TEST_MODE_REVIVE_DELAY := 1.5

var slot: PlayerSlot
var data: CharacterData
var kit: CharacterKit
## Dirección horizontal (normalizada) hacia donde apunta.
var aim_direction: Vector3 = Vector3.FORWARD
## Punto del piso al que apunta (con mouse es el cursor; con joystick, unos metros adelante).
var aim_point: Vector3 = Vector3.ZERO
## La pone la sala: recibe (posición, velocidad, delta) y devuelve la velocidad permitida.
## La usa la cámara compartida para frenar a los jugadores en el borde del cuadro.
var velocity_limiter: Callable
## Si no es null, la acción en curso mueve al personaje a esta velocidad (saltos, cargas).
var action_velocity: Variant = null
## Si no es null, reemplaza al stick/WASD (por ejemplo, la Posesión de Agucci camina sola).
var move_override: Variant = null
## Los enemigos no lo ven (Noche del Valle sin Luz de Agucci, mientras no ataque).
var hidden_from_enemies: bool = false

var _move_velocity: Vector3 = Vector3.ZERO
var _buffer: Dictionary[int, float] = {}
var _dodge_direction: Vector3 = Vector3.FORWARD
var _dodge_speed: float = 0.0
var _dodge_time: float = 0.0
var _action_time: float = 0.0
var _action_move_multiplier: float = 1.0
var _body_material: StandardMaterial3D

@onready var visual: Node3D = $Visual
@onready var _body: MeshInstance3D = $Visual/Body
@onready var _nose: MeshInstance3D = $Visual/Nose
@onready var _ring: MeshInstance3D = $Ring
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var state_machine: StateMachine = $StateMachine


## Hay que llamarlo antes de agregarlo al árbol, o justo después.
func setup(player_slot: PlayerSlot) -> void:
	slot = player_slot
	data = player_slot.character
	name = "Player%d_%s" % [slot.index + 1, data.id]
	if is_node_ready():
		_build()


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group(&"players")
	add_to_group(&"enemy_targets")
	if slot != null:
		_build()
	state_machine.start(self)


func _build() -> void:
	_build_placeholder()
	setup_combatant(DamageInfo.Team.PLAYERS, data.max_health, data.placeholder_radius,
			data.placeholder_height, visual)
	register_flash_material(_body_material)
	if not died.is_connected(_on_died):
		died.connect(_on_died)
		Events.hit_landed.connect(_on_any_hit_landed)
	_create_kit()


func _create_kit() -> void:
	if kit != null:
		kit.queue_free()
	var script: Script = data.kit_script if data.kit_script != null else CharacterKit
	kit = script.new() as CharacterKit
	kit.name = "Kit"
	add_child(kit)
	kit.setup(self)


func _physics_process(delta: float) -> void:
	if slot == null:
		return
	_update_buffer(delta)
	if not combat_tick(delta):
		return
	_update_aim(delta)
	kit.tick(delta)
	if health.is_dead or status.has(StatusEffects.STUN):
		apply_movement(Vector2.ZERO, delta)
		return
	kit.handle_input()
	state_machine.physics_update(delta)


# --- Movimiento ---

## Acelera hacia la dirección pedida (x derecha, y abajo en pantalla) y mueve el cuerpo.
func apply_movement(move: Vector2, delta: float, speed_multiplier: float = 1.0) -> void:
	var speed: float = data.move_speed * speed_multiplier
	if kit != null:
		speed *= kit.move_speed_multiplier()
	if status.has(StatusEffects.HASTE):
		speed *= Balance.combat.haste_multiplier
	var target := Vector3(move.x, 0.0, move.y) * speed
	var rate: float = data.acceleration if move != Vector2.ZERO else data.deceleration
	_move_velocity = _move_velocity.move_toward(target, rate * delta)
	_move_with(_move_velocity, delta)


## Movimiento directo (esquivas, cargas, saltos), sin aceleración.
func move_raw(raw_velocity: Vector3, delta: float) -> void:
	_move_velocity = raw_velocity
	_move_with(raw_velocity, delta)


func _move_with(move_velocity: Vector3, delta: float) -> void:
	var total: Vector3 = move_velocity + knockback_velocity
	total.y = 0.0
	if velocity_limiter.is_valid():
		total = velocity_limiter.call(global_position, total, delta)
	velocity = total
	move_and_slide()


## Lo que pide el jugador para moverse (o lo que impone el kit).
func get_move_input() -> Vector2:
	return move_override as Vector2 if move_override != null else slot.input.move


## Para los enemigos: ¿lo pueden elegir como objetivo?
func can_be_targeted_by_enemies() -> bool:
	return is_targetable() and not hidden_from_enemies


## Multiplicador de distancia para elegir objetivo (los señuelos usan menos de 1: atraen más).
func target_priority() -> float:
	return 1.0


# --- Esquiva y acciones (las usan los kits) ---

func start_dodge(direction: Vector3, distance: float, duration: float) -> void:
	_dodge_direction = direction.normalized() if direction != Vector3.ZERO else aim_direction
	_dodge_time = duration
	_dodge_speed = distance / maxf(duration, 0.01)
	health.make_invulnerable(Balance.combat.dodge_invulnerability)
	action_velocity = null
	_action_time = 0.0
	state_machine.transition_to(&"Dodge")


func is_dodging() -> bool:
	return state_machine.current_name() == &"Dodge"


## Una acción (ataque, habilidad) que dura `duration`. Mientras tanto se mueve más lento.
func start_action(duration: float, move_multiplier: float = 0.5) -> void:
	_action_time = maxf(_action_time, duration)
	_action_move_multiplier = move_multiplier
	if state_machine.current_name() != &"Action":
		state_machine.transition_to(&"Action")


func is_in_action() -> bool:
	return state_machine.current_name() == &"Action"


## Puede empezar algo nuevo (no está esquivando ni en medio de una acción).
func can_act() -> bool:
	return not is_dodging() and not is_in_action() and not health.is_dead


## Usado por los estados Dodge y Action.
func dodge_step(delta: float) -> bool:
	move_raw(_dodge_direction * _dodge_speed, delta)
	_dodge_time -= delta
	if _dodge_time <= 0.0:
		_stop_dash_momentum()
		return false
	return true


func action_step(delta: float) -> bool:
	if action_velocity != null:
		move_raw(action_velocity as Vector3, delta)
	else:
		apply_movement(get_move_input(), delta, _action_move_multiplier)
	_action_time -= delta
	if _action_time <= 0.0:
		if action_velocity != null:
			_stop_dash_momentum()
		action_velocity = null
		return false
	return true


## Al terminar un movimiento rápido (esquiva, dash, salto), la velocidad queda como mucho
## en la de caminar. Si no, el personaje seguía patinando varios metros (bug del Paso de Sombra).
func _stop_dash_momentum() -> void:
	_move_velocity = _move_velocity.limit_length(data.move_speed)


func end_action() -> void:
	if action_velocity != null:
		_stop_dash_momentum()
	_action_time = 0.0
	action_velocity = null


# --- Buffer de input ---

func _update_buffer(delta: float) -> void:
	for action: int in _buffer.keys():
		_buffer[action] -= delta
		if _buffer[action] <= 0.0:
			_buffer.erase(action)
	for action: PlayerInput.Action in BUFFERED_ACTIONS:
		if slot.input.just_pressed(action):
			_buffer[action] = Balance.combat.input_buffer_time


## Devuelve true (y lo borra) si el botón se apretó hace menos de input_buffer_time.
func consume_buffered(action: PlayerInput.Action) -> bool:
	if _buffer.has(action):
		_buffer.erase(action)
		return true
	return false


## ¿Hay un toque guardado de este botón? (No lo borra: vence solo a los input_buffer_time.)
func has_buffered(action: PlayerInput.Action) -> bool:
	return _buffer.has(action)


# --- Combate ---

func _try_avoid(info: DamageInfo) -> String:
	return kit.try_avoid(info)


func _on_blocked_by_invulnerability(info: DamageInfo) -> void:
	kit.on_blocked_by_invulnerability(info)


func _after_hit(info: DamageInfo) -> void:
	if info.shake <= 0.0:
		Events.camera_shake_requested.emit(Balance.combat.shake_player_hurt)
	kit.on_damage_taken(info)


func _on_any_hit_landed(info: DamageInfo, target: Node3D) -> void:
	if info.attacker == self and target != self:
		kit.on_damage_dealt(info, target)


func _on_died(info: DamageInfo) -> void:
	if kit.handle_owner_death(info):
		return
	# Modo prueba hasta la Fase 4: se levanta solo.
	Events.floating_text_requested.emit(global_position + Vector3.UP * 2.4,
			"¡Caíste! (modo prueba)", Color(1.0, 0.6, 0.6))
	kit.cancel_scheduled()
	end_action()
	var timer: SceneTreeTimer = get_tree().create_timer(TEST_MODE_REVIVE_DELAY, false)
	timer.timeout.connect(func() -> void:
		health.restore_full()
		health.make_invulnerable(1.0))


# --- Apuntado ---

func _update_aim(delta: float) -> void:
	var desired: Vector3 = _read_aim_direction()
	if desired != Vector3.ZERO:
		aim_direction = desired
	if not slot.input.is_keyboard:
		aim_point = global_position + aim_direction * 6.0
	var target_yaw: float = atan2(-aim_direction.x, -aim_direction.z)
	visual.rotation.y = rotate_toward(visual.rotation.y, target_yaw, data.turn_speed * delta)


## Gira el cuerpo ya mismo hacia donde apunta (al atacar, para que el golpe salga derecho).
func face_aim_now() -> void:
	visual.rotation.y = atan2(-aim_direction.x, -aim_direction.z)


## Mouse: raycast al plano del piso. Joystick: stick derecho con imán al enemigo
## más cercano en esa dirección; sin stick derecho, hacia donde camina.
func _read_aim_direction() -> Vector3:
	var input: PlayerInput = slot.input
	if input.is_keyboard:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera == null:
			return Vector3.ZERO
		var origin: Vector3 = camera.project_ray_origin(input.mouse_position)
		var normal: Vector3 = camera.project_ray_normal(input.mouse_position)
		var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, normal)
		if hit == null:
			return Vector3.ZERO
		aim_point = hit as Vector3
		var flat: Vector3 = aim_point - global_position
		flat.y = 0.0
		return flat.normalized() if flat.length_squared() > 0.01 else Vector3.ZERO
	var direction := Vector3.ZERO
	if input.has_aim_stick():
		direction = Vector3(input.aim_stick.x, 0.0, input.aim_stick.y).normalized()
	elif input.move != Vector2.ZERO:
		direction = Vector3(input.move.x, 0.0, input.move.y).normalized()
	return _apply_aim_magnet(direction) if direction != Vector3.ZERO else direction


func _apply_aim_magnet(direction: Vector3) -> Vector3:
	var config: CombatConfig = Balance.combat
	var best_angle: float = deg_to_rad(config.aim_magnet_angle_deg)
	var best_direction := Vector3.ZERO
	var here := Vector3(global_position.x, 0.0, global_position.z)
	for hurtbox: Hurtbox in CombatQuery.hurtboxes(get_tree(), DamageInfo.Team.ENEMIES):
		var to_enemy: Vector3 = hurtbox.flat_position() - here
		var distance: float = to_enemy.length()
		if distance < 0.01 or distance > config.aim_magnet_range:
			continue
		var angle: float = direction.angle_to(to_enemy)
		if angle < best_angle:
			best_angle = angle
			best_direction = to_enemy / distance
	if best_direction == Vector3.ZERO:
		return direction
	return direction.slerp(best_direction, config.aim_magnet_strength).normalized()


# --- Placeholder ---

## Rearma el cuerpo con otro tamaño (el dúo cambia entre Maestro y Stewie).
func rebuild_body(height: float, radius: float) -> void:
	_build_body(height, radius)
	clear_flash_materials()
	register_flash_material(_body_material)
	hurtbox.radius = radius
	hurtbox.height = height


func _build_placeholder() -> void:
	_build_body(data.placeholder_height, data.placeholder_radius)


func _build_body(height: float, radius: float) -> void:
	var shape := CapsuleShape3D.new()
	shape.height = height
	shape.radius = radius
	_collision.shape = shape
	_collision.position.y = height * 0.5

	var mesh := CapsuleMesh.new()
	mesh.height = height
	mesh.radius = radius
	_body.mesh = mesh
	_body.position.y = height * 0.5
	_body_material = _make_body_material(slot.color)
	_body.material_override = _body_material

	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(radius * 0.45, radius * 0.35, radius * 0.9)
	_nose.mesh = nose_mesh
	_nose.position = Vector3(0.0, height * 0.72, -radius * 0.95)
	_nose.material_override = _make_body_material(slot.color.darkened(0.55))

	var ring_mesh := PlaneMesh.new()
	ring_mesh.size = Vector2.ONE * radius * RING_SCALE
	_ring.mesh = ring_mesh
	_ring.position.y = 0.03
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_material := ShaderMaterial.new()
	ring_material.shader = RING_SHADER
	ring_material.set_shader_parameter("ring_color", slot.color)
	_ring.material_override = ring_material


func _make_body_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	# Rim light suave, como piden las referencias semirrealistas.
	material.rim_enabled = true
	material.rim = 0.35
	material.rim_tint = 0.4
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	material.next_pass = outline
	return material
