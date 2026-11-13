class_name DuoCompanion
extends Combatant
## El cuerpo del dúo que no maneja el jugador (Maestro o Stewie). Lo mueve la IA
## del MaestroKit. Los enemigos lo pueden atacar; si cae, se levanta a los 15 s.

const OUTLINE_SHADER: Shader = preload("res://assets/shaders/outline.gdshader")
const RING_SHADER: Shader = preload("res://assets/shaders/player_ring.gdshader")

var kit: Node
var identity: int = 0
var facing: Vector3 = Vector3.FORWARD
var visual: Node3D
var move_speed: float = 5.6
## Tiempo que le queda ocupado en un ataque.
var busy: float = 0.0
var attack_timer: float = 0.0
var downed: bool = false
var downed_time: float = 0.0
var invulnerable_shell: bool = false
## Se repliega al lado del jugador (poca vida).
var retreating: bool = false
var priority: float = 1.0

var _dash_velocity: Vector3 = Vector3.ZERO
var _dash_time: float = 0.0

var _move_velocity: Vector3 = Vector3.ZERO
var _body: MeshInstance3D
var _ring: MeshInstance3D
var _collision: CollisionShape3D
var _body_material: StandardMaterial3D
var _extras: Node3D


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 1 << 2  # players
	collision_mask = 1  # world
	add_to_group(&"enemy_targets")
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_body = MeshInstance3D.new()
	visual.add_child(_body)
	_ring = MeshInstance3D.new()
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_collision = CollisionShape3D.new()
	add_child(_collision)


## Arma el cuerpo con el tamaño, color y vida de la identidad (Maestro o Stewie).
func become(new_identity: int, height: float, radius: float, color: Color, speed: float,
		max_health: float, current_health: float) -> void:
	identity = new_identity
	move_speed = speed
	invulnerable_shell = false
	retreating = false
	_dash_time = 0.0
	var capsule := CapsuleMesh.new()
	capsule.height = maxf(height, radius * 2.0)
	capsule.radius = radius
	_body.mesh = capsule
	_body.position.y = capsule.height * 0.5
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = color
	_body_material.roughness = 0.55
	_body_material.rim_enabled = true
	_body_material.rim = 0.35
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	_body_material.next_pass = outline
	_body.material_override = _body_material
	var shape := CapsuleShape3D.new()
	shape.height = capsule.height
	shape.radius = radius
	_collision.shape = shape
	_collision.position.y = capsule.height * 0.5
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 3.0
	_ring.mesh = plane
	_ring.position.y = 0.03
	var ring_material := ShaderMaterial.new()
	ring_material.shader = RING_SHADER
	ring_material.set_shader_parameter("ring_color", Color(color, 0.7))
	ring_material.set_shader_parameter("inner_radius", 0.8)
	_ring.material_override = ring_material
	setup_combatant(DamageInfo.Team.PLAYERS, max_health, radius, capsule.height, visual)
	health.current = clampf(current_health, 1.0, max_health)
	clear_flash_materials()
	register_flash_material(_body_material)
	if _extras != null:
		_extras.queue_free()
	_extras = Node3D.new()
	visual.add_child(_extras)


## Donde el kit agrega detalles (caparazón, bastón).
func extras() -> Node3D:
	return _extras


func _physics_process(delta: float) -> void:
	if downed:
		downed_time -= delta
		if downed_time <= 0.0 and kit != null:
			kit.revive_companion()
		return
	if not combat_tick(delta):
		return
	busy = maxf(busy - delta, 0.0)
	attack_timer -= delta
	if _dash_time > 0.0:
		_dash_time -= delta
		move_with_knockback(_dash_velocity)
		if _dash_time <= 0.0:
			_move_velocity = Vector3.ZERO
		visual.rotation.y = atan2(-facing.x, -facing.z)
		return
	if kit != null and not status.has(StatusEffects.STUN):
		kit.companion_think(self, delta)
	else:
		stop(delta)
	visual.rotation.y = atan2(-facing.x, -facing.z)


func steer(direction: Vector3, speed: float, delta: float) -> void:
	_move_velocity = _move_velocity.move_toward(direction * speed, 60.0 * delta)
	if direction != Vector3.ZERO:
		facing = facing.slerp(direction, clampf(14.0 * delta, 0.0, 1.0)).normalized()
	move_with_knockback(_move_velocity)


func stop(delta: float) -> void:
	_move_velocity = _move_velocity.move_toward(Vector3.ZERO, 80.0 * delta)
	move_with_knockback(_move_velocity)


func can_be_targeted_by_enemies() -> bool:
	return is_targetable() and not downed


func target_priority() -> float:
	return priority


## Esquiva rápida (garrocha o rodar), invulnerable durante el recorrido.
func dash(direction: Vector3, distance: float, duration: float) -> void:
	_dash_velocity = direction.normalized() * distance / maxf(duration, 0.01)
	_dash_time = duration
	health.make_invulnerable(duration)
	facing = direction.normalized()


func is_targetable() -> bool:
	return super.is_targetable() and not downed


func receive_hit(info: DamageInfo) -> bool:
	if invulnerable_shell:
		return false
	return super.receive_hit(info)


func set_downed(value: bool, seconds: float = 0.0) -> void:
	downed = value
	downed_time = seconds
	visual.rotation.x = -1.3 if value else 0.0
	visual.position.y = 0.3 if value else 0.0
