class_name HitEffects
extends Node3D
## Efectos de golpe (pedido del grupo, 2026-11-16: que pegar se sienta todavía mejor):
##   chispas al pegar (más grandes y doradas en los críticos), una nubecita de sombra cuando
##   muere un enemigo (la sombra lo suelta) y polvo al esquivar.
## Usa pools de partículas (CLAUDE.md: nada de crear nodos sin parar).

const SPARKS := 10
const PUFFS := 6
const DUSTS := 4
const SPARK_COLOR := Color(1.0, 0.95, 0.8)
const CRIT_COLOR := Color(1.0, 0.85, 0.35)
const HURT_COLOR := Color(1.0, 0.55, 0.55)
const PUFF_COLOR := Color(0.5, 0.35, 0.65)
const DUST_COLOR := Color(0.75, 0.7, 0.62)

var _sparks: Array[CPUParticles3D] = []
var _puffs: Array[CPUParticles3D] = []
var _dusts: Array[CPUParticles3D] = []
var _next: Dictionary = {"spark": 0, "puff": 0, "dust": 0}


func _ready() -> void:
	for i: int in SPARKS:
		_sparks.append(_make_sparks())
	for i: int in PUFFS:
		_puffs.append(_make_puff())
	for i: int in DUSTS:
		_dusts.append(_make_dust())
	Events.hit_landed.connect(_on_hit_landed)
	Events.enemy_died.connect(_on_enemy_died)
	Events.dodged.connect(_on_dodged)


func _on_hit_landed(info: DamageInfo, target: Node3D) -> void:
	if not is_instance_valid(target) or info.final_amount <= 0.0 or info.has_tag(&"tick"):
		return
	var at: Vector3 = target.global_position + Vector3.UP * 1.0
	var away: Vector3 = target.global_position - info.origin
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.01 else Vector3.UP
	var hurt: bool = info.attacker_team == DamageInfo.Team.ENEMIES
	var color: Color = HURT_COLOR if hurt else (CRIT_COLOR if info.is_crit else SPARK_COLOR)
	var big: bool = info.is_crit or info.final_amount >= 40.0
	var sparks: CPUParticles3D = _take(_sparks, "spark")
	sparks.global_position = at
	sparks.direction = (away + Vector3.UP * 0.6).normalized()
	sparks.color = color
	sparks.amount = 14 if big else 8
	sparks.scale_amount_min = 0.12 if big else 0.08
	sparks.scale_amount_max = 0.22 if big else 0.14
	sparks.initial_velocity_max = 9.0 if big else 6.5
	sparks.restart()


func _on_enemy_died(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	var puff: CPUParticles3D = _take(_puffs, "puff")
	puff.global_position = enemy.global_position + Vector3.UP * 0.8
	puff.restart()


func _on_dodged(who: Node3D) -> void:
	if not is_instance_valid(who):
		return
	var dust: CPUParticles3D = _take(_dusts, "dust")
	dust.global_position = who.global_position + Vector3.UP * 0.15
	dust.restart()


func _take(pool: Array[CPUParticles3D], key: String) -> CPUParticles3D:
	var index: int = _next[key]
	_next[key] = (index + 1) % pool.size()
	return pool[index]


func _base(amount: int, lifetime: float, color: Color, size: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.color = color
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	particles.mesh = mesh
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	add_child(particles)
	return particles


func _make_sparks() -> CPUParticles3D:
	var sparks: CPUParticles3D = _base(8, 0.28, SPARK_COLOR, 1.0)
	sparks.spread = 55.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 6.5
	sparks.gravity = Vector3(0, -14, 0)
	sparks.damping_min = 4.0
	sparks.damping_max = 8.0
	sparks.scale_amount_min = 0.08
	sparks.scale_amount_max = 0.14
	return sparks


func _make_puff() -> CPUParticles3D:
	var puff: CPUParticles3D = _base(12, 0.7, PUFF_COLOR, 1.0)
	puff.direction = Vector3.UP
	puff.spread = 70.0
	puff.initial_velocity_min = 1.0
	puff.initial_velocity_max = 2.8
	puff.gravity = Vector3(0, 1.5, 0)
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 0.5
	puff.scale_amount_min = 0.35
	puff.scale_amount_max = 0.7
	return puff


func _make_dust() -> CPUParticles3D:
	var dust: CPUParticles3D = _base(10, 0.45, DUST_COLOR, 1.0)
	dust.direction = Vector3.UP
	dust.spread = 85.0
	dust.initial_velocity_min = 0.8
	dust.initial_velocity_max = 2.2
	dust.gravity = Vector3(0, -1.0, 0)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 0.4
	dust.scale_amount_min = 0.2
	dust.scale_amount_max = 0.4
	return dust
