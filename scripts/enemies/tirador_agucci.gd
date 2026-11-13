class_name TiradorAgucci
extends Enemy
## Tirador Agucci (GDD, Stage 1): se mueve de costado y dispara ráfagas de UZI en abanico.

var _cooldown: float = 1.5
var _winding: float = -1.0
var _aim: Vector3 = Vector3.FORWARD
var _strafe: float = 1.0
var _strafe_time: float = 0.0


func _ready() -> void:
	enemy_id = &"tirador_agucci"
	super._ready()
	_cooldown = randf_range(0.8, attack_interval_time())


func _think(delta: float) -> void:
	if status.has(StatusEffects.STUN):
		stop(delta)
		_winding = -1.0
		return
	if status.has(StatusEffects.FEAR):
		steer(-flat_direction_to(fear_origin), data.move_speed * 1.3, delta)
		return
	var target: Node3D = nearest_target()
	if target == null or status.has(StatusEffects.BLIND):
		stop(delta)
		return
	if _winding >= 0.0:
		_winding += delta
		stop(delta)
		if _winding >= windup_time():
			_winding = -1.0
			_fire()
		return
	_strafe_time -= delta
	if _strafe_time <= 0.0:
		_strafe_time = randf_range(1.0, 1.8)
		_strafe = -_strafe
	keep_distance(target, data.preferred_distance, delta, _strafe)
	_cooldown -= delta
	if _cooldown <= 0.0 and flat_distance_to(target.global_position) <= data.attack_range:
		_cooldown = attack_interval_time()
		_winding = 0.0
		_aim = flat_direction_to(target.global_position)
		facing = _aim
		telegraph.rotation.y = facing_angle()
		telegraph.show_sector(data.projectile_range * 0.55, data.spread_deg + 10.0, windup_time())


func _fire() -> void:
	telegraph.hide_telegraph()
	var pool: ProjectilePool = enemy_projectiles()
	for i: int in data.projectile_count:
		var t: float = float(i) / maxf(data.projectile_count - 1, 1) - 0.5
		var direction: Vector3 = _aim.rotated(Vector3.UP, deg_to_rad(t * data.spread_deg))
		var info: DamageInfo = make_attack()
		info.is_melee = false
		pool.fire(global_position + Vector3.UP * 1.1 + direction * 0.6, direction,
				data.projectile_speed, data.projectile_range, 0.22, info, DamageInfo.Team.PLAYERS)


func _on_interrupted() -> void:
	_winding = -1.0


func _build_extras() -> void:
	var uzi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.14, 0.18, 0.45)
	uzi.mesh = mesh
	uzi.position = Vector3(data.body_radius + 0.05, data.body_height * 0.55, -0.3)
	uzi.material_override = Fx.flat_material(Color(0.15, 0.15, 0.17))
	visual.add_child(uzi)
	var mask := MeshInstance3D.new()
	var band := CylinderMesh.new()
	band.top_radius = data.body_radius * 1.05
	band.bottom_radius = data.body_radius * 1.05
	band.height = 0.18
	mask.mesh = band
	mask.position.y = data.body_height * 0.8
	mask.material_override = Fx.flat_material(Color(0.12, 0.1, 0.14))
	visual.add_child(mask)
