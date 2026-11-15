class_name FloracionZone
extends Node3D
## Definitiva de Champaka: un hongo gigante con una zona de esporas alrededor.
## Cura a los aliados, revive a un caído y deja a los enemigos lentos y confundidos.

const COLOR := Color(0.35, 0.95, 0.85)
const PULSE := 0.5

var kit: ChampakaKit
var _time_left: float = 8.0
var _pulse: float = 0.0
var _visual: Node3D


func setup(owner_kit: ChampakaKit, duration: float) -> void:
	kit = owner_kit
	_time_left = duration
	_build()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(kit) or not is_instance_valid(kit.player):
		queue_free()
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_finish()
		return
	_pulse -= delta
	if _pulse > 0.0:
		return
	_pulse = PULSE
	var radius: float = kit.bloom_radius()
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var ally := node as PlayerCharacter
		if ally == null or _flat_distance(ally.global_position) > radius:
			continue
		if ally.is_downed():
			ally.complete_revive()
			Fx.ring_burst(get_parent(), ally.global_position, 1.5, COLOR, 0.5)
		elif not ally.health.is_dead:
			ally.health.heal(kit.kd.bloom_heal_per_second * PULSE)
	for hurtbox: Hurtbox in CombatQuery.in_circle(get_tree(), DamageInfo.Team.ENEMIES, global_position, radius):
		var enemy := hurtbox.receiver as Combatant
		if enemy != null:
			enemy.status.apply(StatusEffects.SLOW, PULSE + 0.2)
			enemy.status.apply(StatusEffects.CONFUSED, PULSE + 0.2)
	Fx.ring_burst(get_parent(), global_position, radius, Color(COLOR, 0.5), 0.45)


func _flat_distance(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func _finish() -> void:
	set_physics_process(false)
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
	tween.tween_callback(queue_free)


func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var radius: float = kit.bloom_radius()
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = radius
	disc_mesh.bottom_radius = radius
	disc_mesh.height = 0.03
	disc.mesh = disc_mesh
	disc.position.y = 0.03
	var disc_material := Fx.flat_material(Color(COLOR, 0.18), 0.4)
	disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material_override = disc_material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(disc)
	# El hongo gigante va atrás (al norte) para no tapar a Champaka con la cámara de 3/4.
	var mushroom := Node3D.new()
	mushroom.position = Vector3(0, 0, -2.6)
	_visual.add_child(mushroom)
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.35
	stem_mesh.bottom_radius = 0.5
	stem_mesh.height = 2.6
	stem.mesh = stem_mesh
	stem.position.y = 1.3
	stem.material_override = Fx.flat_material(Color(0.92, 0.9, 0.82))
	mushroom.add_child(stem)
	var cap := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 1.8
	dome.height = 1.6
	dome.is_hemisphere = true
	cap.mesh = dome
	cap.position.y = 2.5
	cap.material_override = Fx.flat_material(COLOR.darkened(0.15), 1.0)
	mushroom.add_child(cap)
	_visual.scale = Vector3.ONE * 0.1
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
