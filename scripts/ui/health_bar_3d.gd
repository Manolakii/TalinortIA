class_name HealthBar3D
extends Node3D
## Barrita de vida sobre un personaje o enemigo (GDD, Interfaz: aparece solo cuando
## recibe daño). Los élites la muestran siempre. Mira siempre a la cámara.

const WIDTH := 1.1
const HEIGHT := 0.11
const VISIBLE_TIME := 2.0

var _target: Combatant
var _fill: MeshInstance3D
var _time_left: float = 0.0
var _always: bool = false


func setup(target: Combatant) -> void:
	_target = target
	_always = target is Enemy and (target as Enemy).is_elite
	var fill_color: Color = Color(0.92, 0.88, 0.82)
	if target is PlayerCharacter:
		fill_color = (target as PlayerCharacter).slot.color.lightened(0.2)
	var background := _quad(Vector2(WIDTH + 0.06, HEIGHT + 0.06), Color(0.05, 0.05, 0.07, 0.85))
	add_child(background)
	_fill = _quad(Vector2(WIDTH, HEIGHT), fill_color)
	_fill.position.z = 0.01
	add_child(_fill)
	position.y = target.hurtbox.height + 0.55
	visible = _always


func reveal() -> void:
	_time_left = VISIBLE_TIME
	visible = true


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or _target.health.is_dead:
		visible = false
		return
	_time_left -= delta
	if not _always and _time_left <= 0.0:
		visible = false
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		global_basis = camera.global_basis
	var ratio: float = _target.health.ratio()
	_fill.scale.x = maxf(ratio, 0.001)
	_fill.position.x = -(1.0 - ratio) * WIDTH * 0.5


func _quad(size: Vector2, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mesh_instance.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.no_depth_test = true
	material.render_priority = 5
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance
