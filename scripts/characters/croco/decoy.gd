class_name Decoy
extends Node3D
## Señuelo holográfico de Ruta de Escape: los enemigos lo prefieren como objetivo
## y le pegan sin hacerle nada, hasta que se apaga.

var _time_left: float = 1.5
var _priority: float = 0.35
var _material: StandardMaterial3D
var _explode_owner: Node3D
var _explode_damage: float = 0.0
var _explode_radius: float = 0.0


func setup(color: Color, height: float, radius: float, duration: float, priority: float) -> void:
	_time_left = duration
	_priority = priority
	add_to_group(&"enemy_targets")
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.height = height
	mesh.radius = radius
	body.mesh = mesh
	body.position.y = height * 0.5
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(color.lightened(0.3), 0.45)
	body.material_override = _material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	var hurtbox := Hurtbox.new()
	hurtbox.team = DamageInfo.Team.PLAYERS
	hurtbox.radius = radius
	hurtbox.height = height
	hurtbox.receiver = self
	add_child(hurtbox)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	# Parpadeo de holograma.
	_material.albedo_color.a = 0.3 + 0.2 * absf(sin(_time_left * 18.0))
	if _time_left <= 0.0:
		_explode()
		queue_free()


func can_be_targeted_by_enemies() -> bool:
	return _time_left > 0.0


func target_priority() -> float:
	return _priority


func is_targetable() -> bool:
	return _time_left > 0.0


## Se come el golpe sin daño.
func receive_hit(_info: DamageInfo) -> bool:
	return true


## Mejora "Señuelo con sorpresa": explota al desaparecer.
func explode_on_expire(owner_player: Node3D, damage: float, radius: float) -> void:
	_explode_owner = owner_player
	_explode_damage = damage
	_explode_radius = radius


func _explode() -> void:
	if _explode_damage <= 0.0:
		return
	var info := DamageInfo.new()
	info.amount = _explode_damage
	info.attacker = _explode_owner if is_instance_valid(_explode_owner) else null
	info.attacker_team = DamageInfo.Team.PLAYERS
	info.origin = global_position
	info.knockback = 6.0
	info.hitstop = Balance.combat.hitstop_light
	Combat.deliver(info, CombatQuery.in_circle(get_tree(), DamageInfo.Team.ENEMIES,
			global_position, _explode_radius))
	Fx.ring_burst(get_parent(), global_position, _explode_radius, Color(1.0, 0.95, 0.85), 0.3)
