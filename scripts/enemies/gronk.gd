class_name Gronk
extends Enemy
## Gronk (GDD, Stage 1): carga en línea recta con aviso. Si choca contra una pared queda
## aturdido 2 s. Atropella también a otros enemigos.

enum Mode { APPROACH, WINDUP, CHARGE, RECOVER }

var mode: Mode = Mode.APPROACH
var _time: float = 0.0
var _charge_direction: Vector3 = Vector3.FORWARD
var _charge_length: float = 0.0
var _traveled: float = 0.0
var _hit: Array[Node] = []


func _ready() -> void:
	enemy_id = &"gronk"
	super._ready()


func _think(delta: float) -> void:
	if status.has(StatusEffects.STUN):
		stop(delta)
		return
	if status.has(StatusEffects.FEAR):
		steer(-flat_direction_to(fear_origin), data.move_speed * 1.2, delta)
		return
	_time += delta
	match mode:
		Mode.APPROACH:
			var target: Node3D = nearest_target()
			if target == null or status.has(StatusEffects.BLIND):
				stop(delta)
				return
			var direction: Vector3 = flat_direction_to(target.global_position)
			var distance: float = flat_distance_to(target.global_position)
			if distance <= data.attack_range and _time > 0.8:
				turn_towards(direction, delta)
				stop(delta)
				if facing.angle_to(direction) < deg_to_rad(12.0):
					_start_windup()
			else:
				steer(direction, data.move_speed * speed_multiplier(), delta)
		Mode.WINDUP:
			stop(delta)
			if _time >= data.windup:
				telegraph.hide_telegraph()
				_hit.clear()
				_traveled = 0.0
				_set_mode(Mode.CHARGE)
		Mode.CHARGE:
			var previous: Vector3 = global_position
			move_with_knockback(_charge_direction * data.charge_speed * speed_multiplier())
			_traveled += previous.distance_to(global_position)
			_trample(previous, global_position)
			if get_slide_collision_count() > 0 and _hit_wall():
				_crash()
			elif _traveled >= _charge_length or _time > _charge_length / data.charge_speed + 0.4:
				_set_mode(Mode.RECOVER)
		Mode.RECOVER:
			stop(delta)
			if _time >= data.recovery:
				_set_mode(Mode.APPROACH)


func _start_windup() -> void:
	_set_mode(Mode.WINDUP)
	_charge_direction = facing
	_charge_length = _distance_to_wall(data.charge_max_distance)
	telegraph.rotation.y = facing_angle()
	telegraph.show_rect(_charge_length + data.body_radius, data.charge_width, data.windup)


## Hasta dónde puede cargar antes de una pared (para que el aviso sea honesto).
func _distance_to_wall(max_distance: float) -> float:
	var from: Vector3 = global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(from, from + _charge_direction * max_distance, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return max_distance
	return maxf(from.distance_to(hit["position"]) - data.body_radius * 0.5, 1.0)


func _hit_wall() -> bool:
	for i: int in get_slide_collision_count():
		var collider: Object = get_slide_collision(i).get_collider()
		if collider is StaticBody3D:
			return true
	return false


func _crash() -> void:
	status.apply(StatusEffects.STUN, data.wall_stun)
	Events.camera_shake_requested.emit(Balance.combat.shake_heavy * 0.5)
	Events.floating_text_requested.emit(global_position + Vector3.UP * 3.0, "¡PUM!",
			Color(1.0, 1.0, 1.0))
	_set_mode(Mode.RECOVER)


## Atropella a jugadores y también a otros enemigos.
func _trample(from: Vector3, to: Vector3) -> void:
	var reach: Vector3 = to + _charge_direction * data.body_radius
	var victims: Array[Hurtbox] = CombatQuery.in_line(get_tree(), DamageInfo.Team.PLAYERS,
			from, reach, data.charge_width)
	victims.append_array(CombatQuery.in_line(get_tree(), DamageInfo.Team.ENEMIES, from, reach,
			data.charge_width))
	for hurtbox: Hurtbox in victims:
		if hurtbox.receiver == self or _hit.has(hurtbox.receiver):
			continue
		_hit.append(hurtbox.receiver)
		var info: DamageInfo = make_attack()
		# Empuja hacia el costado de la carga.
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(hurtbox.global_position, from, reach)
		info.origin = closest - (hurtbox.global_position - closest).normalized() * 0.1
		info.hitstop = Balance.combat.hitstop_heavy
		if hurtbox.receiver is PlayerCharacter or hurtbox.receiver is DuoCompanion:
			info.shake = Balance.combat.shake_heavy * 0.4
		else:
			# A los enemigos los atropella "de verdad": el golpe cuenta como de los jugadores.
			info.attacker_team = DamageInfo.Team.PLAYERS
			info.attacker = null
		hurtbox.take_hit(info)


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_time = 0.0


func _on_interrupted() -> void:
	if mode == Mode.WINDUP or mode == Mode.CHARGE:
		telegraph.hide_telegraph()
		_set_mode(Mode.RECOVER)


func _build_extras() -> void:
	# El cuerpo base es una cápsula parada; el Gronk se ve como una bestia en cuatro patas.
	var body := visual.get_child(0) as MeshInstance3D
	body.rotation.x = PI * 0.5
	body.position.y = data.body_radius * 1.05
	for side: float in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.18
		cone.height = 0.8
		horn.mesh = cone
		horn.position = Vector3(side * 0.5, data.body_radius * 1.6, -data.body_height * 0.5)
		horn.rotation.x = -0.9
		horn.material_override = Fx.flat_material(Color(0.92, 0.88, 0.8))
		visual.add_child(horn)
