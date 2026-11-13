class_name Enemy
extends Combatant
## Base de los enemigos: datos, cuerpo placeholder (colores apagados + contorno),
## aviso de ataque, muerte y estados que pueden imponer los jugadores.

const OUTLINE_SHADER: Shader = preload("res://assets/shaders/outline.gdshader")

@export var enemy_id: StringName = &"talinorteano_cegado"

const ENEMY_BULLET_COLOR := Color(0.85, 0.55, 1.0)
## Los de distancia retroceden a esta parte de su velocidad.
const RETREAT_SPEED := 0.6
## Afijos de élite (GDD, Élites).
const AFFIXES: Array[StringName] = [&"armored", &"fast", &"shadowy", &"explosive"]
const AFFIX_NAMES: Dictionary = {
	&"armored": "Blindado", &"fast": "Veloz", &"shadowy": "Sombrío", &"explosive": "Explosivo",
}
## Dorado = oro y recompensa (GDD, colores reservados): siempre con brillo y forma de rombo.
const BOUNTY_COLOR := Color(1.0, 0.78, 0.2)

var data: EnemyData
## Multiplicadores de vida y daño. Negativo = se calculan solos según la dificultad
## y la cantidad de jugadores (Scaling).
var health_multiplier: float = -1.0
var damage_multiplier: float = -1.0
var is_elite: bool = false
var affixes: Array[StringName] = []
## Lleva la Recompensa del Croco (rombo dorado).
var has_bounty: bool = false
## Despertó (Chamán muerto) y se va sin pelear.
var awake: bool = false
var facing: Vector3 = Vector3.FORWARD
var visual: Node3D
var telegraph: Telegraph
## Mientras está agarrado o volando (Revoleo de Tali), la IA no hace nada.
var is_controlled: bool = false
## Desde dónde viene el miedo (para escaparse hacia el otro lado).
var fear_origin: Vector3 = Vector3.ZERO

var _body_material: StandardMaterial3D
var _move_velocity: Vector3 = Vector3.ZERO
var _puddle_timer: float = 0.0
var _bounty_marker: MeshInstance3D


func _ready() -> void:
	data = Balance.get_enemy(enemy_id)
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 1 << 3  # enemies
	collision_mask = 1 | 512  # paredes y rocas
	add_to_group(&"enemies")
	if health_multiplier < 0.0:
		health_multiplier = Scaling.current_health_multiplier()
	if damage_multiplier < 0.0:
		damage_multiplier = Scaling.current_damage_multiplier()
	if is_elite:
		health_multiplier *= Balance.elite.health_multiplier
	_build_body()
	setup_combatant(DamageInfo.Team.ENEMIES, data.max_health * health_multiplier,
			data.body_radius, data.body_height, visual)
	register_flash_material(_body_material)
	telegraph = Telegraph.new()
	telegraph.name = "Telegraph"
	add_child(telegraph)
	died.connect(_on_died)
	status.effect_started.connect(_on_status_started)
	if is_elite:
		_build_elite_marks()
	_play_spawn()


func _physics_process(delta: float) -> void:
	if health.is_dead or is_controlled:
		return
	if not combat_tick(delta):
		return
	if awake:
		_flee_awake(delta)
	else:
		_think(delta)
	if affixes.has(&"shadowy"):
		_drop_puddles(delta)
	if _bounty_marker != null:
		_bounty_marker.rotate_y(delta * 2.5)
	visual.rotation.y = atan2(-facing.x, -facing.z)
	_update_stun_pose(delta)


## IA de cada enemigo.
func _think(_delta: float) -> void:
	pass


# --- Élites ---

## Convierte a este enemigo en élite. Hay que llamarlo antes de agregarlo al árbol.
func make_elite(affix_count: int, rng: RandomNumberGenerator = null) -> void:
	is_elite = true
	var pool: Array[StringName] = AFFIXES.duplicate()
	affixes.clear()
	for i: int in mini(affix_count, pool.size()):
		var index: int = rng.randi_range(0, pool.size() - 1) if rng != null \
				else randi_range(0, pool.size() - 1)
		affixes.append(pool[index])
		pool.remove_at(index)


## Marca a este élite con la Recompensa del Croco.
func set_bounty() -> void:
	has_bounty = true
	if is_node_ready():
		_build_bounty_marker()


func _build_elite_marks() -> void:
	var names: Array[String] = []
	for affix: StringName in affixes:
		names.append(AFFIX_NAMES[affix])
	var label := Label3D.new()
	label.text = " · ".join(names)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0009
	label.font_size = 30
	label.outline_size = 10
	label.outline_modulate = Color(0.05, 0.05, 0.08, 0.9)
	label.position.y = data.body_height * Balance.elite.scale + 0.5
	add_child(label)
	# Brillo de borde: se distingue de los comunes.
	_body_material.rim_enabled = true
	_body_material.rim = 0.8
	_body_material.rim_tint = 0.2
	if has_bounty:
		_build_bounty_marker()


func _build_bounty_marker() -> void:
	if _bounty_marker != null:
		return
	_bounty_marker = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 0.6
	_bounty_marker.mesh = box
	_bounty_marker.rotation = Vector3(PI * 0.25, 0.0, PI * 0.25)
	_bounty_marker.position.y = data.body_height * body_scale() + 1.5
	_bounty_marker.material_override = Fx.flat_material(BOUNTY_COLOR, 2.5)
	_bounty_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bounty_marker)


func _drop_puddles(delta: float) -> void:
	_puddle_timer -= delta
	if _puddle_timer > 0.0 or _move_velocity.length() < 0.5:
		return
	_puddle_timer = Balance.elite.puddle_interval
	var puddle := ShadowZone.new()
	puddle.radius = Balance.elite.puddle_radius
	puddle.slow_time = 0.3
	puddle.lifetime = Balance.elite.puddle_duration
	get_parent().add_child(puddle)
	puddle.global_position = Vector3(global_position.x, 0.0, global_position.z)


## Paga la Recompensa si lo mató el Croco.
func _pay_bounty(info: DamageInfo) -> void:
	if not has_bounty or not is_instance_valid(info.attacker):
		return
	var killer := info.attacker as PlayerCharacter
	if killer == null or not (killer.kit is CrocoKit):
		return
	var gold: int = Balance.economy.croco_bounty_gold
	RunState.add_gold(killer.slot.index, gold)
	if killer.kit.has_upgrade(&"croco_recompensa_cura"):
		killer.health.heal(10.0)
	Events.floating_text_requested.emit(global_position + Vector3.UP * 3.0,
			"+%d oro" % gold, BOUNTY_COLOR)


# --- Ayudas para la IA ---

## Tiempos de ataque según la dificultad (en Difícil avisan y atacan más rápido).
func windup_time() -> float:
	return data.windup * Scaling.current_windup()


func recovery_time() -> float:
	return data.recovery * Scaling.current_attack_pace()


func attack_interval_time() -> float:
	return data.attack_interval * Scaling.current_attack_pace()


## Velocidad con modificadores: dificultad, élite Veloz, aura del Chamán.
func speed_multiplier() -> float:
	var multiplier: float = Scaling.current_enemy_speed()
	if affixes.has(&"fast"):
		multiplier *= Balance.elite.fast_speed_multiplier
	if status.has(StatusEffects.SHADOW_HASTE):
		multiplier *= 1.0 + Balance.get_enemy(&"chaman_sombra").aura_speed_bonus
	return multiplier


## Un golpe de este enemigo, con el daño escalado por la dificultad.
func make_attack(amount_multiplier: float = 1.0) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = data.damage * damage_multiplier * amount_multiplier
	info.attacker = self
	info.attacker_team = DamageInfo.Team.ENEMIES
	info.origin = global_position
	info.knockback = data.attack_knockback
	info.hitstop = Balance.combat.hitstop_light
	return info


## Mantiene una distancia con el objetivo; `strafe` (-1 a 1) lo hace moverse de costado.
func keep_distance(target: Node3D, preferred: float, delta: float, strafe: float = 0.0) -> void:
	var to_target: Vector3 = flat_direction_to(target.global_position)
	var distance: float = flat_distance_to(target.global_position)
	var side := Vector3(-to_target.z, 0.0, to_target.x) * strafe
	var radial := Vector3.ZERO
	if distance > preferred + 1.5:
		radial = to_target
	elif distance < preferred - 1.5:
		radial = -to_target
	var wanted: Vector3 = radial + side
	if wanted.length_squared() < 0.01:
		stop(delta)
		turn_towards(to_target, delta)
		return
	# Retroceden más lento de lo que avanzan: si los perseguís, los alcanzás.
	var speed: float = data.move_speed * speed_multiplier()
	if distance < preferred - 1.5:
		speed *= RETREAT_SPEED
	steer(wanted.normalized(), speed, delta)
	turn_towards(to_target, delta)


## Pool compartido de proyectiles enemigos.
func enemy_projectiles() -> ProjectilePool:
	var pool := get_tree().get_first_node_in_group(&"enemy_projectiles") as ProjectilePool
	if pool == null:
		pool = ProjectilePool.new()
		pool.name = "EnemyProjectiles"
		pool.add_to_group(&"enemy_projectiles")
		get_tree().root.add_child(pool)
		var mesh := SphereMesh.new()
		mesh.radius = 0.16
		mesh.height = 0.32
		pool.setup(mesh, Fx.flat_material(ENEMY_BULLET_COLOR, 2.0), 32)
	return pool


func facing_angle() -> float:
	return atan2(-facing.x, -facing.z)

## El objetivo más cercano del lado de los jugadores (jugadores, compañeros, señuelos), o null.
## Los nodos del grupo "enemy_targets" implementan can_be_targeted_by_enemies() y target_priority().
func nearest_target() -> Node3D:
	var best: Node3D = null
	var best_score: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"enemy_targets"):
		var target := node as Node3D
		if target == null or not target.can_be_targeted_by_enemies():
			continue
		var score: float = flat_distance_to(target.global_position) * target.target_priority()
		if score < best_score:
			best_score = score
			best = target
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
	return super.is_targetable() and not is_controlled and not awake


## Blindado: recibe menos de frente.
func _modify_incoming(info: DamageInfo) -> void:
	if not affixes.has(&"armored") or info.attacker_team != DamageInfo.Team.PLAYERS:
		return
	var from := Vector3(info.origin.x - global_position.x, 0.0, info.origin.z - global_position.z)
	if from.length_squared() < 0.01:
		return
	if facing.angle_to(from) <= deg_to_rad(Balance.elite.armored_front_angle_deg) * 0.5:
		info.amount *= Balance.elite.armored_front_damage


## El Chamán murió: despierta, deja de pelear y se va (en la Fase 5 da oro).
func wake_and_flee() -> void:
	awake = true
	telegraph.hide_telegraph()
	remove_from_group(&"enemies")
	Events.floating_text_requested.emit(global_position + Vector3.UP * 2.4, "¡Desperté!",
			Color(0.85, 0.95, 1.0))
	Events.enemy_died.emit(self)
	get_tree().create_timer(2.5, false).timeout.connect(queue_free)


func _flee_awake(delta: float) -> void:
	var target: Node3D = nearest_target()
	var away: Vector3 = -flat_direction_to(target.global_position) if target != null else facing
	steer(away, data.move_speed * 1.3, delta)
	var fade: float = clampf(visual.scale.x - delta * 0.35, 0.05, 1.0)
	visual.scale = Vector3.ONE * fade


## El tercer zarpazo de Tali "levanta un poco" a los enemigos.
func _after_hit(info: DamageInfo) -> void:
	if info.has_tag(&"launch"):
		var tween: Tween = create_tween()
		tween.tween_property(visual, "position:y", 0.7, 0.14).set_ease(Tween.EASE_OUT)
		tween.tween_property(visual, "position:y", 0.0, 0.22).set_ease(Tween.EASE_IN)


## ¿Está por pegarle a este punto? (lo usa la IA del compañero para esquivar avisos)
func threatens(point: Vector3) -> bool:
	return telegraph != null and telegraph.contains(point)


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
	var wobble: float = sin(Time.get_ticks_msec() * 0.012) * 0.25 if stunned else 0.0
	var target_tilt: float = 0.5 if stunned else 0.0
	visual.rotation.x = lerpf(visual.rotation.x, target_tilt, 1.0 - exp(-12.0 * delta))
	visual.rotation.z = lerpf(visual.rotation.z, wobble, 1.0 - exp(-12.0 * delta))


# --- Nacer y morir ---

func body_scale() -> float:
	return Balance.elite.scale if is_elite else 1.0


func _play_spawn() -> void:
	visual.scale = Vector3.ONE * 0.2
	var tween: Tween = create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * body_scale(), 0.3).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func _on_died(info: DamageInfo) -> void:
	_pay_bounty(info)
	if affixes.has(&"explosive"):
		var blast := EliteExplosion.new()
		get_parent().add_child(blast)
		blast.global_position = Vector3(global_position.x, 0.0, global_position.z)
		blast.setup(Balance.elite.explosion_radius, Balance.elite.explosion_delay,
				Balance.elite.explosion_damage * damage_multiplier)
	if _bounty_marker != null:
		_bounty_marker.queue_free()
		_bounty_marker = null
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
