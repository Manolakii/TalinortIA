class_name Enemy
extends Combatant
## Base de los enemigos: datos, cuerpo placeholder (colores apagados + contorno),
## aviso de ataque, muerte y estados que pueden imponer los jugadores.

const OUTLINE_SHADER: Shader = preload("res://assets/shaders/outline.gdshader")

@export var enemy_id: StringName = &"talinorteano_cegado"

var data: EnemyData
## Multiplicador de vida (dificultad y cantidad de jugadores, Fase 3).
var health_multiplier: float = 1.0
var facing: Vector3 = Vector3.FORWARD
var visual: Node3D
var telegraph: Telegraph
## Mientras está agarrado o volando (Revoleo de Tali), la IA no hace nada.
var is_controlled: bool = false
## Desde dónde viene el miedo (para escaparse hacia el otro lado).
var fear_origin: Vector3 = Vector3.ZERO

var _body_material: StandardMaterial3D
var _move_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	data = Balance.get_enemy(enemy_id)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 1 << 3  # enemies
	collision_mask = 1  # world
	add_to_group(&"enemies")
	_build_body()
	setup_combatant(DamageInfo.Team.ENEMIES, data.max_health * health_multiplier,
			data.body_radius, data.body_height, visual)
	register_flash_material(_body_material)
	telegraph = Telegraph.new()
	telegraph.name = "Telegraph"
	add_child(telegraph)
	died.connect(_on_died)
	status.effect_started.connect(_on_status_started)
	_play_spawn()


func _physics_process(delta: float) -> void:
	if health.is_dead or is_controlled:
		return
	if not combat_tick(delta):
		return
	_think(delta)
	visual.rotation.y = atan2(-facing.x, -facing.z)
	_update_stun_pose(delta)


## IA de cada enemigo.
func _think(_delta: float) -> void:
	pass


# --- Ayudas para la IA ---

## El jugador vivo más cercano, o null.
func nearest_player() -> PlayerCharacter:
	var best: PlayerCharacter = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or not player.is_targetable():
			continue
		var d: float = flat_distance_to(player.global_position)
		if d < best_distance:
			best_distance = d
			best = player
	return best


func flat_distance_to(point: Vector3) -> float:
	return Vector2(global_position.x - point.x, global_position.z - point.z).length()


func flat_direction_to(point: Vector3) -> Vector3:
	var d := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	return d.normalized() if d.length_squared() > 0.0001 else facing


## Se mueve hacia `direction` a `speed`, girando de a poco y separándose de los demás.
func steer(direction: Vector3, speed: float, delta: float) -> void:
	var wanted: Vector3 = (direction + _separation() * 1.2).normalized() * speed \
			if direction != Vector3.ZERO else Vector3.ZERO
	_move_velocity = _move_velocity.move_toward(wanted, 20.0 * delta)
	if wanted != Vector3.ZERO:
		turn_towards(wanted.normalized(), delta)
	move_with_knockback(_move_velocity)


func stop(delta: float) -> void:
	_move_velocity = _move_velocity.move_toward(Vector3.ZERO, 25.0 * delta)
	move_with_knockback(_move_velocity)


func turn_towards(direction: Vector3, delta: float) -> void:
	var current: float = atan2(-facing.x, -facing.z)
	var target: float = atan2(-direction.x, -direction.z)
	var angle: float = rotate_toward(current, target, data.turn_speed * delta)
	facing = Vector3(-sin(angle), 0.0, -cos(angle))


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		if node == self:
			continue
		var other := node as Node3D
		var away := Vector3(global_position.x - other.global_position.x, 0.0,
				global_position.z - other.global_position.z)
		var d: float = away.length()
		if d > 0.001 and d < data.separation_radius:
			push += away / d * (1.0 - d / data.separation_radius)
	return push


func is_targetable() -> bool:
	return super.is_targetable() and not is_controlled


## El tercer zarpazo de Tali "levanta un poco" a los enemigos.
func _after_hit(info: DamageInfo) -> void:
	if info.has_tag(&"launch"):
		var tween: Tween = create_tween()
		tween.tween_property(visual, "position:y", 0.7, 0.14).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual, "position:y", 0.0, 0.22).set_ease(Tween.EASE_IN)


# --- Agarrado y lanzado (Revoleo) ---

func set_controlled(value: bool) -> void:
	is_controlled = value
	telegraph.hide_telegraph()
	_on_interrupted()


# --- Estados ---

func _on_status_started(effect: StringName) -> void:
	if effect == StatusEffects.STUN or effect == StatusEffects.FEAR:
		telegraph.hide_telegraph()
		_on_interrupted()


## Se cortó lo que estaba haciendo (aturdido, asustado, agarrado).
func _on_interrupted() -> void:
	pass


func _update_stun_pose(delta: float) -> void:
	var stunned: bool = status.has(StatusEffects.STUN)
	var target_tilt: float = 0.35 if stunned else 0.0
	visual.rotation.x = lerpf(visual.rotation.x, target_tilt, 1.0 - exp(-12.0 * delta))


# --- Nacer y morir ---

func _play_spawn() -> void:
	visual.scale = Vector3.ONE * 0.2
	var tween: Tween = create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func _on_died(_info: DamageInfo) -> void:
	telegraph.hide_telegraph()
	collision_layer = 0
	remove_from_group(&"enemies")
	Events.enemy_died.emit(self)
	var tween: Tween = create_tween()
	tween.tween_property(visual, "rotation:x", -1.45, 0.35).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_IN)
	tween.tween_interval(0.35)
	tween.tween_property(visual, "position:y", -1.2, 0.5)
	tween.tween_callback(queue_free)


func _build_body() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)

	var shape := CapsuleShape3D.new()
	shape.height = data.body_height
	shape.radius = data.body_radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = data.body_height * 0.5
	add_child(collision)

	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.height = data.body_height
	mesh.radius = data.body_radius
	body.mesh = mesh
	body.position.y = data.body_height * 0.5
	_body_material = _make_material(data.body_color)
	body.material_override = _body_material
	visual.add_child(body)
	_build_extras()


## Cada enemigo agrega acá sus detalles (armas, vendas...).
func _build_extras() -> void:
	pass


func _make_material(color: Color, with_outline: bool = true) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	if with_outline:
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		material.next_pass = outline
	return material
