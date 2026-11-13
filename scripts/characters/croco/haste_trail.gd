class_name HasteTrail
extends Node3D
## Rastro de Ruta de Escape: los aliados que lo pisan van más rápido un rato.

var _from: Vector3
var _to: Vector3
var _width: float = 1.6
var _haste: float = 1.5
var _time_left: float = 2.0
var _duration: float = 2.0
var _owner_player: Node
var _material: StandardMaterial3D


func setup(owner_player: Node, from: Vector3, to: Vector3, width: float, duration: float,
		haste: float, color: Color) -> void:
	_owner_player = owner_player
	_from = Vector3(from.x, 0.0, from.z)
	_to = Vector3(to.x, 0.0, to.z)
	_width = width
	_duration = duration
	_time_left = duration
	_haste = haste
	var strip := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var length: float = maxf(_from.distance_to(_to), 0.5)
	plane.size = Vector2(width * 0.6, length)
	strip.mesh = plane
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(color.lightened(0.4), 0.35)
	strip.material_override = _material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(strip)
	global_position = (_from + _to) * 0.5 + Vector3.UP * 0.2
	var direction: Vector3 = _to - _from
	if direction.length_squared() > 0.001:
		rotation.y = atan2(-direction.x, -direction.z)


func _physics_process(delta: float) -> void:
	_time_left -= delta
	_material.albedo_color.a = 0.35 * clampf(_time_left / _duration, 0.0, 1.0)
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player == _owner_player or not player.is_targetable():
			continue
		var p := Vector3(player.global_position.x, 0.0, player.global_position.z)
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(p, _from, _to)
		if p.distance_to(closest) <= _width * 0.5:
			player.status.apply(StatusEffects.HASTE, _haste)
	if _time_left <= 0.0:
		queue_free()
