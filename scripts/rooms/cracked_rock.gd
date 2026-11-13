class_name CrackedRock
extends StaticBody3D
## Roca agrietada: esconde un pasaje al Tesoro (pedido del grupo: que el Tesoro haya que
## encontrarlo). Tiene grietas que brillan apenas en dorado. Se rompe con unos golpes de
## cualquier ataque; el apuntado y las IA no la buscan.

signal broken

const ROCK_MATERIAL: Material = preload("res://assets/materials/rock_material.tres")
const CRACK_COLOR := Color(1.0, 0.78, 0.3)

var hits_needed: int = 3
var _hits: int = 0
var _broken: bool = false
var _visual: Node3D
var _hurtbox: Hurtbox
var _crack_material: StandardMaterial3D


func _ready() -> void:
	collision_layer = 512
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.9
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position.y = 0.6
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	var rock := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.6
	sphere.material = ROCK_MATERIAL
	rock.mesh = sphere
	rock.position.y = 0.4
	_visual.add_child(rock)
	# Grietas: líneas finitas que brillan y laten despacio.
	_crack_material = Fx.flat_material(CRACK_COLOR, 1.2)
	for i: int in 4:
		var crack := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 1.0, 0.08)
		crack.mesh = box
		var angle: float = -0.6 + i * 0.4
		crack.position = Vector3(sin(angle) * 0.92, 0.55 + (i % 2) * 0.15, cos(angle) * 0.92)
		crack.rotation = Vector3(0.3 * (i % 2 * 2 - 1), angle, 0.5 * (i % 2 * 2 - 1))
		crack.material_override = _crack_material
		_visual.add_child(crack)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(_crack_material, "emission_energy_multiplier", 2.4, 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_crack_material, "emission_energy_multiplier", 0.6, 0.9).set_trans(Tween.TRANS_SINE)
	_hurtbox = Hurtbox.new()
	_hurtbox.team = DamageInfo.Team.ENEMIES
	_hurtbox.radius = 1.0
	_hurtbox.height = 1.6
	_hurtbox.is_prop = true
	add_child(_hurtbox)


func is_targetable() -> bool:
	return not _broken


func receive_hit(info: DamageInfo) -> bool:
	if _broken or info.attacker_team != DamageInfo.Team.PLAYERS or info.has_tag(&"tick"):
		return false
	_hits += 1
	Fx.ring_burst(get_parent(), global_position, 1.1, CRACK_COLOR, 0.15)
	var shake: Tween = create_tween()
	shake.tween_property(_visual, "position:x", 0.12, 0.04)
	shake.tween_property(_visual, "position:x", -0.12, 0.04)
	shake.tween_property(_visual, "position:x", 0.0, 0.04)
	if _hits >= hits_needed:
		smash()
	return true


func smash() -> void:
	if _broken:
		return
	_broken = true
	collision_layer = 0
	_hurtbox.queue_free()
	Events.camera_shake_requested.emit(0.35)
	Events.floating_text_requested.emit(global_position + Vector3.UP * 2.4, "¡Un pasaje escondido!",
			CRACK_COLOR)
	Fx.ring_burst(get_parent(), global_position, 2.0, Color(0.6, 0.55, 0.5), 0.35)
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3(1.2, 0.05, 1.2), 0.3)
	tween.tween_callback(_visual.queue_free)
	broken.emit()


func is_broken() -> bool:
	return _broken
