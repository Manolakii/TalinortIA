class_name PlayerCharacter
extends CharacterBody3D
## Personaje controlado por un jugador. Por ahora es un placeholder: cápsula del color
## del jugador, contorno finito, aro bajo los pies y una "nariz" que marca hacia dónde apunta.
##
## Convención de ejes: la cámara mira al norte (-Z). Arriba en pantalla = -Z, derecha = +X.

const OUTLINE_SHADER: Shader = preload("res://assets/shaders/outline.gdshader")
const RING_SHADER: Shader = preload("res://assets/shaders/player_ring.gdshader")
## El aro mide esto veces el radio del personaje.
const RING_SCALE := 3.4

var slot: PlayerSlot
var data: CharacterData
## Dirección horizontal (normalizada) hacia donde apunta.
var aim_direction: Vector3 = Vector3.FORWARD
## La pone la sala: recibe (posición, velocidad, delta) y devuelve la velocidad permitida.
## La usa la cámara compartida para frenar a los jugadores en el borde del cuadro.
var velocity_limiter: Callable

@onready var _visual: Node3D = $Visual
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
		_build_placeholder()


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	if slot != null:
		_build_placeholder()
	state_machine.start(self)


func _physics_process(delta: float) -> void:
	if slot == null:
		return
	state_machine.physics_update(delta)
	_update_aim(delta)


## Acelera hacia la dirección pedida (x derecha, y abajo en pantalla) y mueve el cuerpo.
func apply_movement(move: Vector2, delta: float) -> void:
	var target := Vector3(move.x, 0.0, move.y) * data.move_speed
	var rate: float = data.acceleration if move != Vector2.ZERO else data.deceleration
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, rate * delta)
	velocity = horizontal
	if velocity_limiter.is_valid():
		velocity = velocity_limiter.call(global_position, velocity, delta)
	move_and_slide()


func _update_aim(delta: float) -> void:
	var desired: Vector3 = _read_aim_direction()
	if desired != Vector3.ZERO:
		aim_direction = desired
	var target_yaw: float = atan2(-aim_direction.x, -aim_direction.z)
	_visual.rotation.y = rotate_toward(_visual.rotation.y, target_yaw, data.turn_speed * delta)


## Mouse: raycast al plano del piso. Joystick: stick derecho; si no, hacia donde camina.
## (El imán al enemigo más cercano llega con los enemigos, en la Fase 1.)
func _read_aim_direction() -> Vector3:
	var input: PlayerInput = slot.input
	if input.is_keyboard:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera == null:
			return Vector3.ZERO
		var origin: Vector3 = camera.project_ray_origin(input.mouse_position)
		var normal: Vector3 = camera.project_ray_normal(input.mouse_position)
		var floor_plane := Plane(Vector3.UP, 0.0)
		var hit: Variant = floor_plane.intersects_ray(origin, normal)
		if hit == null:
			return Vector3.ZERO
		var flat: Vector3 = (hit as Vector3) - global_position
		flat.y = 0.0
		return flat.normalized() if flat.length_squared() > 0.01 else Vector3.ZERO
	if input.has_aim_stick():
		return Vector3(input.aim_stick.x, 0.0, input.aim_stick.y).normalized()
	if input.move != Vector2.ZERO:
		return Vector3(input.move.x, 0.0, input.move.y).normalized()
	return Vector3.ZERO


func _build_placeholder() -> void:
	var height: float = data.placeholder_height
	var radius: float = data.placeholder_radius

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
	_body.material_override = _make_body_material(slot.color)

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
