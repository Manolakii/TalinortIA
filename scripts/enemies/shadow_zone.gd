class_name ShadowZone
extends Node3D
## Zona de sombra en el piso: violeta con borde brillante (las sombras con mecánica se
## distinguen de las del escenario, GDD Choques). Lastima o ralentiza a los jugadores adentro.
## Sigue a `follow` si se le pasa (zona del Chamán); si no, queda fija (charcos del Sombrío).

const SHADOW_COLOR := Color(0.45, 0.2, 0.72)
const RING_SHADER: Shader = preload("res://assets/shaders/player_ring.gdshader")
const TICK := 0.5

var radius: float = 3.5
## Daño por segundo a los jugadores adentro (0 = no lastima).
var dps: float = 0.0
## Si es mayor que 0, aplica "lento" este tiempo a los que están adentro.
var slow_time: float = 0.0
## Si es mayor que 0, desaparece después de este tiempo.
var lifetime: float = 0.0
var follow: Node3D
var source: Node3D
var damage_multiplier: float = 1.0

var _tick: float = 0.0
var _age: float = 0.0
var _material: ShaderMaterial


func _ready() -> void:
	var disc := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	disc.mesh = plane
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = RING_SHADER
	_material.set_shader_parameter("ring_color", Color(SHADOW_COLOR.lightened(0.3), 0.9))
	_material.set_shader_parameter("inner_radius", 0.86)
	_material.set_shader_parameter("fill_alpha", 0.35)
	disc.material_override = _material
	disc.position.y = 0.06
	add_child(disc)


func _physics_process(delta: float) -> void:
	_age += delta
	if follow != null:
		if not is_instance_valid(follow):
			queue_free()
			return
		global_position = Vector3(follow.global_position.x, 0.0, follow.global_position.z)
	if lifetime > 0.0:
		var fade: float = clampf((lifetime - _age) / 0.6, 0.0, 1.0)
		_material.set_shader_parameter("ring_color", Color(SHADOW_COLOR.lightened(0.3), 0.9 * fade))
		if _age >= lifetime:
			queue_free()
			return
	var inside: Array[Hurtbox] = CombatQuery.in_circle(get_tree(), DamageInfo.Team.PLAYERS,
			global_position, radius)
	if slow_time > 0.0:
		for hurtbox: Hurtbox in inside:
			var target := hurtbox.receiver as Combatant
			if target != null:
				target.status.apply(StatusEffects.SLOW, slow_time)
	_tick -= delta
	if dps > 0.0 and _tick <= 0.0:
		_tick = TICK
		var info := DamageInfo.new()
		info.amount = dps * TICK * damage_multiplier
		info.attacker = source if is_instance_valid(source) else null
		info.attacker_team = DamageInfo.Team.ENEMIES
		info.origin = global_position
		info.tags.append(&"tick")
		Combat.deliver(info, inside)
