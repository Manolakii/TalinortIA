class_name AllyTurret
extends Node3D
## Torreta aliada que deja el General Pipo para una sala (GDD: torreta de Pipo, 10 por tiro y
## 2 tiros por segundo). Le tira al enemigo más cercano a su alcance.

const METAL := Color(0.4, 0.45, 0.38)
const SHOT_COLOR := Color(0.75, 0.92, 1.0)

var damage: float = 10.0
var shots_per_second: float = 2.0
var attack_range: float = 12.0
var _head: Node3D
var _cooldown: float = 0.5


func setup(config: StageRoomsConfig) -> void:
	damage = config.turret_damage
	shots_per_second = config.turret_shots_per_second
	attack_range = config.turret_range


func _ready() -> void:
	for i: int in 3:
		var angle: float = TAU * i / 3.0
		var leg := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, 0.9, 0.08)
		leg.mesh = mesh
		leg.position = Vector3(cos(angle) * 0.3, 0.4, sin(angle) * 0.3)
		leg.rotation = Vector3(sin(angle) * 0.35, 0, -cos(angle) * 0.35)
		leg.material_override = Fx.flat_material(METAL)
		add_child(leg)
	_head = Node3D.new()
	_head.position.y = 0.95
	add_child(_head)
	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.5, 0.35, 0.6)
	box.mesh = box_mesh
	box.material_override = Fx.flat_material(METAL)
	_head.add_child(box)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.12, 0.12, 0.7)
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0, 0.02, -0.55)
	barrel.material_override = Fx.flat_material(METAL.darkened(0.3))
	_head.add_child(barrel)
	var lamp := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	lamp.mesh = sphere
	lamp.position = Vector3(0, 0.24, 0.1)
	lamp.material_override = Fx.flat_material(SHOT_COLOR, 2.0)
	_head.add_child(lamp)
	var label := Label3D.new()
	label.text = "Torreta de Pipo"
	label.font_size = 26
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.8
	add_child(label)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	var target: Hurtbox = CombatQuery.nearest(get_tree(), DamageInfo.Team.ENEMIES, global_position,
			attack_range)
	if target == null:
		return
	var direction: Vector3 = target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		_head.rotation.y = lerp_angle(_head.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 12.0, 1.0))
	if _cooldown > 0.0:
		return
	_cooldown = 1.0 / shots_per_second
	var info := DamageInfo.new()
	info.amount = damage
	info.attacker_team = DamageInfo.Team.PLAYERS
	info.origin = global_position
	info.is_melee = false
	info.knockback = 0.5
	target.take_hit(info)
	var from: Vector3 = _head.global_position + Vector3.UP * 0.02
	var to: Vector3 = target.global_position + Vector3.UP * 0.9
	Fx.beam(get_parent(), from, (to - from).normalized(), from.distance_to(to), 0.06, SHOT_COLOR, 0.08)
