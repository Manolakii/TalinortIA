class_name Telegraph
extends MeshInstance3D
## Aviso de ataque en el piso. El relleno avanza durante `duration` y llega al borde
## justo cuando pega el golpe.

const SHADER: Shader = preload("res://assets/shaders/telegraph.gdshader")
## Altura sobre el piso: por encima de la mayoría del pasto, debajo de los personajes.
const HEIGHT := 0.22

var _material: ShaderMaterial
var _plane: PlaneMesh
var _duration: float = 0.0
var _elapsed: float = 0.0
var _shape: int = 0
var _radius: float = 0.0
var _angle_deg: float = 360.0
var _length: float = 0.0
var _width: float = 0.0


func _ready() -> void:
	_plane = PlaneMesh.new()
	mesh = _plane
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position.y = HEIGHT
	visible = false


## Abanico hacia -Z del nodo (360 = círculo).
func show_sector(radius: float, angle_deg: float, duration: float) -> void:
	_plane.size = Vector2.ONE * radius * 2.0
	_plane.center_offset = Vector3.ZERO
	_shape = 0
	_radius = radius
	_angle_deg = angle_deg
	_material.set_shader_parameter("shape", 0)
	_material.set_shader_parameter("angle_deg", angle_deg)
	_material.set_shader_parameter("size_m", _plane.size)
	_start(duration)


func show_circle(radius: float, duration: float) -> void:
	show_sector(radius, 360.0, duration)


## Rectángulo que arranca en el nodo y se extiende `length` hacia -Z.
func show_rect(length: float, width: float, duration: float) -> void:
	_plane.size = Vector2(width, length)
	_plane.center_offset = Vector3(0.0, 0.0, -length * 0.5)
	_shape = 1
	_length = length
	_width = width
	_material.set_shader_parameter("shape", 1)
	_material.set_shader_parameter("size_m", _plane.size)
	_start(duration)


func hide_telegraph() -> void:
	visible = false
	set_process(false)
	remove_from_group(&"telegraphs")


## ¿Este punto del piso está dentro del aviso? (para la IA que esquiva). `margin` agranda la zona.
func contains(point: Vector3, margin: float = 0.4) -> bool:
	if not visible or not is_inside_tree():
		return false
	var local: Vector3 = global_transform.affine_inverse() * Vector3(point.x, global_position.y, point.z)
	if _shape == 0:
		var flat := Vector2(local.x, local.z)
		if flat.length() > _radius + margin:
			return false
		if _angle_deg >= 359.0 or flat.length() < 0.5:
			return true
		var angle: float = absf(atan2(local.x, -local.z))
		return angle <= deg_to_rad(_angle_deg) * 0.5 + 0.2
	return absf(local.x) <= _width * 0.5 + margin and local.z <= margin and local.z >= -_length - margin


func _start(duration: float) -> void:
	_duration = maxf(duration, 0.01)
	_elapsed = 0.0
	_material.set_shader_parameter("progress", 0.0)
	visible = true
	set_process(true)
	add_to_group(&"telegraphs")


func _process(delta: float) -> void:
	_elapsed += delta
	_material.set_shader_parameter("progress", clampf(_elapsed / _duration, 0.0, 1.0))
