class_name PipoMine
extends Node3D
## Mina de proximidad que deja el Repliegue Ordenado del General Pipo.

const ARM_TIME := 0.5

var kit: PipoKit
var _age: float = 0.0
var _exploded: bool = false
var _light: MeshInstance3D
var _material: StandardMaterial3D


func setup(owner_kit: PipoKit) -> void:
	kit = owner_kit
	var body := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.3
	disc.bottom_radius = 0.35
	disc.height = 0.12
	body.mesh = disc
	body.position.y = 0.06
	body.material_override = Fx.flat_material(Color(0.35, 0.38, 0.32))
	add_child(body)
	_light = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	_light.mesh = sphere
	_light.position.y = 0.16
	_material = Fx.flat_material(kit.player.slot.color, 2.0)
	_light.material_override = _material
	add_child(_light)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	if not is_instance_valid(kit):
		queue_free()
		return
	_age += delta
	_light.visible = _age < ARM_TIME or fmod(_age, 0.6) < 0.3
	if _age >= kit.kd.mine_lifetime:
		queue_free()
		return
	if _age < ARM_TIME:
		return
	if CombatQuery.nearest(get_tree(), DamageInfo.Team.ENEMIES, global_position, kit.kd.mine_trigger) != null:
		explode()


func explode() -> void:
	if _exploded:
		return
	_exploded = true
	var info: DamageInfo = kit.make_hit(kit.mine_damage())
	info.origin = global_position
	info.knockback = 7.0
	info.is_melee = false
	Combat.deliver(info, CombatQuery.in_circle(get_tree(), DamageInfo.Team.ENEMIES, global_position, kit.kd.mine_radius))
	Fx.ring_burst(get_parent(), global_position, kit.kd.mine_radius, Color(1.0, 0.85, 0.55), 0.3)
	Events.camera_shake_requested.emit(Balance.combat.shake_light)
	Sound.play("hit_heavy", -3.0)
	queue_free()
