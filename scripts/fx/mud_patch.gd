class_name MudPatch
extends Node3D
## Barro que deja la reliquia "Barro en las botas" al esquivar: los enemigos que lo pisan quedan
## lentos. Dura unos segundos y se seca.

const MUD_COLOR := Color(0.36, 0.26, 0.16, 0.7)

var radius: float = 1.8
var lifetime: float = 5.0
var _age: float = 0.0
var _tick: float = 0.0
var _material: StandardMaterial3D


func _ready() -> void:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.03
	disc.mesh = mesh
	_material = Fx.flat_material(MUD_COLOR)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material_override = _material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = 0.04
	add_child(disc)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_material.albedo_color.a = MUD_COLOR.a * clampf((lifetime - _age) / 0.6, 0.0, 1.0)
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	for hurtbox: Hurtbox in CombatQuery.in_circle(get_tree(), DamageInfo.Team.ENEMIES, global_position, radius):
		var enemy := hurtbox.receiver as Combatant
		if enemy != null:
			enemy.status.apply(StatusEffects.SLOW, 0.4)
