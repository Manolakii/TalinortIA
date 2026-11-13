class_name DuoZone
extends Node3D
## Zonas de las Sendas del dúo:
##   HEAL: Manantial (Stewie, Espíritu): cura a los aliados adentro. Verde agua = curación.
##   FOG: Niebla de los Valles (Maestro, Niebla): los enemigos adentro van lentos y fallan más.
##   CLOUD: Garrocha de Niebla: nube que oculta a los aliados de los enemigos.

enum Kind { HEAL, FOG, CLOUD }

const HEAL_COLOR := Color(0.35, 0.95, 0.85)
const FOG_COLOR := Color(0.85, 0.88, 0.92)
const RING_SHADER: Shader = preload("res://assets/shaders/player_ring.gdshader")

var kind: Kind = Kind.HEAL
var radius: float = 3.0
var lifetime: float = 5.0
## HEAL: vida por segundo.
var power: float = 6.0

var _age: float = 0.0
var _material: ShaderMaterial


func setup(which: Kind, zone_radius: float, duration: float, zone_power: float = 0.0) -> void:
	kind = which
	radius = zone_radius
	lifetime = duration
	power = zone_power
	var disc := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	disc.mesh = plane
	disc.position.y = 0.07
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = RING_SHADER
	var color: Color = HEAL_COLOR if kind == Kind.HEAL else FOG_COLOR
	_material.set_shader_parameter("ring_color", Color(color, 0.85))
	_material.set_shader_parameter("inner_radius", 0.85)
	_material.set_shader_parameter("fill_alpha", 0.3 if kind == Kind.HEAL else 0.45)
	disc.material_override = _material
	add_child(disc)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	var center: Vector3 = global_position
	match kind:
		Kind.HEAL:
			for node: Node in get_tree().get_nodes_in_group(&"enemy_targets"):
				var ally := node as Combatant
				if ally != null and ally.is_targetable() and _inside(ally.global_position, center):
					ally.health.heal(power * delta)
		Kind.FOG:
			for hurtbox: Hurtbox in CombatQuery.in_circle(get_tree(), DamageInfo.Team.ENEMIES,
					center, radius):
				var enemy := hurtbox.receiver as Combatant
				if enemy != null:
					enemy.status.apply(StatusEffects.SLOW, 0.3)
					enemy.status.apply(StatusEffects.FOGGED, 0.3)
		Kind.CLOUD:
			for node: Node in get_tree().get_nodes_in_group(&"players"):
				var player := node as PlayerCharacter
				if player != null and _inside(player.global_position, center):
					player.status.apply(StatusEffects.HIDDEN, 0.25)


func _inside(point: Vector3, center: Vector3) -> bool:
	return Vector2(point.x - center.x, point.z - center.z).length() <= radius
