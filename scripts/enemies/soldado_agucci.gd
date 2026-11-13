class_name SoldadoAgucci
extends Enemy
## Soldado Agucci (GDD, Stage 1): se acerca de a poco y hace un corte con dash corto,
## marcado en el piso.

enum Mode { APPROACH, WINDUP, DASH, RECOVER }

const DASH_TIME := 0.18

var mode: Mode = Mode.APPROACH
var _time: float = 0.0
var _dash_direction: Vector3 = Vector3.FORWARD
var _dash_from: Vector3
var _hit: Array[Node] = []


func _ready() -> void:
	enemy_id = &"soldado_agucci"
	super._ready()


func _think(delta: float) -> void:
	if status.has(StatusEffects.STUN):
		stop(delta)
		return
	if status.has(StatusEffects.FEAR):
		steer(-flat_direction_to(fear_origin), data.move_speed * 1.3, delta)
		return
	_time += delta
	match mode:
		Mode.APPROACH:
			var target: Node3D = nearest_target()
			if target == null or status.has(StatusEffects.BLIND):
				stop(delta)
				return
			var direction: Vector3 = flat_direction_to(target.global_position)
			if flat_distance_to(target.global_position) <= data.attack_range:
				turn_towards(direction, delta)
				stop(delta)
				if facing.angle_to(direction) < deg_to_rad(20.0):
					_start_windup()
			else:
				steer(direction, data.move_speed * speed_multiplier(), delta)
		Mode.WINDUP:
			stop(delta)
			if _time >= data.windup:
				_start_dash()
		Mode.DASH:
			var previous: Vector3 = global_position
			move_with_knockback(_dash_direction * data.dash_distance / DASH_TIME)
			_hit_along(previous, global_position)
			if _time >= DASH_TIME or get_slide_collision_count() > 0:
				_set_mode(Mode.RECOVER)
		Mode.RECOVER:
			stop(delta)
			if _time >= data.recovery:
				_set_mode(Mode.APPROACH)


func _start_windup() -> void:
	_set_mode(Mode.WINDUP)
	_dash_direction = facing
	telegraph.rotation.y = facing_angle()
	telegraph.show_rect(data.dash_distance + 1.0, data.charge_width, data.windup)


func _start_dash() -> void:
	telegraph.hide_telegraph()
	_hit.clear()
	_dash_from = global_position
	_set_mode(Mode.DASH)


func _hit_along(from: Vector3, to: Vector3) -> void:
	var reach: Vector3 = to + _dash_direction * 1.0
	for hurtbox: Hurtbox in CombatQuery.in_line(get_tree(), DamageInfo.Team.PLAYERS, from, reach,
			data.charge_width):
		if _hit.has(hurtbox.receiver):
			continue
		_hit.append(hurtbox.receiver)
		var info: DamageInfo = make_attack()
		info.origin = from
		if hurtbox.take_hit(info):
			freeze(Balance.combat.hitstop_light)


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_time = 0.0


func _on_interrupted() -> void:
	if mode == Mode.WINDUP or mode == Mode.DASH:
		telegraph.hide_telegraph()
		_set_mode(Mode.RECOVER)


func _build_extras() -> void:
	var blade := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 1.2)
	blade.mesh = mesh
	blade.position = Vector3(data.body_radius + 0.1, data.body_height * 0.55, -0.45)
	blade.material_override = Fx.flat_material(Color(0.7, 0.72, 0.76))
	visual.add_child(blade)
	var mask := MeshInstance3D.new()
	var band := CylinderMesh.new()
	band.top_radius = data.body_radius * 1.05
	band.bottom_radius = data.body_radius * 1.05
	band.height = 0.18
	mask.mesh = band
	mask.position.y = data.body_height * 0.8
	mask.material_override = Fx.flat_material(Color(0.12, 0.1, 0.14))
	visual.add_child(mask)
