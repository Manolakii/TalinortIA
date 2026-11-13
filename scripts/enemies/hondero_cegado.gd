class_name HonderoCegado
extends Enemy
## Hondero cegado (GDD, Stage 1): se queda a unos 8 m y tira piedras en parábola,
## con un círculo de aviso donde caen.

const BLINDFOLD_COLOR := Color(0.42, 0.2, 0.62)

var _cooldown: float = 1.0
var _winding: float = -1.0
var _target: Node3D
var _strafe: float = 1.0
var _strafe_time: float = 0.0
var _sling: MeshInstance3D


func _ready() -> void:
	enemy_id = &"hondero_cegado"
	super._ready()
	_cooldown = randf_range(0.6, data.attack_interval)


func _think(delta: float) -> void:
	if status.has(StatusEffects.STUN):
		stop(delta)
		_winding = -1.0
		return
	if status.has(StatusEffects.FEAR):
		steer(-flat_direction_to(fear_origin), data.move_speed * 1.3, delta)
		return
	if status.has(StatusEffects.BLIND):
		stop(delta)
		return
	_target = nearest_target()
	if _target == null:
		stop(delta)
		return
	if _winding >= 0.0:
		_winding += delta
		stop(delta)
		turn_towards(flat_direction_to(_target.global_position), delta)
		if _winding >= data.windup:
			_winding = -1.0
			_throw()
		return
	_strafe_time -= delta
	if _strafe_time <= 0.0:
		_strafe_time = randf_range(1.2, 2.2)
		_strafe = [-0.5, 0.0, 0.5].pick_random()
	keep_distance(_target, data.preferred_distance, delta, _strafe)
	_cooldown -= delta
	if _cooldown <= 0.0 and flat_distance_to(_target.global_position) <= data.attack_range:
		_cooldown = data.attack_interval
		_winding = 0.0
		var tween: Tween = create_tween()
		tween.tween_property(_sling, "rotation:y", TAU * 2.0, data.windup).as_relative()


func _throw() -> void:
	if not is_instance_valid(_target):
		return
	# Apunta un poco adelante de donde va el objetivo.
	var landing: Vector3 = _target.global_position
	var mover := _target as CharacterBody3D
	if mover != null:
		landing += Vector3(mover.velocity.x, 0.0, mover.velocity.z) * data.flight_time * 0.4
	var stone := LobbedStone.new()
	get_parent().add_child(stone)
	var info: DamageInfo = make_attack()
	info.is_melee = false
	stone.launch(global_position + Vector3.UP * 1.6, landing, data.flight_time, data.impact_radius, info)


func _on_interrupted() -> void:
	_winding = -1.0


func _build_extras() -> void:
	var blindfold := MeshInstance3D.new()
	var band := CylinderMesh.new()
	band.top_radius = data.body_radius * 1.04
	band.bottom_radius = data.body_radius * 1.04
	band.height = 0.12
	blindfold.mesh = band
	blindfold.position.y = data.body_height * 0.8
	blindfold.material_override = Fx.flat_material(BLINDFOLD_COLOR, 0.4)
	visual.add_child(blindfold)
	_sling = MeshInstance3D.new()
	var rope := BoxMesh.new()
	rope.size = Vector3(0.05, 0.05, 0.7)
	_sling.mesh = rope
	_sling.position = Vector3(data.body_radius + 0.1, data.body_height * 0.85, 0.0)
	_sling.material_override = Fx.flat_material(Color(0.4, 0.3, 0.2))
	visual.add_child(_sling)
